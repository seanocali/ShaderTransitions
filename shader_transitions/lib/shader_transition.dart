import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '/shader_canvas.dart';
import '/widget_to_image.dart';
import 'package:synchronized/synchronized.dart';

class ShaderTransition extends StatefulWidget {
  /// Only used when in an AnimatedSwitcher and when the shader animates image captures of widgets (textures).
  /// Store the captured image of this ShaderTransition's child so that the next incoming ShaderTransition can use it.
  /// Map key is the hashCode of the parent AnimatedSwitcher.
  static final _savedImagesMap = HashMap<String, ui.Image>();
  static final _activeInstances = HashMap<String, HashSet<int>>();

  final ui.FragmentProgram? shaderBuilder;
  final Widget child;
  final Animation<double>? animation;

  /// The key of the parent AnimatedSwitcher The key should be defined outside of the build scope
  /// and stored as a final variable so that it remains the same value during rebuilds.
  final Key switcherKey;

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

  ShaderTransition({
    required this.switcherKey,
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
    Key? key,
  });

  static Future<ui.FragmentShader> fromAsset(String assetKey) async {
    final program = await ui.FragmentProgram.fromAsset(assetKey);
    return program.fragmentShader();
  }

  static Animation<double> getSequentialAnimation(Animation<double> animation) {
    return Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: Interval(0.5, 1.0, curve: Curves.linear), // Starts halfway through
      ),
    );
  }

  @override
  State<ShaderTransition> createState() => _ShaderTransitionState();
}

class _ShaderTransitionState extends State<ShaderTransition> {

  late Widget _child;
  late String switcherKey;

  // String get switcherKey => widget.switcherKey.toString();
  bool _isOldWidget = false;
  double _progress = 0.0;
  bool _shaderUniformsSet = false;
  ui.Image? _imageOfPreviousChild;
  ui.Image? _imageOfChild;
  ui.FragmentShader? _shader;
  bool _layoutCapture = false;
  BoxConstraints? _constraints;
  double _pixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
  bool _clear = false;
  bool _isDisposed = false;

  ShaderMode get _shaderMode {
    if (widget.texture1Index != null && widget.texture0Index != null) {
      return ShaderMode.dualTexture;
    }
    else if (widget.texture0Index != null) {
      return ShaderMode.singleTexture;
    }
    return ShaderMode.mask;
  }

  bool _isIncomingLayer = false;
  bool _forceShowChild = false;

  @override
  void initState() {
    switcherKey = context
        .findAncestorStateOfType<State<AnimatedSwitcher>>()
        .toString()
        .split('(')
        .first;
    debugPrint("switcherKey is " + switcherKey);

    _child = NotificationListener<SizeChangedLayoutNotification>(
        onNotification: sizeChanged,
        child: SizeChangedLayoutNotifier(
          child: widget.child,
        ));
    /// Necessary to track active instances within the same AnimatedSwitcher so that stored images are
    /// removed from memory when no longer needed.
    if (!ShaderTransition._activeInstances.containsKey(switcherKey)) {
      ShaderTransition._activeInstances[switcherKey] = HashSet<int>();
    }
    ShaderTransition._activeInstances[switcherKey]!.add(this.hashCode);

    if (widget.animation!.status == AnimationStatus.forward) {
      _isIncomingLayer = true;
    }

    //
    // debugPrint(toString() + " created " + widget.animation!.status.toString() + " " +
    //     widget.animation!.isCompleted.toString() + " " + _progress.toString());
    // debugPrint("Child hashCode: " + widget.child.hashCode.toString());


    _progress = widget.animation!.value;


    super.initState();

    if (widget.animation!.isCompleted && _shaderMode != ShaderMode.mask){
      _forceShowChild = true;
      _initializedRebuiltCompletedLayer();
    }
    else {
      _initializePreAnimatedLayer();
    }
  }

