import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '/shader_canvas.dart';
import '/widget_to_image.dart';
import 'package:synchronized/synchronized.dart';

// class ShaderTransition extends StatefulWidget {
//   /// Only used when in an AnimatedSwitcher and when the shader animates image captures of widgets (textures).
//   /// Store the captured image of this ShaderTransition's child so that the next incoming ShaderTransition can use it.
//   /// Map key is the stateKey of the parent AnimatedSwitcher.
//
//   final ui.FragmentProgram? shaderBuilder;
//   final Widget child;
//   final Animation<double>? animation;
//
//   final Size? childSize;
//
//   /// Shader should contain a uniform vec2 for the resolution. Set the index of the X (width) value here.
//   final int resolutionXIndex;
//
//   /// Shader should contain a uniform vec2 for the resolution. Set the index of the Y (height) value here.
//   final int resolutionYIndex;
//
//   /// Identify the index of the shader's uniform float that will be set dynamically by the animation controller.
//   final int progressIndex;
//
//   /// Use to set all the uniform float values for the shader except resolution x, resolution y, and progress.
//   final Map<int, double>? floatUniforms;
//
//   /// Identify the index of the shader's uniform sampler2D for the outgoing image.
//   /// Must be left null for alpha mask shaders that don't use textures.
//   final int? texture1Index;
//
//   /// Identify the index of the shader's uniform sampler2D for the incoming image.
//   /// Must be left null for alpha mask shaders that don't use textures.
//   final int? texture0Index;
//
//   /// Reverses the animation direction of the incoming widget.
//   final bool reverseAnimations;
//
//
//   const ShaderTransition({
//     required super.key,
//     required this.child,
//     required this.shaderBuilder,
//     required this.animation,
//     this.resolutionXIndex = 0,
//     this.resolutionYIndex = 1,
//     this.progressIndex = 2,
//     this.childSize,
//     this.floatUniforms,
//     this.texture1Index,
//     this.texture0Index,
//     this.reverseAnimations = false,
//   });
//
//   static final _savedImagesMap = HashMap<String, ui.Image>();
//   static final _activeInstances = HashMap<String, List<String>>();
//
//
//   static Future<ui.FragmentShader> fromAsset(String assetKey) async {
//     final program = await ui.FragmentProgram.fromAsset(assetKey);
//     return program.fragmentShader();
//   }
//
//   static Animation<double> getSequentialAnimation(Animation<double> animation) {
//     return Tween(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(
//         parent: animation,
//         curve: const Interval(0.5, 1.0, curve: Curves.linear), // Starts halfway through
//       ),
//     );
//   }
//
//   @override
//   State<ShaderTransition> createState() => _ShaderTransitionState();
// }
//
// class _ShaderTransitionState extends State<ShaderTransition> {
//   String? _switcherId;
//   late Widget _child;
//   double _progress = 0.0;
//   bool _shaderUniformsSet = false;
//   ui.FragmentShader? _shader;
//   bool _layoutCapture = false;
//   BoxConstraints? _constraints;
//   double _pixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
//   bool _clear = false;
//   bool _isDisposed = false;
//   final _lockImages = Lock();
//   final _lockSwitchers = Lock();
//
//   bool _isOutgoing = false;
//
//   ui.Image? _imageOfChild;
//   ui.Image? _imageOfPreviousChild;
//   String? _stateId;
//
//   ShaderMode get _shaderMode {
//     if (widget.texture1Index != null && widget.texture0Index != null) {
//       return ShaderMode.dualTexture;
//     } else if (widget.texture0Index != null) {
//       return ShaderMode.singleTexture;
//     }
//     return ShaderMode.mask;
//   }
//
//   @override
//   void initState() {
//     _stateId = toString()
//         .split('(')
//         .first;
//     widget.animation!.addStatusListener(_statusChange);
//
//     print(toString() + " created " + widget.animation!.status.toString() + " " + _progress.toString() + " " +
//         widget.child.toString());
//     _progress = widget.animation!.value;
//     _switcherId = getSwitcherName();
//     //_printCurrentStatus();
//     _child = NotificationListener<SizeChangedLayoutNotification>(
//         onNotification: sizeChanged,
//         child: SizeChangedLayoutNotifier(
//           child: widget.child,
//         ));
//     _initialize();
//     super.initState();
//   }
//
//   bool sizeChanged(SizeChangedLayoutNotification? notification) {
//     if (notification != null) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         if (mounted) {
//           _reset();
//         }
//       });
//       return true;
//     }
//     return false;
//   }
//
//   void _initialize() {
//     /// Necessary to track active instances within the same AnimatedSwitcher so that stored images are
//     /// removed from memory when no longer needed.
//
//     _initializeShader().whenComplete(() {
//       _shaderUniformsSet = true;
//       if (widget.animation != null && !_isDisposed) {
//         setState(() {
//           _progress = widget.animation!.value;
//         });
//         widget.animation!.addListener(_animateFrame);
//       }
//     });
//   }
//
//   void _statusChange(AnimationStatus status) {
//     // debugPrint(toString() + " Animation status change: " + status.toString());
//     // final sibling = _getSibling(context);
//     // if ((status == AnimationStatus.completed && sibling == null) || status == AnimationStatus.reverse) {
//     //   debugPrint(toString() + " marked as outgoing " + _progress.toString() + " sibling:" + sibling.toString());
//     //   _isOutgoing = true;
//     //   _shader = null;
//     // }
//   }
//
//   String? getSwitcherName() {
//     final parentWidget = context.findAncestorStateOfType<State<AnimatedSwitcher>>();
//     if (parentWidget != null) {
//       return parentWidget
//           .toString()
//           .split('(')
//           .first;
//     }
//     return null;
//   }
//
//   void _reset() {
//     _progress = 0.0;
//     _shaderUniformsSet = false;
//     _imageOfPreviousChild = null;
//     _shader = null;
//     _layoutCapture = false;
//     _constraints = null;
//     _pixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
//     _clear = false;
//     _initialize();
//   }
//
//   void _printCurrentStatus() {
//     debugPrint("--/${toString()}");
//     debugPrint("Animation Progress: $_progress");
//     if (widget.animation != null) {
//       debugPrint("Animation Status: ${widget.animation!.status}");
//     }
//     if (_isDisposed) {
//       debugPrint("Is Disposed--/");
//     }
//     else {
//       debugPrint("Is Active--/");
//     }
//   }
//
//   void _animateFrame() {
//     {
//       if (_shader != null && widget.animation != null) {
//         _progress = widget.animation!.value;
//         if (!_isDisposed) {
//           setState(() {
//             if ((widget.animation?.status == AnimationStatus.reverse) ^ widget.reverseAnimations) {
//               _shader!.setFloat(widget.progressIndex, 1 - _progress);
//             } else {
//               _shader!.setFloat(widget.progressIndex, _progress);
//             }
//           });
//         }
//       }
//     }
//   }
//
//   @override
//   void dispose() {
//     debugPrint(toString() + " disposed");
//     _isDisposed = true;
//     if (ShaderTransition._activeInstances.containsKey(_switcherId)) {
//       ShaderTransition._activeInstances[_switcherId]!.removeWhere((e) => e == _stateId);
//       if (ShaderTransition._activeInstances[_switcherId]!.isEmpty) {
//         /// This indicates that this object's parent AnimatedSwitcher is no longer active. Clears any stored
//         /// image captures in the static map.
//         ShaderTransition._activeInstances.remove(_switcherId);
//         ShaderTransition._savedImagesMap.remove(_switcherId);
//       }
//     }
//     widget.animation!.removeListener(_animateFrame);
//     widget.animation!.removeStatusListener(_statusChange);
//     super.dispose();
//   }
//
//   // A semaphore lock
//   bool _shaderIsInitializing = false;
//   bool _initializeShaderRequested = false;
//
//   Future<void> _initializeShader() async {
//     _initializeShaderRequested = true;
//     if (!_shaderIsInitializing) {
//       _shaderIsInitializing = true;
//       while (_initializeShaderRequested) {
//         _initializeShaderRequested = false;
//
//         /// Necessary to track active instances within the same AnimatedSwitcher so that stored images are
//         /// removed from memory when no longer needed.
//         if (_switcherId != null && _stateId != null) {
//           await _lockSwitchers.synchronized(() {
//             if (!ShaderTransition._activeInstances.containsKey(_switcherId!)) {
//               ShaderTransition._activeInstances[_switcherId!] = List.empty(growable: true);
//             }
//             if (!ShaderTransition._activeInstances[_switcherId]!.contains(_stateId)) {
//               ShaderTransition._activeInstances[_switcherId]!.add(_stateId!);
//             }
//           });
//         }
//
//         if (widget.shaderBuilder != null && _shader == null) {
//           ui.FragmentShader shader = widget.shaderBuilder!.fragmentShader();
//           if (widget.floatUniforms != null) {
//             for (var entry in widget.floatUniforms!.entries) {
//               try {
//                 shader.setFloat(entry.key, entry.value);
//               } catch (e) {
//                 debugPrint(
//                     'Failed to set shader float uniform at index ${entry
//                         .key}: $e.  Ensure shader\'s uniform values match expected indices');
//               }
//             }
//           }
//           Size? childSize = widget.childSize;
//           RenderRepaintBoundary? boundary;
//           if (childSize == null || (_shaderMode != ShaderMode.mask)) {
//             boundary = await _getChildBoundary();
//             childSize = boundary.size;
//           }
//
//           if (_shaderMode == ShaderMode.dualTexture || _shaderMode == ShaderMode.singleTexture) {
//             _imageOfChild = await boundary!.toImage(pixelRatio: _pixelRatio);
//             if (_imageOfChild != null && _switcherId != null) {
//               await _lockImages.synchronized(() {
//                 _imageOfPreviousChild ??= ShaderTransition._savedImagesMap[_switcherId!];
//                 ShaderTransition._savedImagesMap[_switcherId!] = _imageOfChild!;
//               });
//               debugPrint(toString() + " image saved");
//             }
//             else {
//               debugPrint(toString() + " image save failed");
//             }
//           }
//
//           try {
//             shader.setFloat(widget.resolutionXIndex, childSize.width);
//             shader.setFloat(widget.resolutionYIndex, childSize.height);
//           } catch (e) {
//             debugPrint(
//                 'Failed to set resolution values for shader. Ensure shader\'s uniform values match expected indices');
//           }
//
//           await _setImageSamplers(shader);
//           _shader = shader;
//         }
//       }
//       _shaderIsInitializing = false;
//     }
//   }
//
//   Future<RenderRepaintBoundary> _getChildBoundary() async {
//     RenderRepaintBoundary boundary;
//     final Completer<RenderRepaintBoundary> completer = Completer();
//     WidgetsBinding.instance.addPostFrameCallback((_) async {
//       boundary = await WidgetToImage.captureUnrenderedWidgetToBoundary(_child, _constraints);
//       completer.complete(boundary);
//     });
//     if (!_isDisposed) {
//       setState(() {
//         _layoutCapture = true;
//       });
//       if (_isOutgoing) {
//         WidgetsBinding.instance.addPostFrameCallback((_) async {
//           _delayedClear();
//         });
//       }
//     }
//     return completer.future;
//   }
//
//   Future<void> _setImageSamplers(ui.FragmentShader shader) async {
//     try {
//       if (widget.texture0Index != null) {
//         if (_imageOfChild != null) {
//           shader.setImageSampler(widget.texture0Index!, _imageOfChild!);
//         } else {
//           final dummyImage = await WidgetToImage.createTransparentImage();
//           shader.setImageSampler(widget.texture0Index!, dummyImage);
//         }
//       }
//
//       if (widget.texture1Index != null) {
//         if (_imageOfPreviousChild != null) {
//           shader.setImageSampler(widget.texture1Index!, _imageOfPreviousChild!);
//         }
//         else {
//           final dummyImage = await WidgetToImage.createTransparentImage();
//           shader.setImageSampler(widget.texture1Index!, dummyImage);
//         }
//       }
//     } catch (e) {
//       debugPrint('Failed to set shader textures. Ensure shader\'s uniform values match expected indices');
//     }
//   }
//
//   Future<void> _delayedClear() async {
//     /// Existing widgets must be cleared from canvas before displaying ShaderCanvas or else
//     /// there will be clamping artifacts on some shader animations that have transparency.
//     /// Must wait at least one frame to avoid flash of empty frame.
//     await Future.delayed(const Duration(milliseconds: 33));
//     if (!_isDisposed) {
//       setState(() {
//         _clear = true;
//       });
//     }
//   }
//
//   ShaderTransition? _getSibling(BuildContext context) {
//     final parentStack = context.findAncestorWidgetOfExactType<Stack>();
//     if (parentStack != null) {
//       for (final child in parentStack.children) {
//         if (child != widget && child is ShaderTransition) {
//           return child;
//         }
//         else if (child is KeyedSubtree) {
//           if (child.child != widget && child.child is ShaderTransition) {
//             final st = child.child as ShaderTransition;
//             return child.child as ShaderTransition;
//           }
//         }
//       }
//     }
//     return null;
//   }
//
//   List<ShaderTransition> _getSiblings(BuildContext context) {
//     final output = List<ShaderTransition>.empty(growable: true);
//     final parentStack = context.findAncestorWidgetOfExactType<Stack>();
//     if (parentStack != null) {
//       for (final child in parentStack.children) {
//         if (child != widget && child is ShaderTransition) {
//           output.add(child.child as ShaderTransition);
//         }
//         else if (child is KeyedSubtree) {
//           if (child.child != widget && child.child is ShaderTransition) {
//             final st = child.child as ShaderTransition;
//             output.add(child.child as ShaderTransition);
//           }
//         }
//       }
//     }
//     return output;
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     _pixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
//     if (_clear) {
//       _clear = false;
//       return SizedBox.shrink();
//     }
//     if (_layoutCapture) {
//       _layoutCapture = false;
//       return LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
//         _constraints = constraints;
//         debugPrint(widget.animation!.status.toString());
//         return _progress < 0.1 ? SizedBox.shrink() : widget.child;
//       });
//     }
//     if (_progress == 0.0) {
//       return SizedBox.shrink();
//     } else if (_progress == 1.0) {
//       if (!_isOutgoing) {
//         _isOutgoing = true;
//         _shader = null;
//       }
//       if (_shaderMode != ShaderMode.mask && !widget.animation!.isCompleted) {
//         debugPrint(toString() + " delayed clear");
//         WidgetsBinding.instance.addPostFrameCallback((_) async {
//           _delayedClear();
//         });
//         return widget.child;
//       }
//       return widget.child;
//     } else if (_shader != null &&
//         widget.animation != null &&
//         _shaderUniformsSet &&
//         !widget.animation!.isCompleted) {
//       if (_shaderMode == ShaderMode.mask) {
//         return ShaderMask(
//           shaderCallback: (bounds) {
//             return _shader!;
//           },
//           child: widget.child,
//           blendMode: _isOutgoing ^ widget.reverseAnimations ? BlendMode.dstOut : BlendMode.dstIn,
//         );
//       }
//       else {
//         if (_imageOfChild != null) {
//           return SizedBox(
//             width: _imageOfChild!.width.toDouble() / _pixelRatio,
//             height: _imageOfChild!.height / _pixelRatio,
//             child: ShaderCanvas(
//               shader: _shader!,
//               key: ValueKey(_progress),
//             ),
//           );
//         }
//       }
//     }
//     return widget.child;
//   }
// }

