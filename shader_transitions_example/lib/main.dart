import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shader_transitions/shader_canvas.dart';
import 'dart:ui' as ui;

import 'package:shader_transitions/shader_transition.dart';
import 'package:shader_transitions/widget_to_image.dart';


Future<void> main() async {
  _shaderBuilderRadial = await ui.FragmentProgram.fromAsset('shaders/radial.frag');
  _shaderBuilderGridFlip = await ui.FragmentProgram.fromAsset('shaders/grid_flip.frag');
  _shaderBuilderPageTurn = await ui.FragmentProgram.fromAsset('shaders/page_turn.frag');
  _shaderBuilderMorph = await ui.FragmentProgram.fromAsset('shaders/morph.frag');
  runApp(const MyApp());
}

ui.FragmentProgram? _shaderBuilderRadial;
ui.FragmentProgram? _shaderBuilderGridFlip;
ui.FragmentProgram? _shaderBuilderPageTurn;
ui.FragmentProgram? _shaderBuilderMorph;



class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shader Transition Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: //MainPage(),
      Scaffold(body: buildViewportConstrainedGrid()),
    );
  }
}

// class ShaderTransitionDemo2 extends StatefulWidget {
//   const ShaderTransitionDemo2({super.key});
//
//   @override
//   State<ShaderTransitionDemo2> createState() => _ShaderTransitionDemo2State();
// }
//
// class _ShaderTransitionDemo2State extends State<ShaderTransitionDemo2> {
//   bool _showGreen = true;
//   String animationValue = "";
//
//   Future<Uint8List> convertImageToPNG(ui.Image image) async {
//     final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
//     return byteData!.buffer.asUint8List();
//   }
//
//   final switcherKey = UniqueKey();
//   var rebuildKey = UniqueKey();
//
//   @override
//   Widget build(BuildContext context) {
//     final widget = _showGreen ? ExampleWidgetA() : ExampleWidgetB();
//     return Scaffold(
//       body: Center(
//         child: Container(
//           key: rebuildKey,
//           child: AnimatedSwitcher(
//               key: switcherKey,
//               duration: Duration(milliseconds: 3000),
//               child: widget,
//               transitionBuilder: (Widget child, Animation<double> animation) {
//                 bool _isIncoming = animation.status == AnimationStatus.dismissed;
//                 debugPrint ("+++++++++++++++++");
//                 String dir = _isIncoming ? "incoming" : "outgoing";
//                 debugPrint (child.toString() + " is " + dir + " status is " + animation.status.toString() );
//                 debugPrint ("+++++++++++++++++");
//
//
//                 // Apply the tween to the curved animation
//                 final shaderTransition = ShaderTransitionOld(
//                   switcherKey: switcherKey,
//                   shaderBuilder: _shaderBuilderPageTurn!,
//                   animation: animation,
//                   reverseAnimations: false,
//                   resolutionXIndex: 0,
//                   resolutionYIndex: 1,
//                   texture0Index: 0,
//                   texture1Index: 1,
//                   child: child,
//                   progressIndex: 2,
//                   floatUniforms: {
//                     3: 512,
//                     4: 3,
//                   },
//                 );
//                 return shaderTransition;
//               }),
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () async {
// //Navigator.of(context).push(ShaderPageRoute(page: NewPage()));
//           setState(() {
//             _showGreen = !_showGreen;
//           });
//         },
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
// }






Widget buildViewportConstrainedGrid() {
  // List of distinct widgets
  final List<Widget> distinctWidgets = [
    const ShaderTransitionDemo(name: "Radial\r\n(Alpha Mask)", shaderTransition: getRadialTransition,),
    const ShaderTransitionDemo(name: "Grid Flip\r\n(Dual Texture)", shaderTransition: getGridFlipTransition,),
    const ShaderTransitionDemo(name: "Page Turn\r\n(Dual Texture)", shaderTransition: getPageTurnTransition,),
    const ShaderTransitionDemo(name: "Morph\r\n(Dual Texture)", shaderTransition: getMorphTransition,),

    Container(
      color: Colors.red,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Text('Your Text Here'),
      ),
    ),
    Container(color: Colors.purple), // Fifth distinct widget
    Container(color: Colors.yellow), // Sixth distinct widget
    // Add more widgets as needed
  ];

  return LayoutBuilder(
    builder: (context, constraints) {
      double itemWidth = constraints.maxWidth / 2; // For two columns
      double itemHeight = constraints.maxHeight / 3; // For three rows

      return GridView.builder(
        physics: const NeverScrollableScrollPhysics(), // Disable scrolling
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: itemWidth,
          childAspectRatio: itemWidth / itemHeight,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: distinctWidgets.length,
        itemBuilder: (context, index) {
          // Use the widget from the list based on the index
          return distinctWidgets[index];
        },
      );
    },
  );
}

