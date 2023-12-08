import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shader_transitions/shader_canvas.dart';
import 'dart:ui' as ui;

import 'package:shader_transitions/shader_transition.dart';
import 'package:shader_transitions/widget_to_image.dart';


Future<void> main() async {
  _shaderBuilder = await ui.FragmentProgram.fromAsset('shaders/radial.frag');
  runApp(const MyApp());
}

ui.FragmentProgram? _shaderBuilder;


class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shader Switcher Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: //MainPage(),
      ShaderTransitionDemo(),
    );
  }
}

class ShaderTransitionDemo extends StatefulWidget {
  const ShaderTransitionDemo({super.key});

  @override
  State<ShaderTransitionDemo> createState() => _ShaderTransitionDemoState();
}

class _ShaderTransitionDemoState extends State<ShaderTransitionDemo> {
  bool _showGreen = true;
  String animationValue = "";

  Future<Uint8List> convertImageToPNG(ui.Image image) async {
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  final switcherKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final widget = _showGreen ? GreenWidget() : PurpleWidget();
    return Scaffold(
      body: Center(
        child: Container(
          child: AnimatedSwitcher(
              key: switcherKey,
              duration: Duration(milliseconds: 3000),
              child: widget,
              transitionBuilder: (Widget child, Animation<double> animation) {
                bool _isIncoming = animation.status == AnimationStatus.dismissed;
                debugPrint ("+++++++++++++++++");
                String dir = _isIncoming ? "incoming" : "outgoing";
                debugPrint (child.toString() + " is " + dir + " status is " + animation.status.toString() );
                debugPrint ("+++++++++++++++++");


                // Apply the tween to the curved animation
                final shaderTransition = ShaderTransition(
                  switcherKey: switcherKey,
                  shaderBuilder: _shaderBuilder!,
                  animation: animation,
                  reverseAnimations: false,
                  resolutionXIndex: 0,
                  resolutionYIndex: 1,
                  //texture0Index: 0,
                  //texture1Index: 1,
                  child: child,
                  progressIndex: 2,
                  floatUniforms: {
                    3: 1,
                  },
                );
                return shaderTransition;
              }),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
//Navigator.of(context).push(ShaderPageRoute(page: NewPage()));
          setState(() {
            _showGreen = !_showGreen;
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class GreenWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28.0),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment(-0.4, -0.8),
            stops: [0.0, 0.5, 0.5, 1],
            colors: [
              Colors.green,
              Colors.green,
              Colors.limeAccent,
              Colors.limeAccent,
            ],
            tileMode: TileMode.repeated,
          ),
        ),
        width: 800,
        height: 1000,
        child: const Center(child: Text('Green', style: TextStyle(color: Colors.white, fontSize: 24))),
      ),
    );
  }
}

class PurpleWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(58.0),
      child: Container(
        width: 800,
        height: 1000,
        color: Colors.purple,
        child: const Center(child: Text('Purple', style: TextStyle(color: Colors.white, fontSize: 24))),
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
  final _shader = _shaderBuilder!.fragmentShader();
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