import 'dart:async';
import 'dart:ui' as ui;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class WidgetToImage{

  static Future<ui.Image> createTransparentImage() {
    final Completer<ui.Image> completer = Completer();

    Uint8List pixels = Uint8List.fromList([0, 0, 0, 0]); // 1x1 transparent pixel (R=0, G=0, B=0, A=0)

    try{
      ui.decodeImageFromPixels(pixels, 1, 1, ui.PixelFormat.rgba8888, (ui.Image image) {
        completer.complete(image);
      });
    }
    catch (e){
      debugPrint('Failed to decode image from bytes');
      completer.completeError(e);
    }

    return completer.future;
  }

  static Future<ui.Image> loadImage(String assetKey) async {
    // Load asset as data
    final ByteData data = await rootBundle.load(assetKey);
    final bytes = data.buffer.asUint8List();

    // Decode data to create an ui.Image
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(Uint8List.fromList(bytes), (ui.Image img) {
      completer.complete(img);
    });

    return completer.future;
  }

  static Future<ui.Image?> captureUnrenderedWidgetAsImage(Widget widget, BoxConstraints constraints) async{
    final boundary = await captureUnrenderedWidgetToBoundary(widget, constraints);
    final double pixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    return await boundary.toImage(pixelRatio: pixelRatio);
    return null;
  }

  static Future<RenderRepaintBoundary> captureUnrenderedWidgetToBoundary(Widget widget, BoxConstraints constraints) async {
    final completer = Completer<RenderRepaintBoundary>();
    final RenderRepaintBoundary boundary = RenderRepaintBoundary();
    final platformDispatcher = WidgetsBinding.instance.platformDispatcher;
    final fallBackView = platformDispatcher.views.first;
    final view = fallBackView;
    final Locale currentLocale = WidgetsBinding.instance.platformDispatcher.locales.first;
    final screenSize = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
    final double pixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

    // Use constraints to determine size
    final logicalSize = Size(
      constraints.hasBoundedWidth ? constraints.maxWidth : screenSize.width / pixelRatio,
      constraints.hasBoundedHeight ? constraints.maxHeight : screenSize.height / pixelRatio,
    );

    final RenderView renderView = RenderView(
      view: view,
      child: RenderPositionedBox(child: boundary),
      configuration: ViewConfiguration(size: logicalSize, devicePixelRatio: pixelRatio),
    );

    final pipelineOwner = PipelineOwner();
    final buildOwner = BuildOwner(
      focusManager: FocusManager(),
      onBuildScheduled: () {},
    );

    pipelineOwner.rootNode = renderView;
    renderView.prepareInitialFrame();

    RenderObjectToWidgetElement<RenderBox> rootElement;

    final preRender = RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
      child: MediaQuery(
        data: MediaQueryData(size: logicalSize, devicePixelRatio: pixelRatio),
        child: Localizations(
          locale: currentLocale,
          delegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          child: Directionality(
            textDirection: TextDirection.ltr, // Consider dynamic setting for RTL languages
            child: widget,
          ),
        ),
      ),
    );

    try{
      rootElement = preRender.attachToRenderTree(buildOwner);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        buildOwner.buildScope(rootElement);
        buildOwner.finalizeTree();
        pipelineOwner.flushLayout();
        pipelineOwner.flushCompositingBits();
        pipelineOwner.flushPaint();
        completer.complete(boundary);
      });
    }
    catch (e){
      debugPrint(e.toString());
    }

    return completer.future;
  }

}

