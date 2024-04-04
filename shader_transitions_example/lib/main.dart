import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shader_transitions/shader_canvas.dart';
import 'package:shader_transitions/shader_page_route.dart';
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
int _animationDuration = 2000;

final List<Widget> maskShaderWidgets = [
  const ShaderTransitionDemo(name: "Radial\r\n(Alpha Mask)", shaderTransition: getRadialTransition,),
  const ShaderTransitionDemo(name: "Radial\r\n(Alpha Mask)", shaderTransition: getRadialTransition,),
  const ShaderTransitionDemo(name: "Radial\r\n(Alpha Mask)", shaderTransition: getRadialTransition,),
  const ShaderTransitionDemo(name: "Radial\r\n(Alpha Mask)", shaderTransition: getRadialTransition,),

];

final List<Widget> textureShaderWidgets = [
  const ShaderTransitionDemo(name: "Grid Flip\r\n(Dual Texture)", shaderTransition: getGridFlipTransition,),
  const ShaderTransitionDemo(name: "Page Turn\r\n(Dual Texture)", shaderTransition: getPageTurnTransition,),
  const ShaderTransitionDemo(name: "Morph\r\n(Dual Texture)", shaderTransition: getMorphTransition,),
];

List<Widget> _getPages(){
  return [
    ExamplePage(backgroundColor: Colors.grey, child: SizedBox.shrink()),
    ExamplePage(backgroundColor: Colors.tealAccent, child: SizedBox.shrink()),
     //ExamplePage(backgroundColor: Colors.grey, child: buildExamplesGrid(maskShaderWidgets)),
     //ExamplePage(backgroundColor: Colors.tealAccent, child: buildExamplesGrid(textureShaderWidgets)),
  ];
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        // Use an empty Scaffold as the 'starting point'
        body: Builder(
          builder: (BuildContext context) {
            // Schedule a post-frame callback to replace the current 'empty' route
            // with a custom route to Page One after the app is built
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              //Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => MyHomePage(),));
              await Navigator.of(context).pushReplacement(ShaderPageRoute(builder: (context) => MyHomePage(), shaderBuilder: _shaderBuilderRadial!, ancestorKey: UniqueKey()));
            });
            return Container(); // Placeholder for the initial 'nothing' state
          },
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _currentIndex = 0;



  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getPages()[_currentIndex],
    );
  }
}

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key, required this.child, this.backgroundColor});
  final Widget child;
  final Color? backgroundColor;
  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {

  List<String> dropdownItems = <String>['One', 'Two', 'Three', 'Four'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(decoration: BoxDecoration(color: Colors.purpleAccent.withAlpha(100), borderRadius: BorderRadius.all(Radius.circular(40))),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(_instructions,
                        style: TextStyle(color: Colors.grey.shade800, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),),
            ),
            // child: const Column(
            //   children: [
            //     Text("Tap an item below to demonstrate the ShaderTransition in an AnimatedSwitcher. Double-tap to skip rebuild (not recommended for Mask shaders)."),
            //     Text(""),
            //     Text("Change pages in the AppBar to demostrate the ShaderTransition in a PageRoute"),
            //
            //   ],
            // ),
          ),

          Flexible(
            flex: 12,
            child: widget.child,
          ),
          Expanded(flex: 2,
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(color: Colors.purpleAccent.withAlpha(100), borderRadius: const BorderRadius.all(Radius.circular(50))),
                        child: Column(
                          children: [

                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text("Page Navigation Transition",
                                      style: TextStyle(color: Colors.grey.shade800, fontSize: 20,)),
                                ),
                              ),
                            ),
                            Expanded(
                                child: DropdownButton<String>(
                              onChanged: (String? selected){},
                              items: dropdownItems.map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          height: 100,
                          decoration: BoxDecoration(color: Colors.purpleAccent.withAlpha(100), borderRadius: BorderRadius.all(Radius.circular(50))),
                          child: Column(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text("Animation Duration",
                                        style: TextStyle(color: Colors.grey.shade800, fontSize: 20,)),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Slider(
                                  min: 0,
                                  max: 5000,
                                  divisions: 500,
                                  label: "${_animationDuration.toString()}ms",
                                  value: _animationDuration.toDouble(),
                                  onChanged: (double value) {
                                    setState(() {
                                      _animationDuration = value.toInt();
                                    });
                                  },),
                              ),
                            ],
                          ),
                        ),
                      ))
                ],
              )),
          Expanded(
            flex: 2,
              child: Container(
                padding: EdgeInsets.only(top: 10, bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    TextButton(
                      onPressed: () async {
                        await Navigator.of(context).pushReplacement(ShaderPageRoute(builder: (context) => _getPages()[0], shaderBuilder: _shaderBuilderRadial!, ancestorKey: UniqueKey()));
                        },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.layers),
                          Text('Mask Shaders'),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final ancestorKey = UniqueKey();
                        await Navigator.of(context).pushReplacement(ShaderPageRoute(builder: (context) => _getPages()[1], shaderBuilder: _shaderBuilderRadial!, ancestorKey: ancestorKey));
                        },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.image),
                          Text('Texture Shaders'),
                        ],
                      ),
                    ),
                  ],
                ),
              )
          )
        ],
      ),
    );
  }
}



Widget buildExamplesGrid(List<Widget> distinctWidgets) {
  // List of distinct widgets


  return LayoutBuilder(
    builder: (context, constraints) {
      double itemWidth = constraints.maxWidth / 2; // For two columns
      double itemHeight = constraints.maxHeight / 2; // For three rows

      return GridView.builder(
        physics: const NeverScrollableScrollPhysics(), // Disable scrolling
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: itemWidth,
          childAspectRatio: itemWidth / itemHeight,
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

ShaderTransition getRadialTransition(Animation<double> animation, Widget child){
  return ShaderTransition(
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

ShaderTransition getGridFlipTransition(Animation<double> animation, Widget child){
  return ShaderTransition(
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

ShaderTransition getPageTurnTransition(Animation<double> animation, Widget child){
  return ShaderTransition(
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

ShaderTransition getMorphTransition(Animation<double> animation, Widget child){
  return ShaderTransition(
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
  final ShaderTransition Function(Animation<double> animation, Widget child) shaderTransition;
  @override
  State<ShaderTransitionDemo> createState() => _ShaderTransitionDemoState();
}

class _ShaderTransitionDemoState extends State<ShaderTransitionDemo> {
  bool _showWidgetA = true;
  var _forceRebuildKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final child = _showWidgetA ? ExampleWidgetA() : ExampleWidgetB();
    return Center(
      child: GestureDetector(
        onTap: (){
          setState(() {
            _forceRebuildKey = UniqueKey();
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
          children: [
            AnimatedSwitcher(
              key: _forceRebuildKey,
                duration: Duration(milliseconds: _animationDuration),
                child: child,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: widget.shaderTransition(animation, child),
                  );
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
                      padding: const EdgeInsets.all(32.0),
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
  ExampleWidgetA({super.key});

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
  ExampleWidgetB({super.key}){

  }

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

const String _instructions = """
1. Tap an item for widget-to-widget transition (AnimatedSwitcher).
2. Double-Tap item to skip rebuild (better performance, worse interrupt behavior).
3. Select a shader in dropdown and change screens for page route transition.
4. Use slider to adjust transition duration.""";