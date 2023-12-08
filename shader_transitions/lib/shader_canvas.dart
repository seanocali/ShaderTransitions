import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ShaderCanvas extends StatelessWidget {
  final ui.FragmentShader shader;

  const ShaderCanvas({Key? key, required this.shader}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ShaderCanvasPainter(shader: shader, context: context),
      size: Size.infinite, // This will ensure the shader paints the entire available space.
    );
  }
}

class _ShaderCanvasPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final BuildContext context;
  _ShaderCanvasPainter({required this.shader, required this.context});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate != this;
  }
}
