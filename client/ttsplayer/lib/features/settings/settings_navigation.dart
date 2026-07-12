import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/media_access/media_provider_config_service.dart';
import '../../services/settings/settings_repository.dart';
import 'settings_screen.dart';

/// Opens the grouped settings shell after ensuring persisted settings are loaded.
Future<void> openSettingsScreen(BuildContext context) async {
  final repository = context.read<SettingsRepository>();
  final providerService = context.read<MediaProviderConfigService>();
  if (!repository.isLoaded) {
    await repository.initialize();
  }
  await providerService.load();
  if (!context.mounted) return;
  await Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => const SettingsScreen(),
    ),
  );
}
