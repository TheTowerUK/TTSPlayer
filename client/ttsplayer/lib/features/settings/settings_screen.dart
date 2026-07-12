import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../models/application_settings.dart';
import '../../services/media_access/media_provider_config_service.dart';
import '../../services/settings/settings_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tts_app_bar.dart';
import 'media_provider_settings_screen.dart';
import 'widgets/settings_section.dart';

/// Grouped settings shell (M4 Phase 4.2).
///
/// Provider editor integration is a follow-on step; Library & Providers remains
/// a placeholder with interim navigation to [MediaProviderSettingsScreen].
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _timeoutController = TextEditingController();

  bool _ready = false;
  bool _saving = false;
  int _savedTimeoutSeconds = NetworkSettings.defaultCatalogueFetchTimeoutSeconds;
  List<String> _validationErrors = [];
  String? _appVersion;

  bool get _isDirty =>
      int.tryParse(_timeoutController.text.trim()) != _savedTimeoutSeconds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _timeoutController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final repository = context.read<SettingsRepository>();
    if (!repository.isLoaded) {
      await repository.initialize();
    }
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _populateFromRepository(repository);
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      _ready = true;
    });
  }

  void _populateFromRepository(SettingsRepository repository) {
    _savedTimeoutSeconds = repository.catalogueFetchTimeoutSeconds;
    _timeoutController.text = '$_savedTimeoutSeconds';
    _validationErrors = [];
  }

  NetworkSettings? _draftNetworkSettings() {
    final parsed = int.tryParse(_timeoutController.text.trim());
    if (parsed == null) {
      setState(() {
        _validationErrors = ['Catalogue fetch timeout must be a whole number.'];
      });
      return null;
    }
    return NetworkSettings(catalogueFetchTimeoutSeconds: parsed);
  }

  Future<void> _save() async {
    final network = _draftNetworkSettings();
    if (network == null) return;

    final errors = network.validate();
    if (errors.isNotEmpty) {
      setState(() => _validationErrors = errors);
      return;
    }

    setState(() {
      _saving = true;
      _validationErrors = [];
    });

    final repository = context.read<SettingsRepository>();
    final result = await repository.saveNetworkSettings(network);

    if (!mounted) return;
    setState(() => _saving = false);

    if (!result.success) {
      setState(() => _validationErrors = result.validationErrors);
      return;
    }

    setState(() {
      _savedTimeoutSeconds = network.catalogueFetchTimeoutSeconds;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved.')),
    );
  }

  Future<void> _confirmResetNetwork() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset network settings?'),
        content: const Text(
          'Restore the catalogue fetch timeout to its default value?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm_reset_network'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repository = context.read<SettingsRepository>();
    final result = await repository.saveNetworkSettings(NetworkSettings.defaults());
    if (!mounted) return;

    if (!result.success) {
      setState(() => _validationErrors = result.validationErrors);
      return;
    }

    setState(() => _populateFromRepository(repository));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Network settings reset to defaults.')),
    );
  }

  Future<void> _confirmResetAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset all settings?'),
        content: const Text(
          'Restore all configurable settings to their defaults. '
          'Playback progress and resume positions are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm_reset_all_settings'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repository = context.read<SettingsRepository>();
    await repository.resetAllToDefaults();
    if (!mounted) return;

    setState(() => _populateFromRepository(repository));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All settings reset to defaults.')),
    );
  }

  Future<void> _handlePop() async {
    if (!_isDirty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final action = await showDialog<_UnsavedAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('Save your network settings before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _UnsavedAction.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _UnsavedAction.discard),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _UnsavedAction.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (!mounted || action == null || action == _UnsavedAction.cancel) return;

    if (action == _UnsavedAction.save) {
      await _save();
      if (!mounted || _validationErrors.isNotEmpty || _isDirty) return;
    } else {
      setState(() => _populateFromRepository(context.read<SettingsRepository>()));
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _openProviderSettings() async {
    await context.read<MediaProviderConfigService>().load();
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const MediaProviderSettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handlePop();
      },
      child: Scaffold(
        appBar: TtsAppBar(
          title: 'Settings',
          showHome: true,
          extraActions: [
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close',
              onPressed: _handlePop,
            ),
          ],
        ),
        body: !_ready
            ? const Center(child: CircularProgressIndicator())
            : Scrollbar(
                child: SingleChildScrollView(
                  padding: AppSpacing.insetPage,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_validationErrors.isNotEmpty) ...[
                            _ValidationErrorsBanner(errors: _validationErrors),
                            const SizedBox(height: AppSpacing.base),
                          ],
                          const SettingsSection(
                            title: 'General',
                            description:
                                'App-wide preferences will appear here in a future update.',
                            child: Text(
                              'No configurable options yet.',
                              style: AppTypography.bodyMuted,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.section),
                          SettingsSection(
                            title: 'Library & Providers',
                            description:
                                'Catalogue providers and media access configuration. '
                                'See the dashboard for active provider status and refresh.',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Provider settings will move here in the next step. '
                                  'Use the interim screen to configure catalogue paths, '
                                  'media roots, and access mode.',
                                  style: AppTypography.bodyMuted,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                OutlinedButton.icon(
                                  key: const Key('open_provider_settings'),
                                  onPressed: _openProviderSettings,
                                  icon: const Icon(Icons.storage_outlined),
                                  label: const Text('Open provider settings'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.section),
                          const SettingsSection(
                            title: 'Playback',
                            description:
                                'Playback preferences will be added in Phase 4.4.',
                            child: Text(
                              'No configurable options yet.',
                              style: AppTypography.bodyMuted,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.section),
                          SettingsSection(
                            title: 'Network',
                            description:
                                'HTTP catalogue fetch behaviour. Secure transport rules '
                                'are controlled by provider access mode.',
                            child: TextField(
                              key: const Key('catalogue_fetch_timeout'),
                              controller: _timeoutController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: InputDecoration(
                                labelText: 'Catalogue fetch timeout (seconds)',
                                helperText:
                                    'Between ${NetworkSettings.minCatalogueFetchTimeoutSeconds} '
                                    'and ${NetworkSettings.maxCatalogueFetchTimeoutSeconds} seconds.',
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                if (_validationErrors.isNotEmpty) {
                                  setState(() => _validationErrors = []);
                                }
                                setState(() {});
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.section),
                          SettingsSection(
                            title: 'Diagnostics & Advanced',
                            description:
                                'Application information and recovery actions.',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Version',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  _appVersion ?? 'Unknown',
                                  key: const Key('app_version'),
                                ),
                                const SizedBox(height: AppSpacing.base),
                                OutlinedButton.icon(
                                  key: const Key('reset_all_settings'),
                                  onPressed: _saving ? null : _confirmResetAll,
                                  icon: const Icon(Icons.restart_alt_outlined),
                                  label: const Text('Reset all settings'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.section),
                          Row(
                            children: [
                              FilledButton.icon(
                                key: const Key('save_settings'),
                                onPressed: _saving || !_isDirty ? null : _save,
                                icon: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: const Text('Save'),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              OutlinedButton.icon(
                                key: const Key('reset_network_settings'),
                                onPressed: _saving ? null : _confirmResetNetwork,
                                icon: const Icon(Icons.restore_outlined),
                                label: const Text('Reset network defaults'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

enum _UnsavedAction { save, discard, cancel }

class _ValidationErrorsBanner extends StatelessWidget {
  const _ValidationErrorsBanner({required this.errors});

  final List<String> errors;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('validation_errors'),
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: Padding(
        padding: AppSpacing.cardPremium,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fix the following before saving:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final error in errors)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text('• $error'),
              ),
          ],
        ),
      ),
    );
  }
}