ShaderTransitionOld getRadialTransition(Key key, Animation<double> animation, Widget child){
  return ShaderTransitionOld(
    switcherKey: key,
    shaderBuilder: _shaderBuilderRadial,
    animation: animation,
    reverseAnimations: false,
    resolutionXIndex: 0,
    resolutionYIndex: 1,
    progressIndex: 2,
    floatUniforms: const {
      3: 1,
    },
    child: child,
  );
}

ShaderTransitionOld getGridFlipTransition(Key key, Animation<double> animation, Widget child){
  return ShaderTransitionOld(
    switcherKey: key,
    shaderBuilder: _shaderBuilderGridFlip,
    animation: animation,
    reverseAnimations: false,
    resolutionXIndex: 0,
    resolutionYIndex: 1,
    texture0Index: 0,
    texture1Index: 1,
    progressIndex: 2,
    floatUniforms: const {
      3: .1,
      4: .05,
      5: 0,
      6: 0,
      7: 0,
      8: 0,
      9: 0.1,
    },
    child: child,
  );
}

ShaderTransitionOld getPageTurnTransition(Key key, Animation<double> animation, Widget child){
  return ShaderTransitionOld(
    switcherKey: key,
    shaderBuilder: _shaderBuilderPageTurn,
    animation: animation,
    reverseAnimations: false,
    resolutionXIndex: 0,
    resolutionYIndex: 1,
    texture0Index: 0,
    texture1Index: 1,
    progressIndex: 2,
    floatUniforms: const {
      3: 512,
      4: 3,
    },
    child: child,
  );
}

ShaderTransitionOld getMorphTransition(Key key, Animation<double> animation, Widget child){
  return ShaderTransitionOld(
    switcherKey: key,
    shaderBuilder: _shaderBuilderMorph,
    animation: animation,
    reverseAnimations: false,
    resolutionXIndex: 0,
    resolutionYIndex: 1,
    texture0Index: 0,
    texture1Index: 1,
    progressIndex: 2,
    floatUniforms: const {
      3: 0.1,
    },
    child: child,
  );
}

class ShaderTransitionDemo extends StatefulWidget {
  const ShaderTransitionDemo( {super.key, required this.name, required this.shaderTransition});
  final String name;
  final ShaderTransitionOld Function(Key key, Animation<double> animation, Widget child) shaderTransition;
  @override
  State<ShaderTransitionDemo> createState() => _ShaderTransitionDemoState();
}

class _ShaderTransitionDemoState extends State<ShaderTransitionDemo> {
  bool _showWidgetA = true;
  final _switcherKey = UniqueKey();
  var _rebuildKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final child = _showWidgetA ? const ExampleWidgetA() : const ExampleWidgetB();
    return Center(
      child: GestureDetector(
        onTap: (){
          setState(() {
            _rebuildKey = UniqueKey();
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _showWidgetA = !_showWidgetA;
            });
          });
        },
        // onTap: (){
        //   setState(() {
        //     _showWidgetA = !_showWidgetA;
        //   });
        // },
        onDoubleTap: () {
          setState(() {
            _showWidgetA = !_showWidgetA;
          });
        },

        child: Stack(
          key: _rebuildKey,
          children: [
            AnimatedSwitcher(
              key: _switcherKey,
                duration: const Duration(milliseconds: 3000),
                child: child,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return widget.shaderTransition(_switcherKey, animation, child);
                }
                ),
            Container(
              child: Align(
                alignment: Alignment.topLeft,
                child: FractionallySizedBox(
                  widthFactor: 0.3,
                  heightFactor: 0.3,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(widget.name,
                          style: TextStyle(color: Colors.grey.shade800, fontSize: 40, fontStyle: FontStyle.italic)),
                    ),
                  ),
                ),
              ),
            ),
          ],

        ),
      ),
    );
  }
}

