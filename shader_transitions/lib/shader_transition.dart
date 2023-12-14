import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '/shader_canvas.dart';
import '/widget_to_image.dart';

//ignore: must_be_immutable
class ShaderTransition extends StatefulWidget {
  /// Only used when in an AnimatedSwitcher and when the shader animates image captures of widgets (textures).
  /// Store the captured image of this ShaderTransition's child so that the next incoming ShaderTransition can use it.
  /// Map key is the stateKey of the parent AnimatedSwitcher.
  static final _savedImagesMap = HashMap<String, List<ui.Image>>();
  static final _activeInstances = HashMap<String, List<Key>>();

  final ui.FragmentProgram? shaderBuilder;
  final Widget child;
  final Animation<double>? animation;

  final Size? childSize;

  /// Shader should contain a uniform vec2 for the resolution. Set the index of the X (width) value here.
  final int resolutionXIndex;

  /// Shader should contain a uniform vec2 for the resolution. Set the index of the Y (height) value here.
  final int resolutionYIndex;

  /// Identify the index of the shader's uniform float that will be set dynamically by the animation controller.
  final int progressIndex;

  /// Use to set all the uniform float values for the shader except resolution x, resolution y, and progress.
  final Map<int, double>? floatUniforms;

  /// Identify the index of the shader's uniform sampler2D for the outgoing image.
  /// Must be left null for alpha mask shaders that don't use textures.
  final int? texture1Index;

  /// Identify the index of the shader's uniform sampler2D for the incoming image.
  /// Must be left null for alpha mask shaders that don't use textures.
  final int? texture0Index;

  /// Reverses the animation direction of the incoming widget.
  final bool reverseAnimations;

  /// Mutable field so siblings can use for dual-texture shaders.
  ui.Image? imageOfChild;


