import 'package:flutter/material.dart';

import 'loading_overlay.dart';

mixin AsyncActionState<T extends StatefulWidget> on State<T> {
  bool _busy = false;

  bool get isBusy => _busy;

  Future<R?> runBusyAction<R>(Future<R> Function() action) async {
    if (_busy) return null;
    setState(() => _busy = true);
    try {
      return await action();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Widget withLoadingOverlay(Widget child, {String label = 'Please wait...'}) {
    return LoadingOverlay(child: child, loading: _busy, label: label);
  }
}
