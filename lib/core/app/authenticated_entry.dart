import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/shop_setup_screen.dart';
import 'app_providers.dart';
import 'app_shell.dart';

/// Routes authenticated users through the one-time shop setup flow.
class AuthenticatedEntry extends ConsumerStatefulWidget {
  const AuthenticatedEntry({super.key});

  @override
  ConsumerState<AuthenticatedEntry> createState() => _AuthenticatedEntryState();
}

class _AuthenticatedEntryState extends ConsumerState<AuthenticatedEntry> {
  bool _complete() => ref.read(localDatabaseProvider).settings.get(
        'profile_setupComplete',
        defaultValue: false,
      ) as bool;

  @override
  Widget build(BuildContext context) {
    if (!_complete()) {
      return ShopSetupScreen(onCompleted: () => setState(() {}));
    }
    return AppShell(key: ValueKey(ref.watch(shopIdProvider)));
  }
}
