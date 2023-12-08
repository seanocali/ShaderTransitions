import 'package:flutter/widgets.dart';

class ShaderPageRoute extends PageRouteBuilder {
  final Widget page;
  @override
  final Duration transitionDuration;
  @override
  final Duration reverseTransitionDuration;

  ShaderPageRoute({required this.page,
    this.transitionDuration = const Duration(milliseconds: 500),
    this.reverseTransitionDuration = const Duration(milliseconds: 500)
  })
      : super(
    pageBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        ) => page,
    transitionDuration: transitionDuration,
    reverseTransitionDuration: reverseTransitionDuration,
    transitionsBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget? child,
        ) {
      return DualTransitionBuilder(
        animation: animation,
        forwardBuilder: (BuildContext context, Animation<double> animation, Widget? child) {
          // Incoming transition uses primary animation
          return ScaleTransition(
            scale: animation,
            child: child,
          );
        },
        reverseBuilder: (BuildContext context, Animation<double> secondaryAnimation, Widget? child) {
          // Outgoing transition uses secondary animation
          return FadeTransition(
            opacity: secondaryAnimation,
            child: child,
          );
        },
        child: child,
      );
    },
  );
}
