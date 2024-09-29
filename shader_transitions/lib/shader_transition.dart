import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '/shader_canvas.dart';
import '/widget_to_image.dart';

class ShaderTransition extends StatefulWidget {
  /// Only used when in an AnimatedSwitcher and when the shader animates image captures of widgets (textures).
  /// Store the captured image of this ShaderTransition's child so that the next incoming ShaderTransition can use it.
  /// Map key is the hashCode of the parent AnimatedSwitcher.
  static final _savedImagesMap = HashMap<int, ui.Image>();
  static final _activeInstances = HashMap<int, HashSet<int>>();

  final ui.FragmentProgram? shaderBuilder;
  final Widget child;
  final Animation<double>? animation;

  /// If you need to define a fixed size for the widgets being transitioned.
  /// In most cases just leave it null for autodetection.
  final Size? childSize;

  /// Shader should contain a uniform vec2 for the resolution. Set the index of the X (width) value here.
  final int resolutionXIndex;

  /// Shader should contain a uniform vec2 for the resolution. Set the index of the Y (height) value here.
  final int resolutionYIndex;

  /// Identify the index of the shader's uniform float that will be set dynamically to progress the animation.
  final int progressIndex;

  /// Use to set all the uniform float values for the shader except resolution x, resolution y, and progress.
  final Map<int, double>? floatUniforms;

  /// Identify the index of the shader's uniform sampler2D for the incoming image.
  /// Must be left null for alpha mask shaders that don't use textures.
  final int? texture0Index;

  /// Identify the index of the shader's uniform sampler2D for the outgoing image.
  /// Must be left null for alpha mask shaders that don't use textures.
  final int? texture1Index;

  /// Reverses the animation direction of the incoming widget.
  final bool reverseAnimations;

  /// Leave this null if the transition is used in an AnimatedSwitcher or a DualTransitionBuilder (most cases).
  /// Otherwise you need to pass in the key of a common ancestor that both incoming and outgoing instances
  /// of ShaderTransition are part of (e.g. a Stack).
  final Key? ancestorKey;

  const ShaderTransition({
    super.key,
    required this.child,
    this.shaderBuilder,
    this.animation,
    this.childSize,
    this.resolutionXIndex = 0,
    this.resolutionYIndex = 1,
    this.progressIndex = 2,
    this.floatUniforms,
    this.texture1Index,
    this.texture0Index,
    this.reverseAnimations = false,
    this.ancestorKey,
  });

  static Future<ui.FragmentShader> fromAsset(String assetKey) async {
    final program = await ui.FragmentProgram.fromAsset(assetKey);
    return program.fragmentShader();
  }

  static Animation<double> getSequentialAnimation(Animation<double> animation) {
    return Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.5, 1.0, curve: Curves.linear), // Starts halfway through
      ),
    );
  }

  @override
  State<ShaderTransition> createState() => _ShaderTransitionState();
}

class _ShaderTransitionState extends State<ShaderTransition> {
  late Widget _child;
  late bool _reverseAnimations;
  bool _animationHasListener = false;
  bool _animationHasStatusListener = false;
  Size? _childSize;
  bool _animatedSwitcherMode = false;
  int? _ancestorId;
  bool _isOldWidget = false;
  bool _wasInterrupted = false;
  double _progress = 0.0;
  bool _shaderUniformsSet = false;
  ui.Image? _imageOfPreviousChild;
  ui.Image? _imageOfChild;
  ui.FragmentShader? _shader;
  bool _layoutCapture = false;
  BoxConstraints? _constraints;
  double _pixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
  bool _clear = false;
  Completer<void>? _shaderReadyCompleter;

  ShaderMode get _shaderMode {
    if (widget.texture1Index != null && widget.texture0Index != null) {
      return ShaderMode.dualTexture;
    } else if (widget.texture0Index != null) {
      return ShaderMode.singleTexture;
    }
    return ShaderMode.mask;
  }

  bool _isIncomingLayer = false;
  bool _forceShowChild = false;

