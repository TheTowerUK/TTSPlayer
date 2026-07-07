import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/media_access/media_provider_config_service.dart';
import 'media_provider_settings_screen.dart';

/// Opens the media provider settings screen after loading persisted config.
Future<void> openMediaProviderSettingsScreen(BuildContext context) async {
  await context.read<MediaProviderConfigService>().load();
  if (!context.mounted) return;
  await Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => const MediaProviderSettingsScreen(),
    ),
  );
}