class ExampleWidgetA extends StatelessWidget {
  const ExampleWidgetA({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28.0),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment(-0.4, -0.8),
            stops: [0.0, 0.5, 0.5, 1],
            colors: [
              Colors.grey,
              Colors.green,
              Colors.teal,
              Colors.lightGreen,
            ],
            tileMode: TileMode.repeated,
          ),
        ),
        child:
        const Center(child: Opacity(opacity: 0.5, child: FittedBox(fit: BoxFit.contain, child: Text('A', style: TextStyle(color: Colors.grey, fontSize: 140))))),
      ),
    );
  }
}

class ExampleWidgetB extends StatelessWidget {
  const ExampleWidgetB({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(56.0),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment(-0.4, -0.8),
            stops: [0.0, 0.5, 0.5, 1],
            colors: [
              Colors.red,
              Colors.redAccent,
              Colors.purpleAccent,
              Colors.purple,
            ],
            tileMode: TileMode.repeated,
          ),
        ),
        child:
        const Center(child: Opacity(opacity: 0.5, child: FittedBox(fit: BoxFit.contain, child: Text('B', style: TextStyle(color: Colors.grey, fontSize: 140))))),
      ),
    );
  }
}

// class ShaderSwitcherDemo extends StatefulWidget {
//   const ShaderSwitcherDemo({Key? key}) : super(key: key);
//
//   @override
//   _ShaderSwitcherDemoState createState() => _ShaderSwitcherDemoState();
// }
//
// class _ShaderSwitcherDemoState extends State<ShaderSwitcherDemo> {
//   bool _showGreen = true;
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Shader Switcher Demo'),
//       ),
//       body: ShaderSwitcher(
//         assetKey: 'shaders/push.frag',
//         duration: const Duration(seconds: 2),
//         progressIndex: 0,
//         floatUniforms: {
//           1: MediaQuery.of(context).size.width.toDouble(),
//           2: MediaQuery.of(context).size.height.toDouble(),
//           3: 0.0,
//           4: 1.0,
//         },
//         outgoingTextureIndex: 0,
//         incomingTextureIndex: 1,
//         sampler2DUniforms: {},
//         child: _showGreen ? GreenWidget() : PurpleWidget(),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () {
//           setState(() {
//             _showGreen = !_showGreen;
//           });
//         },
//         child: const Icon(Icons.switch_left),
//       ),
//     );
//   }
// }

class StaticTextureShaderTest extends StatefulWidget {
  const StaticTextureShaderTest({super.key});

  @override
  State<StaticTextureShaderTest> createState() => _StaticTextureShaderTestState();
}

class _StaticTextureShaderTestState extends State<StaticTextureShaderTest> {
  final _shader = _shaderBuilderRadial!.fragmentShader();
  bool _shaderReady = false;
  double _progress = 0.0; // Initializing the progress value

  void setShaderUniforms() async {
    _shader.setFloat(0, 800.0);
    _shader.setFloat(1, 600.0);
    ui.Image testImage1 = await WidgetToImage.loadImage('assets/maxresdefault.jpg');
    ui.Image testImage2 = await WidgetToImage.loadImage('assets/Untitled-1.png');

    _shader.setImageSampler(0, testImage1);
    _shader.setImageSampler(1, testImage2);

    _shader.setFloat(2, _progress); // Setting the progress value to the shader

    setState(() {
      _shaderReady = true;
    });
  }

  void _incrementProgress() {
    setState(() {
      _progress += 0.1;
      _shader.setFloat(2, _progress);
    });
  }

  void _decrementProgress() {
    setState(() {
      _progress -= 0.1;
      _shader.setFloat(2, _progress);
    });
  }

  @override
  void initState() {
    super.initState();
    setShaderUniforms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Shader Test')),
      body: Column(
        children: [
          Expanded(child: _shaderReady ? ShaderCanvas(shader: _shader) : Placeholder()),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(onPressed: _decrementProgress, child: Text("- 0.1")),
              SizedBox(width: 16),
              ElevatedButton(onPressed: _incrementProgress, child: Text("+ 0.1")),
            ],
          )
        ],
      ),
    );
  }
}