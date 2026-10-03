import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/mohajon_warm_theme.dart';

class AuthBrand {
  const AuthBrand._();

  /// Photograph used behind the auth hero and the login/register header.
  /// Drop a replacement at this exact path to swap it in without touching any
  /// layout code.
  static const foliageAsset = 'assets/images/auth_foliage.png';

  /// Image used for the full-bleed welcome screen background.
  static const welcomeAsset = 'assets/images/auth_welcome.png';

  // Palette mirrors MohajonWarm so the auth screens read as part of the same
  // product as Home, Stock and Clients. The deep amber [inkDeep] is the only
  // addition: pure gold fails contrast for buttons and headings, so it is
  // reserved for surfaces while [primary] stays gold and [goldText] carries
  // gold text on light backgrounds.

  static const backgroundColor = MohajonWarm.surface;
  static const panelBackground = Colors.white;
  static const panelBorder = MohajonWarm.goldBorder;

  /// Deep espresso rather than [MohajonWarm.ink]: the olive-tinted ink reads
  /// washed out next to the gold header, while a warm near-black gives the
  /// headings the weight a premium layout needs.
  static const panelText = Color(0xFF1F1B10);

  /// Warm muted copy. Slightly deeper than [MohajonWarm.muted] so the subtitle
  /// holds up against the cream page instead of dissolving into it.
  static const panelMuted = Color(0xFF6E6553);

  static const primary = MohajonWarm.goldText;
  static const primaryDeep = Color(0xFF3B2A06);
  static const secondary = MohajonWarm.orange;
  static const secondarySoft = MohajonWarm.tintYellow;

  /// Input fill. Pure white against the cream page so fields read as raised
  /// cards rather than dissolving into the background.
  static const fieldFill = Colors.white;
  static const fieldBorder = Color(0xFFEFE3C2);
  static const accent = MohajonWarm.orange;
  static const gold = MohajonWarm.primary;
  static const shadow = Color(0xFFB07A00);
  static const danger = MohajonWarm.red;
  static const buttonDisabled = Color(0xFFE6DEC4);
  static const onGold = Color(0xFF3B2A06);

  /// Corner radius shared by every auth surface so the screens feel like one
  /// kit rather than three separate designs.
  static const fieldRadius = BorderRadius.all(Radius.circular(16));
  static const buttonRadius = BorderRadius.all(Radius.circular(16));
  static const panelRadius = BorderRadius.only(
    topLeft: Radius.circular(34),
    topRight: Radius.circular(34),
    bottomLeft: Radius.circular(28),
    bottomRight: Radius.circular(28),
  );

  /// Primary button fill: polished gold, lit from the top left.
  ///
  /// A dark button was tried first and rejected — near-black and espresso both
  /// read as heavy and cheap next to this warm palette. Gold with a deep
  /// espresso label keeps the button unmistakably part of the brand, keeps the
  /// label at roughly 8:1, and looks like a gold plate rather than a slab.
  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFE49B), Color(0xFFFFB300)],
  );

  /// Label colour on [gradient]. Dark rather than white, because white on gold
  /// fails contrast.
  static const onGradient = Color(0xFF3B2A06);

  /// Warm glow under the gold button, so it lifts off the cream page.
  static const buttonGlow = Color(0xFFB07A00);

  /// Sheen laid over [gradient], so the button catches light like a physical
  /// surface instead of reading as a flat swatch.
  static const buttonSheen = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.52],
    colors: [Color(0x59FFFFFF), Color(0x00FFFFFF)],
  );

  static ThemeData theme(ThemeData base) {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: onGradient,
      secondary: accent,
      onSecondary: Colors.white,
      error: danger,
      onError: Colors.white,
      surface: panelBackground,
      onSurface: panelText,
      surfaceContainerHighest: MohajonWarm.tintYellow,
      onSurfaceVariant: panelMuted,
      outline: panelBorder,
      outlineVariant: Color(0xFFF3E7C2),
      shadow: shadow,
      scrim: Colors.black,
      inverseSurface: panelText,
      onInverseSurface: Colors.white,
      inversePrimary: Color(0xFFFFE36E),
    );
    return base.copyWith(
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: backgroundColor,
      textTheme: AppType.textTheme(
        base.textTheme.apply(bodyColor: panelText, displayColor: panelText),
        WidgetsBinding.instance.platformDispatcher.locales.firstOrNull,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        labelStyle: const TextStyle(
          color: panelMuted,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: primary,
        suffixIconColor: panelMuted,
        hintStyle: const TextStyle(color: panelMuted, fontSize: 15),
        border: const OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: fieldBorder),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: fieldBorder),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: danger),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: danger, width: 1.6),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: panelBorder),
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? primary : Colors.white,
        ),
        checkColor: WidgetStateProperty.all(Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: AppType.heading(
            const TextStyle(fontSize: 14),
            locale:
                WidgetsBinding.instance.platformDispatcher.locales.firstOrNull,
            weight: AppType.buttonWeight,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: panelText,
          side: const BorderSide(color: panelBorder),
        ),
      ),
      iconTheme: base.iconTheme.copyWith(color: panelMuted),
      progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
        color: primary,
      ),
      dividerTheme: const DividerThemeData(
        color: fieldBorder,
        space: 1,
        thickness: 1,
      ),
      // Warm-tinted shadows instead of Flutter's neutral grey, which reads as
      // dirt against a cream page.
      cardTheme: const CardThemeData(
        elevation: 0,
        color: panelBackground,
        shadowColor: Color(0x33503C14),
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}

