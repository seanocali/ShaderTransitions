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

  // static void incomingAnimationStatusChanged(){
  //   if (_animation != null && _animation!.status != AnimationStatus.forward){
  //     try{
  //       _animation!.removeListener(outgoingAnimationStatusChanged);
  //       debugPrint(" removed incominglistener");
  //     }
  //     catch(e){
  //       debugPrint(e.toString());
  //     }
  //     _animation = null;
  //     ShaderPageRoute.incomingTransitions.clear();
  //   }
  //   else{
  //     ShaderPageRoute.incomingTransitions.clear();
  //   }
  // }
  //
  // static void outgoingAnimationStatusChanged(){
  //   if (_secondaryAnimation != null && _secondaryAnimation!.status != AnimationStatus.forward){
  //     try{
  //       _secondaryAnimation!.removeListener(outgoingAnimationStatusChanged);
  //       debugPrint(" removed outgoinglistener");
  //     }
  //     catch(e){
  //       debugPrint(e.toString());
  //     }
  //       _secondaryAnimation = null;
  //       ShaderPageRoute.outgoingTransitions.clear();
  //   }
  //   else{
  //     ShaderPageRoute.outgoingTransitions.clear();
  //   }
  // }


  ShaderPageRoute({required this.builder, required this.shaderBuilder, required this.ancestorKey})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {

            if (animation.status == AnimationStatus.forward){
                return ShaderTransition(
                  animation: animation,
                  ancestorKey: ancestorKey,
                  shaderBuilder: shaderBuilder,
                  floatUniforms: const {3: 1},
                  child: child,
                );
                _animation = animation;
                //debugPrint(" added incominglistener");
                //animation.addListener(incomingAnimationStatusChanged);

            }
            else if (secondaryAnimation.status == AnimationStatus.forward){
                final reverseAnimation = ReverseAnimation(secondaryAnimation);
                return ShaderTransition(
                  animation: reverseAnimation,
                  ancestorKey: ancestorKey,
                  shaderBuilder: shaderBuilder,
                  floatUniforms: const {3: 1},
                  child: child,
                );
                _secondaryAnimation = reverseAnimation;
                //debugPrint(" added outgoinglistener");
                //reverseAnimation.addListener(outgoingAnimationStatusChanged);

            }
            return child;



            // if (animation.status == AnimationStatus.forward){
            //   if (!incomingTransitions.containsKey(ancestorKey)){
            //     incomingTransitions[ancestorKey] = ShaderTransition(
            //       animation: animation,
            //       ancestorKey: ancestorKey,
            //       shaderBuilder: shaderBuilder,
            //       floatUniforms: const {3: 1},
            //       child: child,
            //     );
            //     _animation = animation;
            //     debugPrint(" added incominglistener");
            //     animation.addListener(incomingAnimationStatusChanged);
            //   }
            //   //debugPrint("Primary" + animation.status.toString() + " " + animation.value.toString());
            //       return incomingTransitions[ancestorKey]!;
            // }
            // else if (secondaryAnimation.status == AnimationStatus.forward){
            //   if (!outgoingTransitions.containsKey(ancestorKey)){
            //     final reverseAnimation = ReverseAnimation(secondaryAnimation);
            //     final status = reverseAnimation.status;
            //     outgoingTransitions[ancestorKey] = ShaderTransition(
            //       animation: reverseAnimation,
            //       ancestorKey: ancestorKey,
            //       shaderBuilder: shaderBuilder,
            //       floatUniforms: const {3: 1},
            //       child: child,
            //     );
            //     _secondaryAnimation = reverseAnimation;
            //     debugPrint(" added outgoinglistener");
            //     reverseAnimation.addListener(outgoingAnimationStatusChanged);
            //   }
            //   //debugPrint("Secondary" + secondaryAnimation.status.toString() + " " + secondaryAnimation.value.toString());
            //   return outgoingTransitions[ancestorKey]!;
            // }
            // return child;
            //


            // return DualTransitionBuilder2(
            //   animation: animation,
            //   forwardBuilder: (
            //       BuildContext context,
            //       Animation<double> animation,
            //       Widget? child,
            //       ) {
            //     debugPrint("Returned forwardBuilder " + animation.status.toString() + " " + animation.value.toString());
            //     animateForwardBuilder++;
            //     return ShaderTransition(
            //       animation: animation,
            //       ancestorKey: ancestorKey,
            //       shaderBuilder: shaderBuilder,
            //       floatUniforms: const {3: 1},
            //       child: child!,
            //     );
            //     //return child!;
            //   },
            //   reverseBuilder: (
            //       BuildContext context,
            //       Animation<double> animation,
            //       Widget? child,
            //       ) {
            //     debugPrint("Returned reverseBuilder " + animation.status.toString() + " " + animation.value.toString());
            //     animateReverseBuilder++;
            //     return child!;
            //     //return ScaleTransition(scale: ReverseAnimation(animation), child: child);
            //   },
            //   child: DualTransitionBuilder2(
            //     animation: ReverseAnimation(secondaryAnimation),
            //     forwardBuilder: (
            //         BuildContext context,
            //         Animation<double> animation,
            //         Widget? child,
            //         ) {
            //       debugPrint("Returned secondaryForwardBuilder " + secondaryAnimation.status.toString() + " " + secondaryAnimation.value.toString());
            //       secondaryAnimateForwardBuilder++;
            //       return child!;
            //       //return ScaleTransition(scale: animation, child: child);
            //     },
            //     reverseBuilder: (
            //         BuildContext context,
            //         Animation<double> animation,
            //         Widget? child,
            //         ) {
            //       debugPrint("Returned secondaryReverseBuilder " + secondaryAnimation.status.toString() + " " + secondaryAnimation.value.toString());
            //       secondaryAnimateReverseBuilder++;
            //       //return child!;
            //       return ShaderTransition(
            //         animation: secondaryAnimation,
            //         ancestorKey: ancestorKey,
            //         shaderBuilder: shaderBuilder,
            //         floatUniforms: const {3: 1},
            //         child: child!,
            //       );
            //       //return outgoingTransitions[ancestorKey]!;
            //     },
            //     child: child,
            //   ),
            // );

            // return DualTransitionBuilder2(
            //   animation: animation,
            //   forwardBuilder: (
            //       BuildContext context,
            //       Animation<double> animation,
            //       Widget? child,
            //       ) {
            //     debugPrint("Returned forwardBuilder " + animation.status.toString() + " " + animation.value.toString());
            //     animateForwardBuilder++;
            //     return ScaleTransition(scale: animation, child: child);
            //     //return child!;
            //   },
            //   reverseBuilder: (
            //       BuildContext context,
            //       Animation<double> animation,
            //       Widget? child,
            //       ) {
            //     debugPrint("Returned reverseBuilder " + animation.status.toString() + " " + animation.value.toString());
            //     animateReverseBuilder++;
            //     return child!;
            //     //return ScaleTransition(scale: ReverseAnimation(animation), child: child);
            //   },
            //   child: DualTransitionBuilder2(
            //     animation: ReverseAnimation(secondaryAnimation),
            //     forwardBuilder: (
            //         BuildContext context,
            //         Animation<double> animation,
            //         Widget? child,
            //         ) {
            //       debugPrint("Returned secondaryForwardBuilder " + secondaryAnimation.status.toString() + " " + secondaryAnimation.value.toString());
            //       secondaryAnimateForwardBuilder++;
            //       return child!;
            //       //return ScaleTransition(scale: animation, child: child);
            //     },
            //     reverseBuilder: (
            //         BuildContext context,
            //         Animation<double> animation,
            //         Widget? child,
            //         ) {
            //       debugPrint("Returned secondaryReverseBuilder " + secondaryAnimation.status.toString() + " " + secondaryAnimation.value.toString());
            //       secondaryAnimateReverseBuilder++;
            //       return ScaleTransition(scale: ReverseAnimation(animation), child: child);
            //       //return outgoingTransitions[ancestorKey]!;
            //     },
            //     child: child,
            //   ),
            // );



//             final ancestorKey = UniqueKey();
//             final incomingTransition = ShaderTransition(
//               animation: animation,
//               ancestorKey: UniqueKey(), // Consider if you need a new key each time
//               shaderBuilder: shaderBuilder,
//               floatUniforms: const {3: 1},
//               child: child,
//             );
//
//             final outgoingTransition = ShaderTransition(
//               animation: secondaryAnimation,
//               ancestorKey: UniqueKey(), // Consider if you need a new key each time
//               shaderBuilder: shaderBuilder,
//               floatUniforms: const {3: 1},
//               child: child,
//             );
//
//
//             debugPrint("ancestorKey: " + ancestorKey.toString() + animation.status.toString() + " " + secondaryAnimation.status.toString());
//             if (animation.status == AnimationStatus.forward) {
//               return incomingTransition;
//             } else if (secondaryAnimation.status == AnimationStatus.forward) {
//              return outgoingTransition;
//             }
// return child;

            // return DualTransitionBuilder(
            //   animation: animation,
            //   forwardBuilder: (
            //       BuildContext context,
            //       Animation<double> animation,
            //       Widget? child,
            //       ) {
            //     return ShaderTransition(
            //         animation: animation,
            //         ancestorKey: ancestorKey,
            //         shaderBuilder: shaderBuilder,
            //         floatUniforms: const {3 : 1},
            //         child: child!);
            //   },
            //   reverseBuilder: (
            //       BuildContext context,
            //       Animation<double> animation,
            //       Widget? child,
            //       ) {
            //     return ShaderTransition(
            //         animation: animation,
            //         reverseAnimations: true,
            //         ancestorKey: ancestorKey,
            //         shaderBuilder: shaderBuilder,
            //         floatUniforms: const {3 : 1},
            //         child: child!);
            //   },
            //   child: DualTransitionBuilder(
            //     animation: secondaryAnimation,
            //     forwardBuilder: (
            //         BuildContext context,
            //         Animation<double> animation,
            //         Widget? child,
            //         ) {
            //       return ShaderTransition(
            //           animation: animation,
            //           reverseAnimations: true,
            //           ancestorKey: ancestorKey,
            //           shaderBuilder: shaderBuilder,
            //           floatUniforms: const {3 : 1},
            //           child: child!);
            //     },
            //     reverseBuilder: (
            //         BuildContext context,
            //         Animation<double> animation,
            //         Widget? child,
            //         ) {
            //       final hasMediaQuery = MediaQuery.maybeOf(context) != null;
            //       return ShaderTransition(
            //           animation: animation,
            //           ancestorKey: ancestorKey,
            //           shaderBuilder: shaderBuilder,
            //           floatUniforms: const {3 : 1},
            //           child: child!);
            //     },
            //     child: child,
            //   ),
            // );
          },
        );

  @override
  Duration get transitionDuration => const Duration(milliseconds: 2000);
}