  @override
  void initState() {
    super.initState();
    _reverseAnimations = widget.reverseAnimations;
    _childSize = widget.childSize;
    _ancestorId = _getAncestorId();

    if (_ancestorId == null) {
      throw Exception(
          "ShaderTransition can't identify a common ancestor and cannot function. Make sure it is used in an AnimatedSwitcher or DualTransitionBuilder or set the ancestorKey field");
    } else {
      _progress = widget.animation!.value;


      /// Necessary to track active instances within the same AnimatedSwitcher so that stored images are
      /// removed from memory when no longer needed.
      if (!ShaderTransition._activeInstances.containsKey(_ancestorId)) {
        ShaderTransition._activeInstances[_ancestorId!] = HashSet<int>();
      }

      if (ShaderTransition._activeInstances[_ancestorId!]!.length < 2) {
        ShaderTransition._activeInstances[_ancestorId!]!.add(hashCode);

        ///Wraping child widget so that shader will update if widget resizes.
        _child = NotificationListener<SizeChangedLayoutNotification>(
            onNotification: sizeChanged,
            child: SizeChangedLayoutNotifier(
              child: widget.child,
            ));


        if (_animatedSwitcherMode){
          _addAnimationStatusListener(widget.animation!, _animationStatusChange);
        }
        else{
          /// Assuming this is a PageRoute transition and thus transitions the entire viewport.
          /// This is also necessary to set the contratins as layout capture will not work
          /// in a PageRoute TransitionBuilder.
          final double widthScreen = WidgetsBinding
              .instance.platformDispatcher.views.first.physicalSize.width /
              WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

          final double heightScreen = WidgetsBinding
              .instance.platformDispatcher.views.first.physicalSize.height /
              WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
          _constraints = BoxConstraints(maxWidth: widthScreen, maxHeight: heightScreen);
          _childSize = Size(_constraints!.maxWidth, _constraints!.maxHeight);
        }

        if (widget.animation!.status == AnimationStatus.forward){
          _isIncomingLayer = true;
          _initializePreAnimatedLayer();
        }
        else if (widget.animation!.status == AnimationStatus.reverse){
          _reverseAnimations = !_reverseAnimations;
          _initializePreAnimatedLayer();
        }
        else{
          _forceShowChild = true;
        }
      }
    }
  }

  ///
  /// This also sets a flag if the transition is used in an AnimatedSwitcher (which is its primary intended use case).
  int? _getAncestorId() {
    final animatedSwitcherState = context.findAncestorStateOfType<State<AnimatedSwitcher>>();
    _animatedSwitcherMode == (animatedSwitcherState != null);
    if (widget.ancestorKey != null) {
      return widget.ancestorKey.hashCode;
    }
    if (animatedSwitcherState != null) {
      return animatedSwitcherState.hashCode;
    }
    throw Exception("ShaderTransition missing ancestorKey. Key must be provided if not used in an AnimatedSwitcher");
  }

