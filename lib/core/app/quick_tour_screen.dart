import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../constants/app_constants.dart';
import '../localization/app_localizations.dart';
import '../theme/mohajon_warm_theme.dart';
import '../../features/auth/presentation/login_screen.dart';

class QuickTourScreen extends StatefulWidget {
  const QuickTourScreen({super.key, this.includeWelcome = true});

  /// When false (opened from Settings for a logged-in user) the pre-login
  /// "Welcome" slide is skipped and only the post-login feature slides show.
  final bool includeWelcome;

  @override
  State<QuickTourScreen> createState() => _QuickTourScreenState();
}

class _QuickTourScreenState extends State<QuickTourScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  int get _slideCount => widget.includeWelcome ? 5 : 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    Hive.box(HiveBoxes.settings).put('hasSeenOnboarding', true);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _next() {
    if (_currentPage >= _slideCount - 1) {
      _finish();
      return;
    }
    _controller.animateToPage(
      _currentPage + 1,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLast = _currentPage == _slideCount - 1;

    final slides = <_Slide>[
      if (widget.includeWelcome)
        _Slide(
          hero: Image.asset(
            'assets/brand/mohajon.png',
            width: 130,
            height: 130,
            fit: BoxFit.contain,
          ),
          title: l10n.t('welcomeToMohajon'),
          description: l10n.t('tourWelcomeDesc'),
        ),
      _Slide(
        hero: const _SlideIcon(icon: Icons.dashboard_rounded, color: MohajonWarm.goldText),
        title: l10n.t('tourDashboardTitle'),
        description: l10n.t('tourDashboardDesc'),
      ),
      _Slide(
        hero: const _SlideIcon(icon: Icons.point_of_sale_rounded, color: MohajonWarm.green),
        title: l10n.t('tourPosTitle'),
        description: l10n.t('tourPosDesc'),
      ),
      _Slide(
        hero: const _SlideIcon(icon: Icons.inventory_2_rounded, color: MohajonWarm.orange),
        title: l10n.t('tourStockTitle'),
        description: l10n.t('tourStockDesc'),
      ),
      _Slide(
        hero: const _SlideIcon(icon: Icons.people_alt_rounded, color: MohajonWarm.goldText),
        title: l10n.t('tourClientsTitle'),
        description: l10n.t('tourClientsDesc'),
      ),
    ];

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 12, 0),
                  child: TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: MohajonWarm.muted,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    child: Text(l10n.t('skip')),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slideCount,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemBuilder: (context, index) {
                    final slide = slides[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              color: MohajonWarm.card,
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(color: MohajonWarm.goldBorder, width: 1.4),
                              boxShadow: [
                                BoxShadow(
                                  color: MohajonWarm.primary.withValues(alpha: 0.35),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: slide.hero,
                          ),
                          const SizedBox(height: 34),
                          Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: MohajonWarm.ink,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            slide.description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                              color: MohajonWarm.muted,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 22),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slideCount, (i) {
                        final active = i == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active ? MohajonWarm.primary : MohajonWarm.goldBorder,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MohajonWarm.primary,
                          foregroundColor: MohajonWarm.ink,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: Text(isLast ? l10n.t('getStarted') : l10n.t('next')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({
    required this.hero,
    required this.title,
    required this.description,
  });

  final Widget hero;
  final String title;
  final String description;
}

class _SlideIcon extends StatelessWidget {
  const _SlideIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: 58, color: color);
  }
}