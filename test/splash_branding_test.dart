import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_1/core/app/splash_branding.dart';
import 'package:inventory_1/core/theme/app_theme.dart';

void main() {
  late ui.Image image;

  setUp(() async {
    image = await createTestImage(width: 32, height: 32);
  });

  tearDown(() => image.dispose());

  testWidgets('first visible frame contains both decoded logo and copy', (
    tester,
  ) async {
    final logo = _DeferredLogo();
    var readyCount = 0;
    tester.binding.resetFirstFrameSent();

    await tester.pumpWidget(_app(logo: logo, onReady: () => readyCount++));
    await tester.pump();

    expect(tester.binding.sendFramesToEngine, isFalse);
    expect(find.text('Mohajon'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(readyCount, 0);

    // Even if image decoding is slow, text must never appear ahead of it.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.sendFramesToEngine, isFalse);
    expect(find.text('Your partner in business bookkeeping'), findsNothing);

    logo.complete(image.clone());
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(tester.binding.sendFramesToEngine, isTrue);
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    expect(find.text('Mohajon'), findsOneWidget);
    expect(find.text('Your partner in business bookkeeping'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(readyCount, 1);
    expect(tester.takeException(), isNull);

    await tester.pump();
    expect(readyCount, 1);
  });

  testWidgets('a failed logo releases startup with a branded fallback', (
    tester,
  ) async {
    final logo = _DeferredLogo();
    var readyCount = 0;
    tester.binding.resetFirstFrameSent();

    await tester.pumpWidget(_app(logo: logo, onReady: () => readyCount++));
    await tester.pump();
    logo.fail();
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(tester.binding.sendFramesToEngine, isTrue);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('Mohajon'), findsOneWidget);
    expect(readyCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving during decode cannot leave the first frame deferred', (
    tester,
  ) async {
    final logo = _DeferredLogo();
    var readyCount = 0;
    tester.binding.resetFirstFrameSent();

    await tester.pumpWidget(_app(logo: logo, onReady: () => readyCount++));
    await tester.pump();
    expect(tester.binding.sendFramesToEngine, isFalse);

    await tester.pumpWidget(const MaterialApp(home: Text('Next screen')));
    logo.complete(image.clone());
    await tester.pump();

    expect(tester.binding.sendFramesToEngine, isTrue);
    expect(find.text('Next screen'), findsOneWidget);
    expect(readyCount, 0);
    expect(tester.takeException(), isNull);
  });

  for (final locale in [const Locale('bn'), const Locale('en')]) {
    for (final size in [const Size(320, 480), const Size(640, 240)]) {
      testWidgets('splash fits $size with large ${locale.languageCode} text', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final logo = _DeferredLogo()..complete(image.clone());

        await tester.pumpWidget(_app(logo: logo, locale: locale, textScale: 2));
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(
          find.text(locale.languageCode == 'bn' ? 'মহাজন' : 'Mohajon'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}

Widget _app({
  required ImageProvider logo,
  VoidCallback? onReady,
  Locale locale = const Locale('en'),
  double textScale = 1,
}) {
  return MaterialApp(
    theme: AppTheme.light(locale),
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('bn')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: true,
      ),
      child: child!,
    ),
    home: SplashBranding(logo: logo, onReady: onReady),
  );
}

class _DeferredLogo extends ImageProvider<_DeferredLogo> {
  final _image = Completer<ImageInfo>();

  void complete(ui.Image image) => _image.complete(ImageInfo(image: image));

  void fail() => _image.completeError(StateError('Unreadable test logo'));

  @override
  Future<_DeferredLogo> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _DeferredLogo key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_image.future);
  }
}
