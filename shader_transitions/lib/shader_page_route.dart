import 'package:flutter/material.dart';

class ShaderPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final int id;

  ShaderPageRoute({required this.child, required this.id})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            debugPrint(id.toString() +
                ' Primary animation: ' +
                animation.value.toString() +
                " " +
                animation.status.toString());
            debugPrint(id.toString() +
                ' Secondary animation: ' +
                secondaryAnimation.value.toString() +
                " " +
                secondaryAnimation.status.toString());
            return DualTransitionBuilder(
                animation: animation,
                forwardBuilder: (BuildContext context, Animation<double> animation, Widget? child) {
                  return ScaleTransition(
                    scale: animation,
                    child: child,
                  );
                },
                reverseBuilder: (BuildContext context, Animation<double> animation, Widget? child) {
                  return ScaleTransition(
                    scale: ReverseAnimation(secondaryAnimation),
                    child: child,
                  );
                },
                child: DualTransitionBuilder(
                    animation: animation,
                    forwardBuilder: (BuildContext context, Animation<double> animation, Widget? child) {
                      return ScaleTransition(
                        scale: animation,
                        child: child,
                      );
                    },
                    reverseBuilder: (BuildContext context, Animation<double> animation, Widget? child) {
                      return ScaleTransition(
                        scale: ReverseAnimation(animation),
                        child: child,
                      );
                    },
                    child: child));
          },
        );
}
