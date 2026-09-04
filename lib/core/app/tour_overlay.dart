import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../theme/mohajon_warm_theme.dart';
import 'tour_models.dart';

class TourOverlay extends StatefulWidget {
  const TourOverlay({
    super.key,
    required this.steps,
    required this.currentIndex,
    required this.onNext,
    required this.onSkip,
    required this.onFinish,
  });

  final List<TourStep> steps;
  final int currentIndex;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onFinish;

  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<TourOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Rect? _getTargetRect() {
    final key = widget.steps[widget.currentIndex].targetKey;
    final obj = key.currentContext?.findRenderObject();
    if (obj == null || !obj.attached) return null;
    if (obj is! RenderBox) return null;
    final box = obj;
    final offset = box.localToGlobal(Offset.zero);
    return offset & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final step = widget.steps[widget.currentIndex];
    final isLast = widget.currentIndex == widget.steps.length - 1;
    final screen = MediaQuery.of(context).size;
    final target = _getTargetRect();

    if (target == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return const SizedBox.shrink();
    }

    const padding = 12.0;
    final highlightRect = Rect.fromLTWH(
      target.left - padding,
      target.top - padding,
      target.width + padding * 2,
      target.height + padding * 2,
    );

    // Tooltip position: prefer below, fallback above
    const tooltipMaxWidth = 300.0;
    const tooltipGap = 16.0;
    const tooltipEstimatedHeight = 200.0;
    final spaceBelow = screen.height - highlightRect.bottom - tooltipGap;
    final spaceAbove = highlightRect.top - tooltipGap;
    final showBelow = spaceBelow >= 120 || spaceBelow > spaceAbove;

    var tooltipTop = showBelow
        ? highlightRect.bottom + tooltipGap
        : highlightRect.top - tooltipGap - tooltipEstimatedHeight;
    final tooltipLeft = math.max(
      16.0,
      math.min(
        highlightRect.center.dx - tooltipMaxWidth / 2,
        screen.width - tooltipMaxWidth - 16,
      ),
    );

    // Keep the tooltip fully on screen
    tooltipTop = tooltipTop.clamp(12.0, screen.height - tooltipEstimatedHeight - 12);

    final total = widget.steps.length;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final pulse = 4.0 + _pulseController.value * 4.0;
        return Stack(
          children: [
            // Dim background + highlight cutout
            GestureDetector(
              onTap: () {},
              child: CustomPaint(
                size: screen,
                painter: _HighlightPainter(
                  highlightRect: highlightRect,
                  pulseWidth: pulse,
                ),
              ),
            ),

            // Tooltip card
            Positioned(
              top: tooltipTop,
              left: tooltipLeft,
              width: tooltipMaxWidth,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: MohajonWarm.goldBorder,
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: MohajonWarm.primary.withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Step counter
                      Text(
                        '${widget.currentIndex + 1} / $total',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: MohajonWarm.muted,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Title
                      Text(
                        step.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: MohajonWarm.ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Description
                      Text(
                        step.description,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: MohajonWarm.muted,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Buttons
                      Row(
                        children: [
                          if (!isLast)
                            TextButton(
                              onPressed: widget.onSkip,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                l10n.t('skipAll'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: MohajonWarm.muted,
                                ),
                              ),
                            ),
                          const Spacer(),
                          SizedBox(
                            height: 36,
                            child: ElevatedButton(
                              onPressed: isLast ? widget.onFinish : widget.onNext,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MohajonWarm.primary,
                                foregroundColor: MohajonWarm.ink,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                isLast ? l10n.t('finish') : l10n.t('next'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HighlightPainter extends CustomPainter {
  _HighlightPainter({
    required this.highlightRect,
    required this.pulseWidth,
  });

  final Rect highlightRect;
  final double pulseWidth;

  @override
  void paint(Canvas canvas, Size size) {
    // Use saveLayer so BlendMode.clear works correctly
    canvas.saveLayer(Offset.zero & size, Paint());

    // Dim overlay
    final dimPaint = Paint()..color = const Color(0x88000000);
    canvas.drawRect(Offset.zero & size, dimPaint);

    // Cut out highlight area
    final clearPaint = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(highlightRect, const Radius.circular(16)),
      clearPaint,
    );

    canvas.restore();

    // Glow border (outside saveLayer)
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = pulseWidth
      ..color = MohajonWarm.primary.withValues(alpha: 0.7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(highlightRect, const Radius.circular(16)),
      glowPaint,
    );

    // Solid border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = MohajonWarm.primary;
    canvas.drawRRect(
      RRect.fromRectAndRadius(highlightRect, const Radius.circular(16)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(_HighlightPainter old) =>
      highlightRect != old.highlightRect || pulseWidth != old.pulseWidth;
}