  void _animationStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.reverse) {
      _isIncomingLayer = false;
      _isOldWidget = true;
      if (_progress < 1.0) {
        _wasInterrupted = true;
      }
      if (_shaderMode == ShaderMode.dualTexture || _shaderMode == ShaderMode.singleTexture) {
        _shader = null;
        _forceShowChild = true;
        _initializedRebuiltCompletedLayer();
      } else {
        _initializePreAnimatedLayer();
      }
    }
  }

  Future<void> _initializedRebuiltCompletedLayer() async {
    await createImageAndGetSize(_childSize);
    int timeout = 100;
    bool siblingExists = false;
    while (timeout > 0 && !siblingExists) {
      await Future.delayed(const Duration(milliseconds: 1));
      siblingExists = ShaderTransition._activeInstances[_ancestorId]!.length > 1;
      timeout -= 1;
    }
    if (timeout > 0) {
      setState(() {
        _forceShowChild = false;
        _clear = true;
      });
    }
  }

  // Future<void> _initializePreAnimatedLayer() async {
  //   // Remove existing listener if any
  //   _removeAnimationListener(widget.animation!, animateFrame);
  //
  //   // Continue with initialization
  //   await _initializeShader();
  //   _shaderUniformsSet = true;
  //   if (widget.animation != null) {
  //     _addAnimationListener(widget.animation!, animateFrame);
  //   }
  // }

  Future<void> _initializePreAnimatedLayer() async {
    _shaderReadyCompleter = Completer<void>();
    _removeAnimationListener(widget.animation!, animateFrame);
    await _initializeShader();
    _shaderUniformsSet = true;
    _shaderReadyCompleter?.complete();

    if (widget.animation != null) {
      _addAnimationListener(widget.animation!, animateFrame);
    }
  }


  void _addAnimationListener(Animation<double> animation, Function() listener) {
    if (!_animationHasListener) {
      animation.addListener(listener);
      _animationHasListener = true;
    }
  }

  void _removeAnimationListener(Animation<double> animation, Function() listener){
    if (_animationHasListener){
      _animationHasListener = false;
      try{
        animation.removeListener(listener);
      }
      catch(e){
        debugPrint(e.toString());
      }
    }
  }

  void _addAnimationStatusListener(Animation<double> animation, Function(AnimationStatus) listener){
    animation.addStatusListener(listener);
    _animationHasStatusListener = true;
  }

  void _removeAnimationStatusListener(Animation<double> animation, Function(AnimationStatus) listener){
    if (_animationHasStatusListener){
      _animationHasStatusListener = false;
      try{
        animation.removeStatusListener(listener);
      }
      catch(e){
        debugPrint(e.toString());
      }
    }
  }

  bool sizeChanged(SizeChangedLayoutNotification? notification) {
    if (notification != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _reset();
        }
      });
      return true;
    }
    return false;
  }

  void _reset() {
    _progress = widget.animation!.value;
    if (widget.animation!.status == AnimationStatus.forward) {
      _shaderUniformsSet = false;
      _shader = null;
      _layoutCapture = false;
      _constraints = null;
      _pixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
      _clear = false;
      _initializePreAnimatedLayer();
    }
  }

  void animateFrame() {
    {
      if (_shader != null && widget.animation != null) {
        _progress = widget.animation!.value;
        setState(() {
          if (_isOldWidget ^ _reverseAnimations) {
            _shader!.setFloat(widget.progressIndex, 1 - _progress);
          } else {
            _shader!.setFloat(widget.progressIndex, _progress);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _removeAnimationListener(widget.animation!, animateFrame);
    _removeAnimationStatusListener(widget.animation!, _animationStatusChange);
    if (ShaderTransition._activeInstances.containsKey(_ancestorId)) {
      ShaderTransition._activeInstances[_ancestorId]!.removeWhere((e) => e == hashCode);
      if (ShaderTransition._activeInstances[_ancestorId]!.isEmpty) {

        /// This indicates that this object's parent AnimatedSwitcher is no longer active. Clears any stored
        /// image captures in the static map.
        ShaderTransition._activeInstances.remove(_ancestorId);
        if (_imageOfChild != null && ShaderTransition._savedImagesMap[_ancestorId] != _imageOfChild) {
          _imageOfChild!.dispose();
          _imageOfChild = null;
        }
        ShaderTransition._savedImagesMap[_ancestorId]?.dispose();
        ShaderTransition._savedImagesMap.remove(_ancestorId);
      }
    }
    super.dispose();
  }

  Future<bool> _initializeShader() async {
    if (widget.shaderBuilder != null) {
      final shader = widget.shaderBuilder!.fragmentShader();

      if (widget.floatUniforms != null) {
        for (var entry in widget.floatUniforms!.entries) {
          shader.setFloat(entry.key, entry.value);
        }
      }
      Size? childSize = await createImageAndGetSize(_childSize);

      await setImageSamplers(shader);

      shader.setFloat(widget.resolutionXIndex, childSize.width);
      shader.setFloat(widget.resolutionYIndex, childSize.height);

      _shader = shader;
      return true;
    }
    return false;
  }

  Future<Size> createImageAndGetSize(Size? existingSize) async {
    Size? childSize = existingSize;
    RenderRepaintBoundary? boundary;
    if (childSize == null || (_shaderMode != ShaderMode.mask && _imageOfChild == null)) {
      boundary = await getChildBoundary();
      childSize = boundary.size;
    }

    if (_shaderMode != ShaderMode.mask && _imageOfChild == null) {
      _imageOfChild = await boundary!.toImage(pixelRatio: _pixelRatio);
      if (_imageOfChild != null) {
        if (ShaderTransition._savedImagesMap.containsKey(_ancestorId!)) {
          _imageOfPreviousChild = ShaderTransition._savedImagesMap[_ancestorId!]!;
        }
        ShaderTransition._savedImagesMap[_ancestorId!] = _imageOfChild!;
      }
    }
    return childSize;
  }

  Future<RenderRepaintBoundary> getChildBoundary() async {
    RenderRepaintBoundary boundary;
    final Completer<RenderRepaintBoundary> completer = Completer();
    if (_constraints == null){
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (_constraints != null) {
          boundary = await WidgetToImage.captureUnrenderedWidgetToBoundary(_child, _constraints!);
          completer.complete(boundary);
        }
      });
      setState(() {
        _layoutCapture = true;
      });
    }
    return completer.future;
  }

  Future<void> setImageSamplers(ui.FragmentShader shader) async {
    if (widget.texture0Index != null) {
      if (_imageOfChild != null) {
        shader.setImageSampler(widget.texture0Index!, _imageOfChild!);
      } else {
        final dummyImage = await WidgetToImage.createTransparentImage();
        shader.setImageSampler(widget.texture0Index!, dummyImage);
      }
    }

    if (widget.texture1Index != null) {
      if (_imageOfPreviousChild != null) {
        shader.setImageSampler(widget.texture1Index!, _imageOfPreviousChild!);
      } else {
        final dummyImage = await WidgetToImage.createTransparentImage();
        shader.setImageSampler(widget.texture1Index!, dummyImage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _pixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

    if (_clear) {
      _removeAnimationListener(widget.animation!, animateFrame);
      return Container();
    } else if (_layoutCapture) {
      return LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
        _constraints = constraints;
        return _isIncomingLayer ? Container() : _child;
      });
    } else if (_forceShowChild) {
      return _child;
    } else {
      // Use FutureBuilder to wait for shader readiness
      return FutureBuilder<void>(
        future: _shaderReadyCompleter?.future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && _shader != null && widget.animation != null && !widget.animation!.isCompleted) {
            // Shader is ready, render with shader effects
            if (_shaderMode == ShaderMode.mask) {
              return ShaderMask(
                shaderCallback: (bounds) => _shader!,
                blendMode: _isOldWidget ^ _reverseAnimations ? BlendMode.dstOut : BlendMode.dstIn,
                child: _child,
              );
            } else if (_imageOfChild != null) {
              return SizedBox(
                width: _imageOfChild!.width.toDouble() / _pixelRatio,
                height: _imageOfChild!.height / _pixelRatio,
                child: ShaderCanvas(
                  shader: _shader!,
                  key: ValueKey(_progress),
                ),
              );
            } else {
              // Image is not ready yet, render child without shader
              return _child;
            }
          } else {
            // Shader is not ready yet, render child without shader to avoid black flash
            return _child;
          }
        },
      );
    }
  }

  // @override
  // Widget build(BuildContext context) {
  //   _pixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
  //
  //   if (_clear) {
  //     _removeAnimationListener(widget.animation!, animateFrame);
  //     return Container();
  //   } else if (_layoutCapture) {
  //     // Capturing layout constraints before proceeding
  //     return LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
  //       _constraints = constraints;
  //       // If this is the incoming layer, we don't render anything yet
  //       // Otherwise, we render the child widget
  //       return _isIncomingLayer ? Container() : _child;
  //     });
  //   } else if (_forceShowChild) {
  //     // If we need to force show the child (e.g., after interruption)
  //     return _child;
  //   } else if (_shader != null && widget.animation != null && _shaderUniformsSet && !widget.animation!.isCompleted) {
  //     // Shader is ready, animation is in progress
  //     if (_shaderMode == ShaderMode.mask) {
  //       return ShaderMask(
  //         shaderCallback: (bounds) {
  //           return _shader!;
  //         },
  //         blendMode: _isOldWidget ^ _reverseAnimations ? BlendMode.dstOut : BlendMode.dstIn,
  //         child: _child,
  //       );
  //     } else {
  //       if (_imageOfChild != null) {
  //         return SizedBox(
  //           width: _imageOfChild!.width.toDouble() / _pixelRatio,
  //           height: _imageOfChild!.height / _pixelRatio,
  //           child: ShaderCanvas(
  //             shader: _shader!,
  //             key: ValueKey(_progress),
  //           ),
  //         );
  //       } else {
  //         // If we don't have the image yet, render the child without shader
  //         return _child;
  //       }
  //     }
  //   } else {
  //     // Shader is not ready yet, or animation is completed
  //     // Render the child without shader effects to avoid black flash
  //     return _child;
  //   }
  // }
}

enum ShaderMode {
  mask,
  singleTexture,
  dualTexture,
}
