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
  static final _savedImagesMap = HashMap<String, List<ui.Image>>();
  static final _activeInstances = HashMap<String, List<int>>();

  final ui.FragmentProgram? shaderBuilder;
  final Widget child;
  final Animation<double>? animation;

  /// The key of this widget's parent (an AnimatedSwitcher).
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

  const ShaderTransition({super.key, 
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
  });

  static Future<ui.FragmentShader> fromAsset(String assetKey) async {
    final program = await ui.FragmentProgram.fromAsset(assetKey);
    return program.fragmentShader();
  }

  static Animation<double> getSequentialAnimation(Animation<double> animation){
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

  String get switcherKey => widget.switcherKey.toString();
  bool _isOldWidget = false;
  double _progress = 0.0;
  bool _shaderUniformsSet = false;
  ui.Image? _imageOfChild;
  ui.FragmentShader? _shader;
  bool _layoutCapture = false;
  BoxConstraints? _constraints;
  double _pixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
  bool _clear = false;
  bool _isDisposed = false;
  Size? _childSize;
  ShaderMode get _shaderMode {
    if (widget.texture1Index != null && widget.texture0Index != null){
      return ShaderMode.DualTexture;
    }
    else if (widget.texture0Index != null){
      return ShaderMode.SingleTexture;
    }
    return ShaderMode.Mask;
  }

  @override
  void initState() {
    _childSize = widget.childSize;
    /// Necessary to track active instances within the same AnimatedSwitcher so that stored images are
    /// removed from memory when no longer needed.
    if (!ShaderTransition._activeInstances.containsKey(switcherKey)) {
      ShaderTransition._activeInstances[switcherKey] = List.empty(growable: true);
    }
    ShaderTransition._activeInstances[switcherKey]!.add(hashCode);

    super.initState();
    _progress = widget.animation!.value;
    initializeShader().whenComplete(() {
      _shaderUniformsSet = true;
      if (widget.animation != null) {
        setState(() {
          _progress = widget.animation!.value;
        });
        widget.animation!.addListener(animateFrame);
      } else {
      }
    });
  }

  void animateFrame() {
    {
      if (isZombie() || _isDisposed){
        widget.animation!.removeListener(animateFrame);
        changeToOutgoingWidget();
        delayedClear();
        return;
      }
      if (_shader != null && widget.animation != null) {
        _progress = widget.animation!.value;
        setState(() {
          if (_isOldWidget ^ widget.reverseAnimations){
            _shader!.setFloat(widget.progressIndex, 1 - _progress);
          }
          else{
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
    if (ShaderTransition._activeInstances.containsKey(switcherKey)) {
      ShaderTransition._activeInstances[switcherKey]!.removeWhere((e) => e == hashCode);
      /// Keep 3 most recent images available for interrupted animations
      while (ShaderTransition._savedImagesMap.containsKey(switcherKey) && ShaderTransition._savedImagesMap[switcherKey]!.length > 3){
        ShaderTransition._savedImagesMap[switcherKey]!.removeAt(0);
      }
      if (ShaderTransition._activeInstances[switcherKey]!.isEmpty) {
        /// This indicates that this object's parent AnimatedSwitcher is no longer active. Clears any stored
        /// image captures in the static map.
        ShaderTransition._activeInstances.remove(switcherKey);
        ShaderTransition._savedImagesMap.remove(switcherKey);
      }
    }
    super.dispose();
  }

  void storeImageOfChild(){
    if (!ShaderTransition._savedImagesMap.containsKey(switcherKey)) {
      ShaderTransition._savedImagesMap[switcherKey] = List.empty(growable: true);
    }
    ShaderTransition._savedImagesMap[switcherKey]!.add(_imageOfChild!);
  }

  void changeToOutgoingWidget() {
    if (!_isOldWidget) {
      _isOldWidget = true;
      if (_imageOfChild != null) {
        storeImageOfChild();
      }
      if (_shaderMode == ShaderMode.DualTexture || _shaderMode == ShaderMode.SingleTexture) {
        _shader = null;
      }
    }
  }

  Future<bool> initializeShader() async {
    if (widget.shaderBuilder != null) {
      _shader = widget.shaderBuilder!.fragmentShader();

      if (widget.floatUniforms != null) {
        for (var entry in widget.floatUniforms!.entries) {
          _shader!.setFloat(entry.key, entry.value);
        }
      }

      RenderRepaintBoundary? boundary;
      if (_childSize == null || (_shaderMode != ShaderMode.Mask && _imageOfChild == null)){
        boundary = await getChildBoundary();
        _childSize = boundary.size;
      }

      if  (_shaderMode != ShaderMode.Mask && _imageOfChild == null){
        _imageOfChild = await boundary!.toImage(pixelRatio: _pixelRatio);
      }
      await setImageSamplers();

      _shader!.setFloat(widget.resolutionXIndex, _childSize!.width);
      _shader!.setFloat(widget.resolutionYIndex, _childSize!.height);

      return true;
    }
    return false;
  }

  Future<RenderRepaintBoundary> getChildBoundary() async {
    RenderRepaintBoundary boundary;
    final Completer<RenderRepaintBoundary> completer = Completer();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      boundary = await WidgetToImage.captureUnrenderedWidgetToBoundary(widget.child, _constraints);
      completer.complete(boundary);
    });
    setState(() {
      _layoutCapture = true;
    });
    return completer.future;
  }
  Future<void> setImageSamplers() async {
    if (widget.texture0Index != null){
      if (_imageOfChild != null) {
        _shader!.setImageSampler(widget.texture0Index!, _imageOfChild!);
      }
      else{
        final dummyImage = await WidgetToImage.createTransparentImage();
        _shader!.setImageSampler(widget.texture0Index!, dummyImage);
      }
    }

    if (widget.texture1Index != null){
      if (ShaderTransition._savedImagesMap.containsKey(switcherKey)
          && ShaderTransition._savedImagesMap[switcherKey]!.isNotEmpty) {
        _shader!.setImageSampler(widget.texture1Index!, ShaderTransition._savedImagesMap[switcherKey]!.last);
      }
      else{
        final dummyImage = await WidgetToImage.createTransparentImage();
        _shader!.setImageSampler(widget.texture1Index!, dummyImage);
      }
    }
  }

  bool isZombie(){
    if (_shaderMode != ShaderMode.Mask && ShaderTransition._activeInstances.containsKey(switcherKey)){
      final ai = ShaderTransition._activeInstances[switcherKey]!;
      if (ai.length > 2){
        return (ai.last != hashCode);
      }
    }
    return false;
  }

  Future<void> delayedClear() async{
    /// Existing widgets must be cleared from canvas before displaying ShaderCanvas or else
    /// there will be clamping artifacts on some shader animations that have transparency.
    /// Must wait at least one frame to avoid flash of empty frame.
    await Future.delayed(const Duration(milliseconds: 33));
    if (!_isDisposed){
      setState(() {
        _clear = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _pixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    if (_clear){
      _clear = false;
      return const SizedBox.shrink();
    }
    if (_layoutCapture) {
      _layoutCapture = false;
      return LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
        _constraints = constraints;
        debugPrint(widget.animation!.status.toString());
        return _progress < 0.1 ? const SizedBox.shrink() : widget.child;
      });
    }
    if (_progress == 0.0) {
      return const SizedBox.shrink();
    } else if (_progress == 1.0) {
      if (!_isOldWidget){
        changeToOutgoingWidget();
      }
      if (_shaderMode != ShaderMode.Mask && !widget.animation!.isCompleted){
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          delayedClear();
        });
        return widget.child;
      }
      return widget.child;
    } else if (_shader != null &&
        widget.animation != null &&
        _shaderUniformsSet &&
        !widget.animation!.isCompleted) {
      if (_shaderMode == ShaderMode.Mask) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return _shader!;
          },
          blendMode: _isOldWidget ^ widget.reverseAnimations ? BlendMode.dstOut : BlendMode.dstIn,
          child: widget.child,
        );
      }
      else {
        if (_imageOfChild != null){
          return SizedBox(
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
    return widget.child;
  }
}

enum ShaderMode{
  Mask,
  SingleTexture,
  DualTexture,
}