/// The header photograph, shipped as a transparent PNG so the page background
/// shows through its soft edges. A missing or unreadable file degrades to
/// nothing at all rather than to a block of a different colour.
class BotanicalImage extends StatelessWidget {
  const BotanicalImage({
    super.key,
    this.asset = AuthBrand.foliageAsset,
    this.fit = BoxFit.cover,
    this.opacity = 1,
  });

  final String asset;
  final BoxFit fit;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        asset,
        fit: fit,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => const SizedBox.expand(),
      ),
    );
  }
}

/// Page background shared by every auth screen.
///
/// [MohajonWarm.pageGradient] — the exact background Home, Stock, Clients and
/// every other page use. Nothing is stacked on top of it behind the photo: the
/// header image is a transparent PNG, so this one background reads straight
/// through it and continues unbroken below it. That is what keeps the screen
/// from looking like a photo pasted onto a differently coloured panel.
class AuthDecorativeBackdrop extends StatelessWidget {
  const AuthDecorativeBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: MohajonWarm.pageGradient),
    );
  }
}

/// Photo header.
///
/// The artwork is a transparent PNG and nothing is painted behind it, so the
/// page background reads straight through its soft edges. It is deliberately
/// kept smaller than full bleed and dropped below the status bar: a photo that
/// runs edge to edge from the very top of the screen crowds the form and
/// flattens the layout, while an inset hero sitting on the app's gold header
/// gives the screen room to breathe.
///
/// [child] is laid out in the photo's top-left corner (back button, brand
/// disc), so call sites never have to know the status bar height.
class AuthPhotoHeader extends StatelessWidget {
  const AuthPhotoHeader({
    super.key,
    this.topInset = 0,
    this.minHeight = 170,
    this.maxHeight = 280,
    this.horizontalInset = 24,
    this.topGap = 20,
    this.child,
  });

  /// Height of the status bar, so the photo can start just below it.
  final double topInset;

  /// Bounds on the artwork height. In practice the width decides it, because
  /// [maxHeight] is set above `width / _assetRatio` for every width the auth
  /// pages allow, which is what keeps the photo uncropped.
  final double minHeight;
  final double maxHeight;

  /// Page background showing either side of the photo.
  final double horizontalInset;

  /// Breathing room between the status bar and the top of the photo.
  final double topGap;

  /// Back button or brand disc, pinned to the photo's top-left corner.
  final Widget? child;

