import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:counter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:integration_test/src/channel.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tap on the floating action button, verify counter',
      (tester) async {
    // Load app widget.
    await tester.pumpWidget(const MyApp());

    // Verify the counter starts at 0.
    expect(find.text('0'), findsOneWidget);

    // Finds the floating action button to tap on.
    final fab = find.byType(FloatingActionButton);

    // Emulate a tap on the floating action button.
    await tester.tap(fab);

    // Trigger a frame.
    await tester.pumpAndSettle();

    // Verify the counter increments by 1.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);

    await takeScreenShot(
      binding: binding,
      fileName: 'counter.png',
      tester: tester,
    );
  });
}

Future<void> takeScreenShot({
  required IntegrationTestWidgetsFlutterBinding binding,
  required String fileName,
  required WidgetTester tester,
}) async {
  if (Platform.isAndroid) {
    await _takeScreenshotForAndroid(
      binding: binding,
      fileName: 'integration_test/screenshots/android/$fileName',
      tester: tester,
    );
  } else {
    await binding.takeScreenshot('integration_test/screenshots/ios/$fileName');
  }
}

Future<void> pumpWithDuration({
  required Duration duration,
  required WidgetTester tester,
  int delayMillisecond = 50,
}) {
  final waitingForRenderer = Completer<void>();
  var afterTime = Duration(milliseconds: duration.inMilliseconds);
  Future.doWhile(() async {
    if (afterTime.inMilliseconds == 0) {
      waitingForRenderer.complete();

      return false;
    }

    await Future.delayed(
      Duration(milliseconds: delayMillisecond),
      () async {
        await tester.pump();
        afterTime = Duration(
          milliseconds: afterTime.inMilliseconds > delayMillisecond
              ? afterTime.inMilliseconds - delayMillisecond
              : 0,
        );
      },
    );

    return true;
  });

  return waitingForRenderer.future;
}

Future<void> _takeScreenshotForAndroid({
  required IntegrationTestWidgetsFlutterBinding binding,
  required String fileName,
  required WidgetTester tester,
}) async {
  await integrationTestChannel.invokeMethod<void>(
    'convertFlutterSurfaceToImage',
  );
  await pumpWithDuration(
      duration: const Duration(milliseconds: 500), tester: tester);

  binding.reportData ??= <String, dynamic>{};
  binding.reportData!['screenshots'] ??= <dynamic>[];
  integrationTestChannel.setMethodCallHandler((MethodCall call) async {
    switch (call.method) {
      case 'scheduleFrame':
        PlatformDispatcher.instance.scheduleFrame();
    }

    return null;
  });

  final rawBytes = await integrationTestChannel.invokeMethod<List<int>>(
      'captureScreenshot', <String, dynamic>{'name': fileName});

  if (rawBytes == null) {
    return;
  }

  final data = <String, dynamic>{'screenshotName': fileName, 'bytes': rawBytes};
  assert(data.containsKey('bytes'));
  (binding.reportData!['screenshots'] as List<dynamic>).add(data);

  await integrationTestChannel.invokeMethod<void>('revertFlutterImage');
}
