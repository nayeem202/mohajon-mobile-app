import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_typography.dart';
import '../theme/mohajon_warm_theme.dart';

/// Keeps Android's launch screen in place until the complete branding can paint.
class SplashBranding extends StatefulWidget {
  const SplashBranding({
    super.key,
    this.onReady,
    this.logo = const AssetImage('assets/brand/mohajon.png'),
  });

  static const backgroundColor = Color(0xFFFFF8E1);

  final VoidCallback? onReady;
  final ImageProvider logo;

  @override
  State<SplashBranding> createState() => _SplashBrandingState();
}

class _SplashBrandingState extends State<SplashBranding> {
  final _binding = WidgetsBinding.instance;
  bool _frameDeferred = false;
  bool _readyScheduled = false;

  @override
  void initState() {
    super.initState();
    // Text is synchronous, but PNG decoding is not. Send neither to the
    // display until Image has an actual decoded frame to paint alongside it.
    _binding.deferFirstFrame();
    _frameDeferred = true;
  }

  void _releaseFirstFrame() {
    if (!_frameDeferred) return;
    _frameDeferred = false;
    _binding.allowFirstFrame();
  }

  void _scheduleReady() {
    if (_readyScheduled) return;
    _readyScheduled = true;
    _binding.addPostFrameCallback((_) {
      if (!mounted) return;
      _releaseFirstFrame();
      // Notify navigation only after the now-complete frame has been drawn.
      _binding.addPostFrameCallback((_) {
        if (mounted) widget.onReady?.call();
      });
      _binding.scheduleFrame();
    });
  }

  @override
  void dispose() {
    // Balance the deferral even if the route is removed during asset loading.
    _releaseFirstFrame();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final isBangla = AppType.isBengali(locale);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: SplashBranding.backgroundColor,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: SplashBranding.backgroundColor,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final logoSize = math.min(
                (constraints.maxWidth * .5).clamp(96.0, 208.0),
                (constraints.maxHeight * .34).clamp(96.0, 208.0),
              );
              final decodeSize =
                  (logoSize * MediaQuery.devicePixelRatioOf(context)).ceil();
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 24,
                      ),
                      child: Image(
                        image: ResizeImage.resizeIfNeeded(
                          decodeSize,
                          decodeSize,
                          widget.logo,
                        ),
                        width: logoSize,
                        height: logoSize,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                        excludeFromSemantics: true,
                        frameBuilder: (context, child, frame, synchronous) {
                          if (frame == null) return const SizedBox.shrink();
                          _scheduleReady();
                          return _content(
                            logo: child,
                            locale: locale,
                            isBangla: isBangla,
                            reduceMotion: reduceMotion,
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          // An unreadable bundled image must not block startup.
                          _scheduleReady();
                          return _content(
                            logo: SizedBox.square(
                              dimension: logoSize,
                              child: Center(
                                child: Text(
                                  'M',
                                  style: AppType.heading(
                                    const TextStyle(
                                      fontSize: 80,
                                      color: MohajonWarm.goldText,
                                    ),
                                    locale: const Locale('en'),
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            locale: locale,
                            isBangla: isBangla,
                            reduceMotion: reduceMotion,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _content({
    required Widget logo,
    required Locale locale,
    required bool isBangla,
    required bool reduceMotion,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(label: 'Mohajon', image: true, child: logo),
        const SizedBox(height: 16),
        Text(
          isBangla ? 'মহাজন' : 'Mohajon',
          textAlign: TextAlign.center,
          style: AppType.heading(
            const TextStyle(fontSize: 32, color: MohajonWarm.ink, height: 1.3),
            locale: locale,
            weight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isBangla
              ? 'আপনার ব্যবসার হিসাবের সঙ্গী'
              : 'Your partner in business bookkeeping',
          textAlign: TextAlign.center,
          style: AppType.body(
            const TextStyle(
              fontSize: 15,
              color: MohajonWarm.muted,
              height: 1.5,
            ),
            locale: locale,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox.square(
          dimension: 26,
          child: CircularProgressIndicator(
            value: reduceMotion ? .7 : null,
            strokeWidth: 2.5,
            strokeCap: StrokeCap.round,
            color: MohajonWarm.goldText,
            backgroundColor: MohajonWarm.goldBorder,
          ),
        ),
      ],
    );
  }
}
