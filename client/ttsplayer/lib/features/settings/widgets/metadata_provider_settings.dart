import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../metadata_enrichment/services/metadata_provider_lifecycle.dart';
import '../../../models/application_settings.dart';
import '../../../services/settings/settings_repository.dart';
import '../../../theme/app_theme.dart';

class MetadataProviderSettings extends StatefulWidget {
  const MetadataProviderSettings({super.key});

  @override
  State<MetadataProviderSettings> createState() =>
      _MetadataProviderSettingsState();
}

class _MetadataProviderSettingsState extends State<MetadataProviderSettings> {
  bool _saving = false;

  Future<void> _setMasterEnabled(bool enabled) async {
    if (_saving) return;
    if (enabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const Key('metadata_privacy_disclosure'),
          title: const Text('Enable external metadata?'),
          content: const Text(
            'When you explicitly search for or refresh book metadata, '
            'TTSPlayer may send a normalized ISBN, normalized title, author, '
            'and optional year to Open Library.\n\n'
            'TTSPlayer does not send full paths, directory names, filenames, '
            'basenames, file stems, or catalogue tree structure. Enabling '
            'external metadata does not start automatic or background work.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('confirm_enable_external_metadata'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enable'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    await _save(
      context.read<SettingsRepository>().metadataProviders.copyWith(
            externalMetadataEnabled: enabled,
          ),
    );
  }

  Future<void> _setOpenLibraryEnabled(bool enabled) async {
    if (_saving) return;
    final current = context.read<SettingsRepository>().metadataProviders;
    final ids = current.enabledProviderIds.toSet();
    if (enabled) {
      ids.add(MetadataProviderLifecycle.openLibraryProviderId);
    } else {
      ids.remove(MetadataProviderLifecycle.openLibraryProviderId);
    }
    await _save(current.copyWith(enabledProviderIds: ids));
  }

  Future<void> _save(MetadataProvidersSettings settings) async {
    setState(() => _saving = true);
    final result = await context
        .read<SettingsRepository>()
        .saveMetadataProviders(settings);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('External metadata settings could not be saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsRepository>().metadataProviders;
    final masterEnabled = settings.externalMetadataEnabled;
    final openLibraryEnabled = settings.enabledProviderIds
        .contains(MetadataProviderLifecycle.openLibraryProviderId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: const Key('external_metadata_enabled'),
          contentPadding: EdgeInsets.zero,
          title: const Text('External metadata'),
          subtitle: const Text(
            'Off by default. Provider access occurs only after an explicit action.',
          ),
          value: masterEnabled,
          onChanged: _saving ? null : _setMasterEnabled,
        ),
        CheckboxListTile(
          key: const Key('open_library_enabled'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Open Library'),
          subtitle: const Text(
            'Book metadata provider. No account or credential is required.',
          ),
          value: openLibraryEnabled,
          onChanged: !masterEnabled || _saving
              ? null
              : (value) => _setOpenLibraryEnabled(value ?? false),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Disabling external metadata retains downloaded metadata and provider '
          'artwork. Retained data remains available offline. Nothing is deleted '
          'unless you use a separate confirmed delete action.',
          key: Key('metadata_retention_disclosure'),
          style: AppTypography.bodyMuted,
        ),
      ],
    );
  }
}