enum ShaderMode {
  mask,
  singleTexture,
  dualTexture,
}


















class ShaderTransitionOld extends StatefulWidget {
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

  ShaderTransitionOld({
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
  State<ShaderTransitionOld> createState() => _ShaderTransitionOldState();
}

class _ShaderTransitionOldState extends State<ShaderTransitionOld> {

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
        && ShaderTransitionOld._activeInstances.containsKey(switcherKey)
    && ShaderTransitionOld._activeInstances[switcherKey]!.isNotEmpty){
      _isRebuiltOldWidget = true;
    }

    String rebuiltMsg = _isRebuiltOldWidget ? "Was rebuilt" : "Is Totally New";
    debugPrint(toString() + " created " + widget.animation!.status.toString() + " " + widget.animation!.isCompleted.toString() + " " + _progress.toString() + " " + rebuiltMsg);

    _child = NotificationListener<SizeChangedLayoutNotification>(
        onNotification: sizeChanged,
        child: SizeChangedLayoutNotifier(
          child: widget.child,
        ));


    /// Necessary to track active instances within the same AnimatedSwitcher so that stored images are
    /// removed from memory when no longer needed.
    if (!ShaderTransitionOld._activeInstances.containsKey(switcherKey)) {
      ShaderTransitionOld._activeInstances[switcherKey] = List.empty(growable: true);
    }
    ShaderTransitionOld._activeInstances[switcherKey]!.add(this.hashCode);
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
    if (ShaderTransitionOld._activeInstances.containsKey(switcherKey)) {
      ShaderTransitionOld._activeInstances[switcherKey]!.removeWhere((e) => e == this.hashCode);
      /// Keep 3 most recent images available for interrupted animations
      while (ShaderTransitionOld._savedImagesMap.containsKey(switcherKey) && ShaderTransitionOld._savedImagesMap[switcherKey]!.length > 3){
        ShaderTransitionOld._savedImagesMap[switcherKey]!.removeAt(0);
      }
      if (ShaderTransitionOld._activeInstances[switcherKey]!.isEmpty) {
        /// This indicates that this object's parent AnimatedSwitcher is no longer active. Clears any stored
        /// image captures in the static map.
        ShaderTransitionOld._activeInstances.remove(switcherKey);
        ShaderTransitionOld._savedImagesMap.remove(switcherKey);
      }
    }
    super.dispose();
  }

