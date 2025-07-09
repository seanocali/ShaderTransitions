import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dual_transition_builder_2.dart';
import 'shader_transition.dart';

class ShaderPageRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;
  final ui.FragmentProgram shaderBuilder;
  final Key ancestorKey;
  static int animateForwardBuilder = 0;
  static int animateReverseBuilder = 0;
  static int secondaryAnimateForwardBuilder = 0;
  static int secondaryAnimateReverseBuilder = 0;
  static void clearCounters(){
    animateForwardBuilder = 0;
    animateReverseBuilder = 0;
    secondaryAnimateForwardBuilder = 0;
    secondaryAnimateReverseBuilder = 0;
  }

  static void printCounters(){
    debugPrint("animateForwardBuilder: $animateForwardBuilder");
    debugPrint("animateReverseBuilder: $animateReverseBuilder");
    debugPrint("secondaryAnimateForwardBuilder: $secondaryAnimateForwardBuilder");
    debugPrint("secondaryAnimateReverseBuilder: $secondaryAnimateReverseBuilder");

  }

  static Animation<double>? _animation;
  static Animation<double>? _secondaryAnimation;

  static Map<Key, ShaderTransition> incomingTransitions = {};
  static Map<Key, ShaderTransition> outgoingTransitions = {};


  ShaderPageRoute({required this.builder, required this.shaderBuilder, required this.ancestorKey})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {

            if (animation.status == AnimationStatus.forward){
              final transition = ShaderTransition(
                animation: animation,
                ancestorKey: ancestorKey,
                shaderBuilder: shaderBuilder,
                floatUniforms: const {3: 1},
                child: child,
              );
              return transition;

            }
            else if (secondaryAnimation.status == AnimationStatus.forward){
                final reverseAnimation = ReverseAnimation(secondaryAnimation);
                final transition = ShaderTransition(
                  animation: reverseAnimation,
                  ancestorKey: ancestorKey,
                  shaderBuilder: shaderBuilder,
                  floatUniforms: const {3: 1},
                  child: child,
                );
                return transition;

            }
            return child;
          },
        );

  @override
  Duration get transitionDuration => const Duration(milliseconds: 2000);
}

class _ShaderTransitionWidget extends StatefulWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;
  final ui.FragmentProgram shaderBuilder;
  final Key ancestorKey;

  const _ShaderTransitionWidget({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
    required this.shaderBuilder,
    required this.ancestorKey,
  });

  @override
  _ShaderTransitionWidgetState createState() => _ShaderTransitionWidgetState();
}

class _ShaderTransitionWidgetState extends State<_ShaderTransitionWidget> {
  bool _shaderReady = false;

  @override
  void initState() {
    super.initState();
    _initializeShader();
  }

  Future<void> _initializeShader() async {
    // Ensure the shader is compiled and ready
    // If any resources (like images) are needed, load them here

    // Simulate asynchronous initialization if needed
    // await Future.delayed(Duration(milliseconds: 100));

    setState(() {
      _shaderReady = true;
     });
  }

  @override
  Widget build(BuildContext context) {
    if (!_shaderReady) {
      // While shader is not ready, display the outgoing page
      return _buildOutgoingPage(context);
    }

    // Shader is ready, proceed with the transition
    if (widget.animation.status == AnimationStatus.forward) {
      return ShaderTransition(
        animation: widget.animation,
        ancestorKey: widget.ancestorKey,
        shaderBuilder: widget.shaderBuilder,
        floatUniforms: const {3: 1},
        child: widget.child,
      );
    } else if (widget.secondaryAnimation.status == AnimationStatus.forward) {
      final reverseAnimation = ReverseAnimation(widget.secondaryAnimation);
      return ShaderTransition(
        animation: reverseAnimation,
        ancestorKey: widget.ancestorKey,
        shaderBuilder: widget.shaderBuilder,
        floatUniforms: const {3: 1},
        child: widget.child,
      );
    }

    // Neither animation is active; display the child without transition
    return widget.child;
  }

  Widget _buildOutgoingPage(BuildContext context) {
    // Return the previous page's content to keep it visible
    // Since we can't directly access the previous page's widget,
    // we can use a placeholder or the current content

    // For this example, we'll return a placeholder
    return Container(color: Colors.black);
  }
}
