// Renders the launcher icon from the app's own font, so the icon and the UI
// are the same type. Run: flutter test tool/make_icon_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const ink = Color(0xFF101011);
const bone = Color(0xFFEBE6DC);
const blue = Color(0xFF3D7BFF);

Widget mark({required bool fullBleed}) {
  // Adaptive foreground: art inside the central 66/108 safe zone.
  final scale = fullBleed ? 1.0 : 66 / 108;
  return Container(
    width: 1024,
    height: 1024,
    color: fullBleed ? ink : Colors.transparent,
    alignment: Alignment.center,
    child: Transform.scale(
      scale: scale,
      child: SizedBox(
        width: 1024,
        height: 1024,
        child: Stack(alignment: Alignment.center, children: [
          Positioned(
            top: 170,
            child: Text(
              'OV',
              style: TextStyle(
                fontFamily: 'Archivo',
                fontSize: 600,
                height: 1,
                color: bone,
                letterSpacing: -10,
                fontVariations: const [FontVariation('wdth', 62), FontVariation('wght', 900)],
              ),
            ),
          ),
          Positioned(
            bottom: 200,
            child: Container(width: 520, height: 64, decoration: BoxDecoration(color: blue, borderRadius: BorderRadius.circular(32))),
          ),
        ]),
      ),
    ),
  );
}

Future<void> render(WidgetTester tester, Widget w, String path) async {
  final key = GlobalKey();
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: RepaintBoundary(key: key, child: w)),
  ));
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('render icon', (tester) async {
    await tester.runAsync(() async {
      final loader = FontLoader('Archivo')
        ..addFont(File('assets/fonts/Archivo.ttf').readAsBytes().then((b) => b.buffer.asByteData()));
      await loader.load();
    });
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1;
    Directory('build/icon').createSync(recursive: true);
    await render(tester, mark(fullBleed: true), 'build/icon/icon.png');
    await render(tester, mark(fullBleed: false), 'build/icon/foreground.png');
  });
}