  void storeImageOfChild(){
    if (!ShaderTransitionOld._savedImagesMap.containsKey(switcherKey)) {
      ShaderTransitionOld._savedImagesMap[switcherKey] = List.empty(growable: true);
    }
    ShaderTransitionOld._savedImagesMap[switcherKey]!.add(_imageOfChild!);
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

    ShaderTransitionOld? _getSibling(BuildContext context) {
    final parentStack = context.findAncestorWidgetOfExactType<Stack>();
    if (parentStack != null) {
      for (final child in parentStack.children) {
        if (child != widget && child is ShaderTransitionOld) {
          return child;
        }
        else if (child is KeyedSubtree) {
          if (child.child != widget && child.child is ShaderTransitionOld) {
            final st = child.child as ShaderTransitionOld;
            return child.child as ShaderTransitionOld;
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
      if (ShaderTransitionOld._savedImagesMap.containsKey(switcherKey)
          && ShaderTransitionOld._savedImagesMap[switcherKey]!.isNotEmpty) {
        shader.setImageSampler(widget.texture1Index!, ShaderTransitionOld._savedImagesMap[switcherKey]!.last);
      }
      else{
        final dummyImage = await WidgetToImage.createTransparentImage();
        shader.setImageSampler(widget.texture1Index!, dummyImage);
      }
    }
  }

  bool isZombie(){
    if (_shaderMode != ShaderMode.mask && ShaderTransitionOld._activeInstances.containsKey(switcherKey)){
      final ai = ShaderTransitionOld._activeInstances[switcherKey]!;
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

  bool neverAgain = false;

  @override
  Widget build(BuildContext context) {
    if (neverAgain){
      return SizedBox.shrink();
    }
    _pixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    if (_clear){
      _clear = false;
      neverAgain = true;
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