  ShaderTransition({
    required super.key,
    required this.child,
    required this.shaderBuilder,
    required this.animation,
    this.resolutionXIndex = 0,
    this.resolutionYIndex = 1,
    this.progressIndex = 2,
    this.childSize,
    this.floatUniforms,
    this.texture1Index,
    this.texture0Index,
    this.reverseAnimations = false,
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
  String? _switcherId;
  late Widget _child;
  bool _isOldWidget = false;
  double _progress = 0.0;
  bool _shaderUniformsSet = false;
  ui.FragmentShader? _shader;
  bool _layoutCapture = false;
  BoxConstraints? _constraints;
  double _pixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
  bool _clear = false;
  bool _isDisposed = false;
  late Key _stateKey;
  _ShaderTransitionState? _siblingState;

  ShaderMode get _shaderMode {
    if (widget.texture1Index != null && widget.texture0Index != null) {
      return ShaderMode.dualTexture;
    } else if (widget.texture0Index != null) {
      return ShaderMode.singleTexture;
    }
    return ShaderMode.mask;
  }

  @override
  void initState() {
    _switcherId = getSwitcherName();
    _stateKey = UniqueKey();
    _child = NotificationListener<SizeChangedLayoutNotification>(
        onNotification: sizeChanged,
        child: SizeChangedLayoutNotifier(
          child: widget.child,
        ));
    _initialize();
    super.initState();
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

  void _initialize() {
    /// Necessary to track active instances within the same AnimatedSwitcher so that stored images are
    /// removed from memory when no longer needed.

    ShaderTransition? sibling;
    if (_switcherId != null){
      if (!ShaderTransition._activeInstances.containsKey(_switcherId!)) {
        ShaderTransition._activeInstances[_switcherId!] = List.empty(growable: true);
      }
      ShaderTransition._activeInstances[_switcherId]!.add(_stateKey);
      _progress = widget.animation!.value;
      if (_shaderMode == ShaderMode.dualTexture){
         sibling = _getSibling(context);
      }
    }

    _initializeShader(sibling).whenComplete(() {
      _shaderUniformsSet = true;
      if (widget.animation != null) {
        _progress = widget.animation!.value;
        widget.animation!.addListener(_animateFrame);
      }
    });
  }

  String? getSwitcherName(){
    final parentWidget = context.findAncestorStateOfType<State<AnimatedSwitcher>>();
    if (parentWidget != null){
      return parentWidget.toString().split('(').first;
    }
    return null;
  }

  void _reset() {
    _isOldWidget = false;
    _progress = 0.0;
    _shaderUniformsSet = false;
    widget.imageOfChild = null;
    _shader = null;
    _layoutCapture = false;
    _constraints = null;
    _pixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    _clear = false;
    if (ShaderTransition._activeInstances.containsKey(_switcherId)) {
      ShaderTransition._activeInstances.remove(_switcherId);
    }
    _initialize();
  }

  void _animateFrame() {
    {
      if (_isZombie() || _isDisposed) {
        widget.animation!.removeListener(_animateFrame);
        _changeToOutgoingWidget();
        _delayedClear();
        return;
      }

      if (_shader != null && widget.animation != null) {
        _progress = widget.animation!.value;

        if (!_isDisposed){
          setState(() {
            if ((widget.animation!.status == AnimationStatus.reverse) ^ widget.reverseAnimations) {
              _shader!.setFloat(widget.progressIndex, 1 - _progress);
            } else {
              _shader!.setFloat(widget.progressIndex, _progress);
            }
            if (widget.animation!.isCompleted || widget.animation!.isDismissed) {
              _changeToOutgoingWidget();
            }
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (ShaderTransition._activeInstances.containsKey(_switcherId)) {
      ShaderTransition._activeInstances[_switcherId]!.removeWhere((e) => e == _stateKey);

      /// Keep 3 most recent images available for interrupted animations
      while (ShaderTransition._savedImagesMap.containsKey(_switcherId) &&
          ShaderTransition._savedImagesMap[_switcherId]!.length > 3) {
        ShaderTransition._savedImagesMap[_switcherId]!.removeAt(0);
      }
      if (ShaderTransition._activeInstances[_switcherId]!.isEmpty) {
        /// This indicates that this object's parent AnimatedSwitcher is no longer active. Clears any stored
        /// image captures in the static map.
        ShaderTransition._activeInstances.remove(_switcherId);
        ShaderTransition._savedImagesMap.remove(_switcherId);
      }
    }
    super.dispose();
  }

  void _storeImageOfChild() {
    if (_switcherId != null){
      if (!ShaderTransition._savedImagesMap.containsKey(_switcherId!)) {
        ShaderTransition._savedImagesMap[_switcherId!] = List.empty(growable: true);
      }
      ShaderTransition._savedImagesMap[_switcherId]!.add(widget.imageOfChild!);
    }
  }

  void _changeToOutgoingWidget() {
    if (!_isOldWidget) {
      _isOldWidget = true;
      if (widget.imageOfChild != null) {
        _storeImageOfChild();
      }
      if (_shaderMode == ShaderMode.dualTexture || _shaderMode == ShaderMode.singleTexture) {
        _shader = null;
      }
    }
  }

  // A semaphore lock
  bool _shaderIsInitializing = false;
  bool _initializeShaderRequested = false;

  Future<void> _initializeShader(ShaderTransition? sibling) async {
    _initializeShaderRequested = true;
    if (!_shaderIsInitializing) {
      _shaderIsInitializing = true;
      while (_initializeShaderRequested) {
        _initializeShaderRequested = false;
        if (widget.shaderBuilder != null && _shader == null) {
          ui.FragmentShader shader = widget.shaderBuilder!.fragmentShader();
          if (widget.floatUniforms != null) {
            for (var entry in widget.floatUniforms!.entries) {
              try {
                shader.setFloat(entry.key, entry.value);
              } catch (e) {
                debugPrint(
                    'Failed to set shader float uniform at index ${entry.key}: $e.  Ensure shader\'s uniform values match expected indices');
              }
            }
          }
          Size? childSize = widget.childSize;
          RenderRepaintBoundary? boundary;
          if (childSize == null || (_shaderMode != ShaderMode.mask)) {
            boundary = await _getChildBoundary();
            childSize = boundary.size;
          }

          if (_shaderMode != ShaderMode.mask) {
            widget.imageOfChild = await boundary!.toImage(pixelRatio: _pixelRatio);
            debugPrint(widget.key.toString() + " imageOfChild created");
          }

          try {
            shader.setFloat(widget.resolutionXIndex, childSize.width);
            shader.setFloat(widget.resolutionYIndex, childSize.height);
          } catch (e) {
            debugPrint(
                'Failed to set resolution values for shader. Ensure shader\'s uniform values match expected indices');
          }

          await _setImageSamplers(shader, sibling);
          _shader = shader;
        }
      }
      _shaderIsInitializing = false;
    }
  }

  Future<RenderRepaintBoundary> _getChildBoundary() async {
    RenderRepaintBoundary boundary;
    final Completer<RenderRepaintBoundary> completer = Completer();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      boundary = await WidgetToImage.captureUnrenderedWidgetToBoundary(_child, _constraints);
      completer.complete(boundary);
    });
    if (!_isDisposed){
      setState(() {
        _layoutCapture = true;
      });
    }
    return completer.future;
  }

  Future<void> _setImageSamplers(ui.FragmentShader shader, ShaderTransition? sibling) async {
    try {
      if (widget.texture0Index != null) {
        if (widget.imageOfChild != null) {
          shader.setImageSampler(widget.texture0Index!, widget.imageOfChild!);
        } else {
          final dummyImage = await WidgetToImage.createTransparentImage();
          shader.setImageSampler(widget.texture0Index!, dummyImage);
        }
      }

      if (widget.texture1Index != null) {
        if (sibling?.imageOfChild != null){
          shader.setImageSampler(widget.texture1Index!, sibling!.imageOfChild!);
        }
        else{
          final dummyImage = await WidgetToImage.createTransparentImage();
          shader.setImageSampler(widget.texture1Index!, dummyImage);
        }

        // if (ShaderTransition._savedImagesMap.containsKey(_switcherId) &&
        //     ShaderTransition._savedImagesMap[_switcherId]!.isNotEmpty) {
        //   shader.setImageSampler(widget.texture1Index!, ShaderTransition._savedImagesMap[_switcherId]!.last);
        // } else {
        //   final dummyImage = await WidgetToImage.createTransparentImage();
        //   shader.setImageSampler(widget.texture1Index!, dummyImage);
        // }
      }
    } catch (e) {
      debugPrint('Failed to set shader textures. Ensure shader\'s uniform values match expected indices');
    }
  }

  bool _isZombie() {
    if (_shaderMode != ShaderMode.mask && ShaderTransition._activeInstances.containsKey(_switcherId)) {
      final ai = ShaderTransition._activeInstances[_switcherId]!;
      if (ai.length > 2) {
        return (ai.last != _stateKey);
      }
    }
    return false;
  }

  Future<void> _delayedClear() async {
    /// Existing widgets must be cleared from canvas before displaying ShaderCanvas or else
    /// there will be clamping artifacts on some shader animations that have transparency.
    /// Must wait at least one frame to avoid flash of empty frame.
    //await Future.delayed(const Duration(milliseconds: 33));
    if (!_isDisposed){
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _clear = true;
        });
      });
    }
  }

  ShaderTransition? _getSibling(BuildContext context) {
    final parentStack = context.findAncestorWidgetOfExactType<Stack>();
    if (parentStack != null) {
      for(final child in parentStack.children){
        if (child != widget && child is ShaderTransition){
          return child;
        }
        else if (child is KeyedSubtree){
          if (child.child != widget && child.child is ShaderTransition){
            final st = child.child as ShaderTransition;
            debugPrint(st.key.toString() + " found as sibling");
            return child.child as ShaderTransition;
          }
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    _pixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    if (_clear) {
      _clear = false;
      return const SizedBox.shrink();
    }
    if (_layoutCapture) {
      _layoutCapture = false;
      return LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
        _constraints = constraints;
        return _progress < 0.1 ? const SizedBox.shrink() : _child;
      });
    }
    if (_progress == 0.0) {
      return const SizedBox.shrink();
    } else if (_progress == 1.0) {
      if (!_isOldWidget) {
        _changeToOutgoingWidget();
      }
      if (_shaderMode != ShaderMode.mask && !widget.animation!.isCompleted) {
        _delayedClear();
        return _child;
      }
      return _child;
    } else if (_shader != null && widget.animation != null && _shaderUniformsSet && !widget.animation!.isCompleted) {
      if (_shaderMode == ShaderMode.mask) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return _shader!;
          },
          blendMode: _isOldWidget ^ widget.reverseAnimations ? BlendMode.dstOut : BlendMode.dstIn,
          child: _child,
        );
      } else {
        if (widget.imageOfChild != null) {
          return SizedBox(
            width: widget.imageOfChild!.width.toDouble() / _pixelRatio,
            height: widget.imageOfChild!.height / _pixelRatio,
            child: ShaderCanvas(
              shader: _shader!,
              key: ValueKey(_progress),
            ),
          );
        }
      }
    }
    return _child;
  }
}

enum ShaderMode {
  mask,
  singleTexture,
  dualTexture,
}
