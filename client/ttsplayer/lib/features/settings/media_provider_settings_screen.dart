import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/media_access/media_access_config.dart';
import '../../services/media_access/media_provider_config.dart';
import '../../services/media_access/media_provider_config_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tts_app_bar.dart';

/// Settings screen for catalogue providers and media access configuration.
///
/// Phase 4.3 — view, edit, and persist [MediaProviderConfig] only. Startup
/// catalogue selection and resolver refresh are wired in later sub-phases.
class MediaProviderSettingsScreen extends StatefulWidget {
  const MediaProviderSettingsScreen({super.key});

  @override
  State<MediaProviderSettingsScreen> createState() =>
      _MediaProviderSettingsScreenState();
}

class _MediaProviderSettingsScreenState
    extends State<MediaProviderSettingsScreen> {
  final _httpCatalogueController = TextEditingController();
  final _httpMediaBaseController = TextEditingController();

  List<TextEditingController> _localCatalogueControllers = [];
  List<TextEditingController> _mediaRootControllers = [];

  MediaAccessMode _mode = MediaAccessMode.localPreferred;
  List<String> _validationErrors = [];
  List<String> _validationWarnings = [];
  bool _saving = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeFields());
  }

  Future<void> _initializeFields() async {
    final config = context.read<MediaProviderConfigService>().config;
    if (!mounted) return;
    setState(() {
      _populateFromConfig(config);
      _ready = true;
    });
  }

  @override
  void dispose() {
    _httpCatalogueController.dispose();
    _httpMediaBaseController.dispose();
    _disposePathControllers(_localCatalogueControllers);
    _disposePathControllers(_mediaRootControllers);
    super.dispose();
  }

  void _populateFromConfig(MediaProviderConfig config) {
    _disposePathControllers(_localCatalogueControllers);
    _disposePathControllers(_mediaRootControllers);

    final localPaths = config.localCataloguePaths;
    _localCatalogueControllers = [
      for (final path in localPaths) TextEditingController(text: path),
      if (localPaths.isEmpty) TextEditingController(),
    ];

    final roots = config.mediaAccess.mediaRoots;
    _mediaRootControllers = [
      for (final root in roots) TextEditingController(text: root),
      if (roots.isEmpty) TextEditingController(),
    ];

    _httpCatalogueController.text = config.httpCatalogueUrl ?? '';
    _httpMediaBaseController.text = config.mediaAccess.httpMediaBaseUrl ?? '';
    _mode = config.mediaAccess.mode;
    _validationErrors = [];
    _validationWarnings = [];
  }

  void _disposePathControllers(List<TextEditingController> controllers) {
    for (final controller in controllers) {
      controller.dispose();
    }
  }

  MediaProviderConfig _buildDraftConfig() {
    return MediaProviderConfig.fromDraft(
      localCataloguePaths:
          _localCatalogueControllers.map((c) => c.text).toList(),
      httpCatalogueUrl: _httpCatalogueController.text,
      mediaRoots: _mediaRootControllers.map((c) => c.text).toList(),
      httpMediaBaseUrl: _httpMediaBaseController.text,
      mode: _mode,
    );
  }

  Future<void> _save() async {
    final config = _buildDraftConfig();
    final errors = config.validate();
    if (errors.isNotEmpty) {
      setState(() => _validationErrors = errors);
      return;
    }

    setState(() {
      _saving = true;
      _validationErrors = [];
      _validationWarnings = config.securityWarnings();
    });

    final service = context.read<MediaProviderConfigService>();
    final saved = await service.save(config);

    if (!mounted) return;
    setState(() => _saving = false);

    if (saved) {
      final warnings = config.securityWarnings();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            warnings.isEmpty
                ? 'Settings saved.'
                : 'Settings saved. ${warnings.length} security warning(s) — see banner.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _populateFromConfig(service.config);
      if (warnings.isNotEmpty) {
        setState(() => _validationWarnings = warnings);
      }
    } else {
      setState(() => _validationErrors = config.validate());
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to defaults?'),
        content: const Text(
          'This removes saved provider settings and restores the built-in '
          'defaults. Catalogue loading at startup is unchanged until a '
          'later update applies saved settings automatically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm_reset_settings'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final service = context.read<MediaProviderConfigService>();
    await service.resetToDefaults();
    if (!mounted) return;

    setState(() {
      _populateFromConfig(service.config);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings reset to defaults.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _addLocalCataloguePath() {
    setState(() {
      _localCatalogueControllers.add(TextEditingController());
    });
  }

  void _removeLocalCataloguePath(int index) {
    if (_localCatalogueControllers.length <= 1) {
      _localCatalogueControllers.first.clear();
      return;
    }
    setState(() {
      _localCatalogueControllers.removeAt(index).dispose();
    });
  }

  void _addMediaRoot() {
    setState(() {
      _mediaRootControllers.add(TextEditingController());
    });
  }

  void _removeMediaRoot(int index) {
    if (_mediaRootControllers.length <= 1) {
      _mediaRootControllers.first.clear();
      return;
    }
    setState(() {
      _mediaRootControllers.removeAt(index).dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TtsAppBar(title: 'Settings', showHome: true),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: AppSpacing.insetPage,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                if (_validationErrors.isNotEmpty) ...[
                  _ValidationErrorsBanner(errors: _validationErrors),
                  const SizedBox(height: AppSpacing.base),
                ],
                if (_validationWarnings.isNotEmpty) ...[
                  _ValidationWarningsBanner(warnings: _validationWarnings),
                  const SizedBox(height: AppSpacing.base),
                ],
                const _SectionHeader(
                  title: 'Catalogue providers',
                  subtitle:
                      'Local catalogue files are tried in order. An optional '
                      'HTTP catalogue URL can be added for remote libraries.',
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Local catalogue paths',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (var i = 0; i < _localCatalogueControllers.length; i++)
                  _PathFieldRow(
                    key: Key('local_catalogue_$i'),
                    controller: _localCatalogueControllers[i],
                    hint: r'Y:\Media\catalog.json',
                    onRemove: () => _removeLocalCataloguePath(i),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('add_local_catalogue'),
                    onPressed: _addLocalCataloguePath,
                    icon: const Icon(Icons.add),
                    label: const Text('Add local catalogue path'),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
                TextField(
                  key: const Key('http_catalogue_url'),
                  controller: _httpCatalogueController,
                  decoration: const InputDecoration(
                    labelText: 'Remote catalogue URL (optional)',
                    hintText: 'https://nas.example:8443/catalog.json',
                    helperText: 'Prefer https:// for production. Plain http:// is allowed in local preferred mode only.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                const _SectionHeader(
                  title: 'Media access',
                  subtitle:
                      'Media roots map catalogue file paths to local or HTTP '
                      'playback. Mode controls resolver preference.',
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Media roots',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (var i = 0; i < _mediaRootControllers.length; i++)
                  _PathFieldRow(
                    key: Key('media_root_$i'),
                    controller: _mediaRootControllers[i],
                    hint: r'Y:\Media',
                    onRemove: () => _removeMediaRoot(i),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('add_media_root'),
                    onPressed: _addMediaRoot,
                    icon: const Icon(Icons.add),
                    label: const Text('Add media root'),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
                TextField(
                  key: const Key('http_media_base_url'),
                  controller: _httpMediaBaseController,
                  decoration: const InputDecoration(
                    labelText: 'Remote media base URL (optional)',
                    hintText: 'https://nas.example:8443/media/',
                    helperText: 'Must match the Caddy /media/ prefix. Prefer https:// for production.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
                Text(
                  'Media access mode',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                RadioListTile<MediaAccessMode>(
                  key: const Key('media_access_mode_local'),
                  title: const Text('Local preferred'),
                  value: MediaAccessMode.localPreferred,
                  groupValue: _mode,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _mode = value);
                  },
                ),
                RadioListTile<MediaAccessMode>(
                  key: const Key('media_access_mode_http'),
                  title: const Text('HTTP required'),
                  value: MediaAccessMode.httpRequired,
                  groupValue: _mode,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _mode = value);
                  },
                ),
                const SizedBox(height: AppSpacing.section),
                Row(
                  children: [
                    FilledButton.icon(
                      key: const Key('save_settings'),
                      onPressed: _saving ? null : _save,
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
                      key: const Key('reset_settings'),
                      onPressed: _saving ? null : _confirmReset,
                      icon: const Icon(Icons.restore_outlined),
                      label: const Text('Reset to defaults'),
                    ),
                  ],
                ),
                ],
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(subtitle, style: AppTypography.bodyMuted),
      ],
    );
  }
}

class _ValidationErrorsBanner extends StatelessWidget {
  final List<String> errors;

  const _ValidationErrorsBanner({required this.errors});

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
              'Fix these issues before saving:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final error in errors)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  '• $error',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ValidationWarningsBanner extends StatelessWidget {
  final List<String> warnings;

  const _ValidationWarningsBanner({required this.warnings});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const Key('validation_warnings'),
      color: scheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: Padding(
        padding: AppSpacing.cardPremium,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Security notes (save allowed):',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: scheme.onTertiaryContainer,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final warning in warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  '• $warning',
                  style: TextStyle(color: scheme.onTertiaryContainer),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PathFieldRow extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onRemove;

  const _PathFieldRow({
    super.key,
    required this.controller,
    required this.hint,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: onRemove,
            icon: const Icon(Icons.remove_circle_outline),
          ),
        ],
      ),
    );
  }
}
