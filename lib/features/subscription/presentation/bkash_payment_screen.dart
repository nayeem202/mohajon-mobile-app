import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/mohajon_warm_theme.dart';

/// Outcome of the in-app bKash checkout, surfaced back to the caller so it can
/// run the server-side confirmation (or simply refresh) as needed.
@immutable
class BkashWebResult {
  const BkashWebResult(this.status);

  /// One of `success`, `cancel`, `failure`; null when the user closed the
  /// checkout without bKash reporting a terminal state.
  final String? status;

  bool get succeeded => status == 'success';
}

/// In-app browser that opens the bKash WebCheckout URL returned by the
/// server. When bKash redirects the customer back to the merchant callback
/// URL (success/cancel/failure), this screen detects it and pops itself so
/// the caller can confirm the payment and land back on the subscription page.
class BkashPaymentScreen extends StatefulWidget {
  const BkashPaymentScreen({super.key, required this.bkashUrl});

  final String bkashUrl;

  @override
  State<BkashPaymentScreen> createState() => _BkashPaymentScreenState();
}

class _BkashPaymentScreenState extends State<BkashPaymentScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _loadFailed = false;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _loading = true;
                _loadFailed = false;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (mounted && (error.isForMainFrame ?? true)) {
              setState(() {
                _loading = false;
                _loadFailed = true;
              });
            }
          },
          onNavigationRequest: (request) {
            final url = request.url;
            // bKash redirects here after the customer pays or cancels. The
            // callback host is not intended to be rendered — close the sheet.
            if (url.contains('/api/v1/bkash/callback') ||
                url.contains('status=success') ||
                url.contains('status=cancel') ||
                url.contains('status=failure')) {
              _finish(
                url.contains('status=success')
                    ? 'success'
                    : (url.contains('status=cancel') ? 'cancel' : 'failure'),
              );
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.bkashUrl));
  }

  void _finish(String? status) {
    if (_popped) return;
    _popped = true;
    Navigator.of(context).pop(BkashWebResult(status));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
                  child: Row(
                    children: [
                      _HeaderAction(
                        icon: Icons.close_rounded,
                        tooltip: l10n.t('cancel'),
                        onPressed: () => _finish(null),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.t('bkashPayment'),
                              style: const TextStyle(
                                color: MohajonWarm.ink,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.t('securePaymentCheckout'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: MohajonWarm.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _HeaderAction(
                        icon: Icons.refresh_rounded,
                        tooltip: l10n.t('retry'),
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _loadFailed = false;
                          });
                          _controller.reload();
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    decoration: BoxDecoration(
                      color: MohajonWarm.card,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: MohajonWarm.goldBorder),
                      boxShadow: [
                        BoxShadow(
                          color: MohajonWarm.ink.withValues(alpha: .08),
                          blurRadius: 18,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        if (!_loadFailed)
                          WebViewWidget(controller: _controller),
                        if (_loadFailed)
                          _PaymentLoadError(
                            message: l10n.t('paymentPageLoadFailed'),
                            retryLabel: l10n.t('retry'),
                            onRetry: () {
                              setState(() {
                                _loading = true;
                                _loadFailed = false;
                              });
                              _controller.reload();
                            },
                          ),
                        if (_loading && !_loadFailed)
                          const Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            child: LinearProgressIndicator(minHeight: 3),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: MohajonWarm.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(13),
      side: const BorderSide(color: MohajonWarm.goldBorder),
    ),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: MohajonWarm.ink, size: 20),
      visualDensity: VisualDensity.compact,
    ),
  );
}

class _PaymentLoadError extends StatelessWidget {
  const _PaymentLoadError({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: const BoxDecoration(
              color: MohajonWarm.tintOrange,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: MohajonWarm.orange,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MohajonWarm.ink,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(retryLabel),
          ),
        ],
      ),
    ),
  );
}
