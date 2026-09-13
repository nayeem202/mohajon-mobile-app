import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/localization/app_localizations.dart';

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
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (request) {
            final url = request.url;
            // bKash redirects here after the customer pays or cancels. The
            // callback host is not intended to be rendered — close the sheet.
            if (url.contains('/api/v1/bkash/callback') ||
                url.contains('status=success') ||
                url.contains('status=cancel') ||
                url.contains('status=failure')) {
              _finish(url.contains('status=success')
                  ? 'success'
                  : (url.contains('status=cancel') ? 'cancel' : 'failure'));
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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('bkashPayment')),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => _finish(null),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            Positioned.fill(
              child: ColoredBox(
                color: scheme.surface,
                child: Center(
                  child: CircularProgressIndicator(color: scheme.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}