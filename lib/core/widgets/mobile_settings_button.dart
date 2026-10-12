import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';

/// An action button that displays a gear icon (Icons.settings_rounded)
/// leading to `/settings` only on compact / mobile screens (width <= 800px).
/// On desktop screens, it renders SizedBox.shrink() so desktop layout remains unchanged.
class MobileSettingsButton extends StatelessWidget {
  const MobileSettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    if (!isMobile) {
      return const SizedBox.shrink();
    }

    final l = AppLocalizations.of(context);
    return IconButton(
      key: const Key('mobile_settings_button'),
      icon: const Icon(Icons.settings_rounded),
      tooltip: l['settings'],
      onPressed: () => context.go('/settings'),
    );
  }
}