  /// Aspect ratio of [foliageAsset].
  static const _assetRatio = 1200 / 815;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final artworkWidth = (constraints.maxWidth - horizontalInset * 2).clamp(
          1.0,
          10000.0,
        );
        final height = (artworkWidth / _assetRatio).clamp(minHeight, maxHeight);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: topInset + topGap),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalInset),
              child: SizedBox(
                height: height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const BotanicalImage(fit: BoxFit.contain),
                    if (child != null)
                      Positioned(top: 10, left: 0, child: child!),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Small circular back button that sits on the photo header: a translucent
/// white disc with a deep amber arrow, readable against the golden photo.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Go back',
      child: Material(
        color: Colors.white.withValues(alpha: .90),
        shape: const CircleBorder(side: BorderSide(color: Color(0x1A5C4400))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed ?? () => Navigator.of(context).maybePop(),
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 15,
              color: AuthBrand.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Centered title + subtitle pair. Deep amber heading over muted body copy,
/// carrying the same two voices as the rest of the app.
class AuthHeading extends StatelessWidget {
  const AuthHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.topPadding = 4,
    this.bottomPadding = 22,
  });

  final String title;
  final String subtitle;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppType.heading(
              const TextStyle(
                color: AuthBrand.panelText,
                fontSize: 29,
                letterSpacing: -1,
                height: 1.1,
              ),
              locale: Localizations.localeOf(context),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppType.body(
              const TextStyle(
                color: AuthBrand.panelMuted,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: .1,
                height: 1.35,
              ),
              locale: Localizations.localeOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Input decoration used by every auth field: white fill, hairline warm
/// border, generous height. [leading] sits inside a tinted rounded square so
/// the icon reads as part of the field rather than floating beside it.
class AuthFieldDecoration extends InputDecoration {
  AuthFieldDecoration({
    required String hint,
    required IconData icon,
    Locale? locale,
    super.suffixIcon,
    super.suffix,
    super.errorText,
  }) : super(
         hintText: hint,
         filled: true,
         fillColor: AuthBrand.fieldFill,
         contentPadding: const EdgeInsets.symmetric(
           horizontal: 16,
           vertical: 18,
         ),
         prefixIcon: AuthFieldIcon(icon: icon),
         floatingLabelBehavior: FloatingLabelBehavior.never,
         hintStyle: AppType.body(
           const TextStyle(
             color: AuthBrand.panelMuted,
             fontSize: 15,
             fontWeight: FontWeight.w500,
           ),
           locale: locale,
         ),
         labelStyle: AppType.body(
           const TextStyle(
             color: AuthBrand.panelMuted,
             fontSize: 13.5,
             fontWeight: FontWeight.w500,
           ),
           locale: locale,
         ),
         prefixStyle: AppType.body(
           const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
           locale: locale,
         ),
         border: const OutlineInputBorder(
           borderRadius: AuthBrand.fieldRadius,
           borderSide: BorderSide.none,
         ),
         enabledBorder: const OutlineInputBorder(
           borderRadius: AuthBrand.fieldRadius,
           borderSide: BorderSide(color: AuthBrand.fieldBorder),
         ),
         focusedBorder: const OutlineInputBorder(
           borderRadius: AuthBrand.fieldRadius,
           borderSide: BorderSide(color: AuthBrand.primary, width: 1.6),
         ),
         errorBorder: const OutlineInputBorder(
           borderRadius: AuthBrand.fieldRadius,
           borderSide: BorderSide(color: AuthBrand.danger),
         ),
         focusedErrorBorder: const OutlineInputBorder(
           borderRadius: AuthBrand.fieldRadius,
           borderSide: BorderSide(color: AuthBrand.danger, width: 1.6),
         ),
         errorStyle: AppType.body(
           const TextStyle(
             color: AuthBrand.danger,
             fontSize: 12.5,
             fontWeight: FontWeight.w500,
           ),
           locale: locale,
         ),
       );
}

/// Tinted rounded square that hosts a field's leading icon.
class AuthFieldIcon extends StatelessWidget {
  const AuthFieldIcon({super.key, required this.icon, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(
      widthFactor: 1,
      child: Container(
        margin: const EdgeInsets.all(9),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: AuthBrand.secondarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color ?? AuthBrand.primary, size: 20),
      ),
    );
  }
}

/// "Or continue with" separator: two thin hairlines with the label centred.
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AuthBrand.fieldBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: AppType.body(
              const TextStyle(
                color: AuthBrand.panelMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              locale: Localizations.localeOf(context),
            ),
          ),
        ),
        const Expanded(child: Divider(color: AuthBrand.fieldBorder)),
      ],
    );
  }
}

/// Circular white social-login button. Equal size and spacing across the row,
/// with a whisper-thin border instead of a heavy shadow.
class SocialAuthButton extends StatelessWidget {
  const SocialAuthButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.brandColor,
    this.size = 54,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final Color? brandColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(
            side: BorderSide(color: AuthBrand.fieldBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: brandColor == null
                    ? icon
                    : IconTheme.merge(
                        data: IconThemeData(color: brandColor),
                        child: icon,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The three social providers shown side by side on login and register.
class SocialAuthRow extends StatelessWidget {
  const SocialAuthRow({
    super.key,
    required this.onGoogle,
    required this.onFacebook,
  });

  final VoidCallback? onGoogle;
  final VoidCallback? onFacebook;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SocialAuthButton(
          label: 'Continue with Google',
          brandColor: const Color(0xFF4285F4),
          icon: SvgPicture.asset(
            'assets/brand/google_g.svg',
            width: 21,
            height: 21,
          ),
          onPressed: onGoogle,
        ),
        const SizedBox(width: 18),
        SocialAuthButton(
          label: 'Continue with Facebook',
          brandColor: const Color(0xFF1877F2),
          icon: const Icon(Icons.facebook_rounded, size: 26),
          onPressed: onFacebook,
        ),
      ],
    );
  }
}

/// Footer line such as "Don't have an account? Sign up" with the action
/// highlighted in forest green.
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onPressed,
  });

  final String prompt;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            prompt,
            textAlign: TextAlign.right,
            style: AppType.body(
              const TextStyle(
                color: AuthBrand.panelMuted,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              locale: Localizations.localeOf(context),
            ),
          ),
        ),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AuthBrand.primary,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            action,
            style: AppType.heading(
              const TextStyle(fontSize: 13.5),
              locale: Localizations.localeOf(context),
              weight: AppType.buttonWeight,
            ),
          ),
        ),
      ],
    );
  }
}
