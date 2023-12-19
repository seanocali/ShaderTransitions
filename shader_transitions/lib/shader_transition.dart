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

  static Animation<double> getSequentialAnimation(Animation<double> animation){
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
  ShaderMode get _shaderMode {
    if (widget.texture1Index != null && widget.texture0Index != null){
      return ShaderMode.dualTexture;
    }
    else if (widget.texture0Index != null){
      return ShaderMode.singleTexture;
    }
    return ShaderMode.mask;
  }

  bool _isRebuiltOldWidget = false;

  @override
  void initState() {

    if (widget.animation!.isCompleted
        && ShaderTransition._activeInstances.containsKey(switcherKey)
    && ShaderTransition._activeInstances[switcherKey]!.isNotEmpty){
      _isRebuiltOldWidget = true;
    }

    debugPrint(toString() + " created " + widget.animation!.status.toString() + " " + widget.animation!.isCompleted.toString() + " " + _progress.toString());

    _child = NotificationListener<SizeChangedLayoutNotification>(
        onNotification: sizeChanged,
        child: SizeChangedLayoutNotifier(
          child: widget.child,
        ));


    /// Necessary to track active instances within the same AnimatedSwitcher so that stored images are
    /// removed from memory when no longer needed.
    if (!ShaderTransition._activeInstances.containsKey(switcherKey)) {
      ShaderTransition._activeInstances[switcherKey] = List.empty(growable: true);
    }
    ShaderTransition._activeInstances[switcherKey]!.add(this.hashCode);
    super.initState();
    _initialize();
  }



  void _initialize(){
    _progress = widget.animation!.value;
    initializeShader().whenComplete(() {
      _shaderUniformsSet = true;
      if (!_isDisposed && widget.animation != null) {
        setState(() {
          _progress = widget.animation!.value;
        });
        widget.animation!.addListener(animateFrame);
      }
    });
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
    _initialize();
  }

  void animateFrame() {
    {
      if (isZombie() || _isDisposed){
        widget.animation!.removeListener(animateFrame);
        changeToOutgoingWidget();
        delayedClear();
        return;
      }
      if (!_isDisposed && _shader != null && widget.animation != null) {
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
    debugPrint(toString() + " disposed");
    if (ShaderTransition._activeInstances.containsKey(switcherKey)) {
      ShaderTransition._activeInstances[switcherKey]!.removeWhere((e) => e == this.hashCode);
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
      Size? childSize = widget.childSize;
      RenderRepaintBoundary? boundary;
      if (childSize == null || (_shaderMode != ShaderMode.mask && _imageOfChild == null)){
        boundary = await getChildBoundary();
        childSize = boundary.size;
      }

      if  (_shaderMode != ShaderMode.mask && _imageOfChild == null){
        _imageOfChild = await boundary!.toImage(pixelRatio: _pixelRatio);
      }
      await setImageSamplers(shader);

      shader.setFloat(widget.resolutionXIndex, childSize!.width);
      shader.setFloat(widget.resolutionYIndex, childSize!.height);

      _shader = shader;
      return true;
    }
    return false;
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
    if (!_isDisposed){
      setState(() {
        _layoutCapture = true;
      });
    }

    return completer.future;
  }
  Future<void> setImageSamplers(ui.FragmentShader shader) async {
    if (widget.texture0Index != null){
      if (_imageOfChild != null) {
        shader.setImageSampler(widget.texture0Index!, _imageOfChild!);
      }
      else{
        final dummyImage = await WidgetToImage.createTransparentImage();
        shader.setImageSampler(widget.texture0Index!, dummyImage);
      }
    }

    if (widget.texture1Index != null){
      if (ShaderTransition._savedImagesMap.containsKey(switcherKey)
          && ShaderTransition._savedImagesMap[switcherKey]!.isNotEmpty) {
        shader.setImageSampler(widget.texture1Index!, ShaderTransition._savedImagesMap[switcherKey]!.last);
      }
      else{
        final dummyImage = await WidgetToImage.createTransparentImage();
        shader.setImageSampler(widget.texture1Index!, dummyImage);
      }
    }
  }

  bool isZombie(){
    if (_shaderMode != ShaderMode.mask && ShaderTransition._activeInstances.containsKey(switcherKey)){
      final ai = ShaderTransition._activeInstances[switcherKey]!;
      if (ai.length > 2){
        return (ai.last != this.hashCode);
      }
    }
    return false;
  }

  Future<void> delayedClear() async{
    /// Existing widgets must be cleared from canvas before displaying ShaderCanvas or else
    /// there will be clamping artifacts on some shader animations that have transparency.
    /// Must wait at least one frame to avoid flash of empty frame.
    await Future.delayed(Duration(milliseconds: 33));
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
      return SizedBox.shrink();
    }

    if (_layoutCapture) {
      _layoutCapture = false;
      return LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
        _constraints = constraints;
        return _progress < 0.1 ? SizedBox.shrink() : _child;
      });
    }
    if (_progress == 0.0) {
      return SizedBox.shrink();
    } else if (_progress == 1.0) {
      if (!_isOldWidget){
        changeToOutgoingWidget();
      }
      if (_shaderMode != ShaderMode.mask && !widget.animation!.isCompleted){
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          delayedClear();
        });
        return _child;
      }
      return _child;
    } else if (_shader != null &&
        widget.animation != null &&
        _shaderUniformsSet &&
        !widget.animation!.isCompleted) {
      if (_shaderMode == ShaderMode.mask) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return _shader!;
          },
          child: _child,
          blendMode: _isOldWidget ^ widget.reverseAnimations ? BlendMode.dstOut : BlendMode.dstIn,
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
    return _child;
  }
}

enum ShaderMode {
  mask,
  singleTexture,
  dualTexture,
}