  Future<void> _initializedRebuiltCompletedLayer() async{

      await createImageAndGetSize(widget.childSize);
      int timeout = 150;
  bool siblingExists = false;
      while (timeout > 0 && !siblingExists){
        await Future.delayed(const Duration(milliseconds: 1));
        siblingExists = ShaderTransition._activeInstances[switcherKey]!.length > 1;
        timeout -= 1;
      }
      if (timeout > 0){
        debugPrint("Timeout is " + timeout.toString());
        setState(() {
          _forceShowChild = false;
          delayedClear();
        });
      }
  }

  Future<void> _initializePreAnimatedLayer() async{
    await initializeShader();
    _shaderUniformsSet = true;
    if (!_isDisposed && widget.animation != null) {
      widget.animation!.addListener(animateFrame);
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
    _progress = 0.0;
    _shaderUniformsSet = false;
    _shader = null;
    _layoutCapture = false;
    _constraints = null;
    _pixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    _clear = false;
    _initializePreAnimatedLayer();
  }

  void animateFrame() {
    {
      if (isZombie() || _isDisposed) {
        widget.animation!.removeListener(animateFrame);
        changeToOutgoingWidget();
        delayedClear();
        return;
      }
      if (!_isDisposed && _shader != null && widget.animation != null) {
        _progress = widget.animation!.value;
        setState(() {
          if (_isOldWidget ^ widget.reverseAnimations) {
            _shader!.setFloat(widget.progressIndex, 1 - _progress);
          }
          else {
            _shader!.setFloat(widget.progressIndex, _progress);
          }
          if (widget.animation!.isCompleted || widget.animation!.isDismissed) {
            changeToOutgoingWidget();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    debugPrint(toString() + " disposed");
    debugPrint("Active AnimatedSwitchers: " + ShaderTransition._activeInstances.length.toString());
    debugPrint("Stored Images: " + ShaderTransition._savedImagesMap.length.toString());

    if (ShaderTransition._activeInstances.containsKey(switcherKey)) {
      ShaderTransition._activeInstances[switcherKey]!.removeWhere((e) => e == this.hashCode);

      /// Keep 3 most recent images available for interrupted animations
      debugPrint(ShaderTransition._activeInstances[switcherKey]!.length.toString());
      if (ShaderTransition._activeInstances[switcherKey]!.isEmpty) {
        /// This indicates that this object's parent AnimatedSwitcher is no longer active. Clears any stored
        /// image captures in the static map.
        ShaderTransition._activeInstances.remove(switcherKey);
        ShaderTransition._savedImagesMap.remove(switcherKey);
      }
    }
    super.dispose();
  }

  void storeImageOfChild() {
    if (ShaderTransition._savedImagesMap.containsKey(switcherKey)) {
      _imageOfPreviousChild = ShaderTransition._savedImagesMap[switcherKey]!;
    }
    ShaderTransition._savedImagesMap[switcherKey] = _imageOfChild!;
  }

  void changeToOutgoingWidget() {
    _isIncomingLayer = false;
    if (!_isOldWidget) {
      _isOldWidget = true;
      if (_shaderMode == ShaderMode.dualTexture || _shaderMode == ShaderMode.singleTexture) {
        _shader = null;
      }
    }
  }

  Future<bool> initializeShader() async {
    if (widget.shaderBuilder != null) {
      final shader = widget.shaderBuilder!.fragmentShader();

      if (widget.floatUniforms != null) {
        for (var entry in widget.floatUniforms!.entries) {
          shader.setFloat(entry.key, entry.value);
        }
      }
      Size? childSize = await createImageAndGetSize(widget.childSize);

      await setImageSamplers(shader);

      shader.setFloat(widget.resolutionXIndex, childSize.width);
      shader.setFloat(widget.resolutionYIndex, childSize.height);

      _shader = shader;
      return true;
    }
    return false;
  }

  Future<Size> createImageAndGetSize(Size? existingSize) async{
    Size? childSize = existingSize;
    RenderRepaintBoundary? boundary;
    if (childSize == null || (_shaderMode != ShaderMode.mask && _imageOfChild == null)) {
      boundary = await getChildBoundary();
      childSize = boundary.size;
    }

    if (_shaderMode != ShaderMode.mask && _imageOfChild == null) {
      _imageOfChild = await boundary!.toImage(pixelRatio: _pixelRatio);
      if (_imageOfChild != null) {
        storeImageOfChild();
      }
    }
    return childSize;
  }

  ShaderTransition? _getSibling(BuildContext context) {
    final parentStack = context.findAncestorWidgetOfExactType<Stack>();
    if (parentStack != null) {
      for (final child in parentStack.children) {
        if (child != widget && child is ShaderTransition) {
          return child;
        }
        else if (child is KeyedSubtree) {
          if (child.child != widget && child.child is ShaderTransition) {
            final st = child.child as ShaderTransition;
            return child.child as ShaderTransition;
          }
        }
      }
    }
    return null;
  }

  Future<RenderRepaintBoundary> getChildBoundary() async {
    RenderRepaintBoundary boundary;
    final Completer<RenderRepaintBoundary> completer = Completer();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      boundary = await WidgetToImage.captureUnrenderedWidgetToBoundary(_child, _constraints);
      completer.complete(boundary);
    });
    if (!_isDisposed) {
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
      }
      else {
        final dummyImage = await WidgetToImage.createTransparentImage();
        shader.setImageSampler(widget.texture0Index!, dummyImage);
      }
    }

    if (widget.texture1Index != null) {
      if (_imageOfPreviousChild != null) {
        shader.setImageSampler(widget.texture1Index!, _imageOfPreviousChild!);
      }
      else {
        final dummyImage = await WidgetToImage.createTransparentImage();
        shader.setImageSampler(widget.texture1Index!, dummyImage);
      }
    }
  }

  bool isZombie() {
    if (_shaderMode != ShaderMode.mask && ShaderTransition._activeInstances.containsKey(switcherKey)) {
      final ai = ShaderTransition._activeInstances[switcherKey]!;
      if (ai.length > 2) {
        return (ai.last != this.hashCode);
      }
    }
    return false;
  }

  Future<void> delayedClear() async {
    /// Existing widgets must be cleared from canvas before displaying ShaderCanvas or else
    /// there will be clamping artifacts on some shader animations that have transparency.
    /// Must wait at least one frame to avoid flash of empty frame.
    await Future.delayed(Duration(milliseconds: 33));
    if (!_isDisposed) {
      setState(() {
        _clear = true;
      });
    }
  }

  String lastOutputName = "";

  @override
  Widget build(BuildContext context) {
    Widget output = _child;
    _pixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    if (_clear) {
      output = SizedBox.shrink();
    }

    else if (_layoutCapture) {
      _layoutCapture = false;
        output = LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
          _constraints = constraints;
          return _progress < 0.1 ? SizedBox.shrink() : _child;
        });
    }
    else if (_forceShowChild){
      output = _child;
    }
    else if (_progress == 0.0) {
      output = SizedBox.shrink();
    } else if (_progress == 1.0) {
      if (!_isOldWidget) {
        changeToOutgoingWidget();
      }
      if (_shaderMode != ShaderMode.mask && !widget.animation!.isCompleted) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          delayedClear();
        });
      }
      return _child;
    } else if (_shader != null &&
        widget.animation != null &&
        _shaderUniformsSet &&
        !widget.animation!.isCompleted) {
      if (_shaderMode == ShaderMode.mask) {
        output = ShaderMask(
          shaderCallback: (bounds) {
            return _shader!;
          },
          child: _child,
          blendMode: _isOldWidget ^ widget.reverseAnimations ? BlendMode.dstOut : BlendMode.dstIn,
        );
      }
      else {
        if (_imageOfChild != null) {
          output = SizedBox(
            width: _imageOfChild!.width.toDouble() / _pixelRatio,
            height: _imageOfChild!.height / _pixelRatio,
            child: ShaderCanvas(
              shader: _shader!,
              key: ValueKey(_progress),
            ),
          );
        }
      }
    }
    if (lastOutputName != output.toString()){
      lastOutputName = output.toString();
      String m = _isIncomingLayer ? " Is Incoming " : " Is Outgoing ";
      debugPrint(toString() + m + " output frame changed to " + lastOutputName);
    }
    return output;
  }
}

enum ShaderMode {
  mask,
  singleTexture,
  dualTexture,
}