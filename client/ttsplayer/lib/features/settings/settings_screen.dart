import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../models/application_settings.dart';
import '../../models/playback/playback_rate_presets.dart';
import '../../services/media_access/media_provider_config_service.dart';
import '../../services/settings/settings_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tts_app_bar.dart';
import 'widgets/media_provider_settings_form.dart';
import 'widgets/settings_section.dart';

/// Grouped settings shell (M4 Phase 4.2).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _providerFormKey = GlobalKey<MediaProviderSettingsFormState>();
  final _timeoutController = TextEditingController();

  bool _ready = false;
  bool _savingNetwork = false;
  bool _savingPlayback = false;
  bool _providerDirty = false;
  int _savedTimeoutSeconds = NetworkSettings.defaultCatalogueFetchTimeoutSeconds;
  double _savedPlaybackRate = PlaybackRatePresets.defaultRate;
  double _draftPlaybackRate = PlaybackRatePresets.defaultRate;
  List<String> _networkValidationErrors = [];
  List<String> _playbackValidationErrors = [];
  String? _appVersion;

  bool get _networkDirty =>
      int.tryParse(_timeoutController.text.trim()) != _savedTimeoutSeconds;

  bool get _playbackDirty => _draftPlaybackRate != _savedPlaybackRate;

  bool get _hasUnsavedChanges =>
      _networkDirty || _providerDirty || _playbackDirty;

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
    final providerService = context.read<MediaProviderConfigService>();
    if (!repository.isLoaded) {
      await repository.initialize();
    }
    await providerService.load();
    if (!mounted) return;
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _populateNetworkFromRepository(repository);
      _populatePlaybackFromRepository(repository);
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      _ready = true;
    });
  }

  void _populatePlaybackFromRepository(SettingsRepository repository) {
    _savedPlaybackRate = repository.defaultPlaybackRate;
    _draftPlaybackRate = _savedPlaybackRate;
    _playbackValidationErrors = [];
  }

  void _populateNetworkFromRepository(SettingsRepository repository) {
    _savedTimeoutSeconds = repository.catalogueFetchTimeoutSeconds;
    _timeoutController.text = '$_savedTimeoutSeconds';
    _networkValidationErrors = [];
  }

  NetworkSettings? _draftNetworkSettings() {
    final parsed = int.tryParse(_timeoutController.text.trim());
    if (parsed == null) {
      setState(() {
        _networkValidationErrors = [
          'Catalogue fetch timeout must be a whole number.',
        ];
      });
      return null;
    }
    return NetworkSettings(catalogueFetchTimeoutSeconds: parsed);
  }

  Future<void> _saveNetwork() async {
    final network = _draftNetworkSettings();
    if (network == null) return;

    final errors = network.validate();
    if (errors.isNotEmpty) {
      setState(() => _networkValidationErrors = errors);
      return;
    }

    setState(() {
      _savingNetwork = true;
      _networkValidationErrors = [];
    });

    final repository = context.read<SettingsRepository>();
    final result = await repository.saveNetworkSettings(network);

    if (!mounted) return;
    setState(() => _savingNetwork = false);

    if (!result.success) {
      setState(() => _networkValidationErrors = result.validationErrors);
      return;
    }

    setState(() {
      _savedTimeoutSeconds = network.catalogueFetchTimeoutSeconds;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Network settings saved.')),
    );
  }

  Future<void> _savePlayback() async {
    if (!PlaybackRatePresets.isSupported(_draftPlaybackRate)) {
      setState(() {
        _playbackValidationErrors = ['Select a supported playback speed.'];
      });
      return;
    }

    setState(() {
      _savingPlayback = true;
      _playbackValidationErrors = [];
    });

    final repository = context.read<SettingsRepository>();
    final result = await repository.saveDefaultPlaybackRate(_draftPlaybackRate);

    if (!mounted) return;
    setState(() => _savingPlayback = false);

    if (!result.success) {
      setState(() => _playbackValidationErrors = result.validationErrors);
      return;
    }

    setState(() {
      _savedPlaybackRate = _draftPlaybackRate;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Playback settings saved.')),
    );
  }

  Future<void> _confirmResetPlayback() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset playback settings?'),
        content: const Text(
          'Restore the default playback speed to normal (1×)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm_reset_playback'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repository = context.read<SettingsRepository>();
    await repository.resetPlaybackToDefaults();
    if (!mounted) return;

    setState(() => _populatePlaybackFromRepository(repository));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Playback settings reset to defaults.')),
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
      setState(() => _networkValidationErrors = result.validationErrors);
      return;
    }

    setState(() => _populateNetworkFromRepository(repository));
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
    final providerService = context.read<MediaProviderConfigService>();
    await repository.resetAllToDefaults();
    await providerService.resetToDefaults();
    if (!mounted) return;

    setState(() => _populateNetworkFromRepository(repository));
    setState(() => _populatePlaybackFromRepository(repository));
    _providerFormKey.currentState?.reloadFromService();
    setState(() => _providerDirty = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All settings reset to defaults.')),
    );
  }

  Future<void> _handlePop() async {
    if (!_hasUnsavedChanges) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final action = await showDialog<_UnsavedAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('Save your changes before leaving?'),
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
      if (_networkDirty) await _saveNetwork();
      if (!mounted || _networkValidationErrors.isNotEmpty) return;
      if (_playbackDirty) await _savePlayback();
      if (!mounted || _playbackValidationErrors.isNotEmpty) return;
      if (_providerDirty) {
        await _providerFormKey.currentState?.save();
      }
      if (!mounted || _hasUnsavedChanges) return;
    } else {
      setState(() {
        _populateNetworkFromRepository(context.read<SettingsRepository>());
        _populatePlaybackFromRepository(context.read<SettingsRepository>());
      });
      _providerFormKey.currentState?.reloadFromService();
      setState(() => _providerDirty = false);
    }

    if (mounted) Navigator.of(context).pop();
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
                          if (_networkValidationErrors.isNotEmpty) ...[
                            _NetworkValidationErrorsBanner(
                              errors: _networkValidationErrors,
                            ),
                            const SizedBox(height: AppSpacing.base),
                          ],
                          if (_playbackValidationErrors.isNotEmpty) ...[
                            _PlaybackValidationErrorsBanner(
                              errors: _playbackValidationErrors,
                            ),
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
                            child: MediaProviderSettingsForm(
                              key: _providerFormKey,
                              onDirtyChanged: (dirty) {
                                if (_providerDirty != dirty) {
                                  setState(() => _providerDirty = dirty);
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.section),
                          SettingsSection(
                            title: 'Playback',
                            description:
                                'Default speed applied when newly opened media starts '
                                'playing. Does not change speed for media already playing.',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!kIsWeb && !Platform.isWindows)
                                  const Padding(
                                    padding: EdgeInsets.only(
                                      bottom: AppSpacing.sm,
                                    ),
                                    child: Text(
                                      'Playback speed control is available on Windows only. '
                                      'Other platforms always play at normal speed.',
                                      style: AppTypography.bodyMuted,
                                    ),
                                  ),
                                DropdownButtonFormField<double>(
                                  key: const Key('default_playback_speed'),
                                  value: _draftPlaybackRate,
                                  decoration: InputDecoration(
                                    labelText: 'Default playback speed',
                                    helperText:
                                        'Saved: ${PlaybackRatePresets.displayLabel(_savedPlaybackRate)}',
                                    border: const OutlineInputBorder(),
                                  ),
                                  items: [
                                    for (final rate in PlaybackRatePresets.supported)
                                      DropdownMenuItem<double>(
                                        value: rate,
                                        child: Text(
                                          PlaybackRatePresets.displayLabel(rate),
                                        ),
                                      ),
                                  ],
                                  onChanged: (_savingNetwork || _savingPlayback)
                                      ? null
                                      : (value) {
                                          if (value == null) return;
                                          setState(() {
                                            _draftPlaybackRate = value;
                                            _playbackValidationErrors = [];
                                          });
                                        },
                                ),
                              ],
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
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: 'Catalogue fetch timeout (seconds)',
                                helperText:
                                    'Between ${NetworkSettings.minCatalogueFetchTimeoutSeconds} '
                                    'and ${NetworkSettings.maxCatalogueFetchTimeoutSeconds} seconds.',
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                if (_networkValidationErrors.isNotEmpty) {
                                  setState(() => _networkValidationErrors = []);
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
                                  onPressed:
                                      _savingNetwork ? null : _confirmResetAll,
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
                                key: const Key('save_playback_settings'),
                                onPressed: _savingPlayback || !_playbackDirty
                                    ? null
                                    : _savePlayback,
                                icon: _savingPlayback
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: const Text('Save playback settings'),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              OutlinedButton.icon(
                                key: const Key('reset_playback_settings'),
                                onPressed: _savingPlayback
                                    ? null
                                    : _confirmResetPlayback,
                                icon: const Icon(Icons.restore_outlined),
                                label: const Text('Reset playback defaults'),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.section),
                          Row(
                            children: [
                              FilledButton.icon(
                                key: const Key('save_network_settings'),
                                onPressed: _savingNetwork || !_networkDirty
                                    ? null
                                    : _saveNetwork,
                                icon: _savingNetwork
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: const Text('Save network settings'),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              OutlinedButton.icon(
                                key: const Key('reset_network_settings'),
                                onPressed:
                                    _savingNetwork ? null : _confirmResetNetwork,
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

class _PlaybackValidationErrorsBanner extends StatelessWidget {
  const _PlaybackValidationErrorsBanner({required this.errors});

  final List<String> errors;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('playback_validation_errors'),
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: Padding(
        padding: AppSpacing.cardPremium,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fix the following before saving playback settings:',
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

class _NetworkValidationErrorsBanner extends StatelessWidget {
  const _NetworkValidationErrorsBanner({required this.errors});

  final List<String> errors;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('network_validation_errors'),
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: Padding(
        padding: AppSpacing.cardPremium,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fix the following before saving network settings:',
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
