import 'package:flutter/material.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

class ParentSettingsScreen extends StatelessWidget {
  const ParentSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Privacy'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
            children: const [
              PortalSettingsContent(portalLabel: 'Parent'),
            ],
          ),
        ),
      ),
    );
  }
}
