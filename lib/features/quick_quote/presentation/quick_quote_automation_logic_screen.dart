import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/guards/admin_guard.dart';
import '../application/quick_quote_automation_logic_controller.dart';
import '../domain/quick_quote_configuration.dart';

typedef QuickQuoteConfigFilePicker =
    Future<MapEntry<String, List<int>>?> Function();

class QuickQuoteAutomationLogicScreen extends StatefulWidget {
  const QuickQuoteAutomationLogicScreen({
    this.controller,
    this.filePicker,
    super.key,
  });

  final QuickQuoteAutomationLogicController? controller;
  final QuickQuoteConfigFilePicker? filePicker;

  @override
  State<QuickQuoteAutomationLogicScreen> createState() =>
      _QuickQuoteAutomationLogicScreenState();
}

class _QuickQuoteAutomationLogicScreenState
    extends State<QuickQuoteAutomationLogicScreen> {
  late final QuickQuoteAutomationLogicController _controller =
      widget.controller ?? _buildController();
  late final bool _ownsController = widget.controller == null;

  QuickQuoteAutomationLogicController _buildController() {
    final services = ServiceLocator();
    return QuickQuoteAutomationLogicController(
      repository: services.quickQuoteConfigRepository,
      isAdmin: () => services.authController.isAdmin,
      productLoader: () async {
        await services.productMasterController.loadProducts();
        return List.unmodifiable(services.productMasterController.products);
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ServiceLocator().authController.isAdmin) {
        _controller.initialize();
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Quick Quote Automation Logic')),
        body: _controller.status == QuickQuoteAutomationLogicStatus.loading
            ? const Center(child: CircularProgressIndicator())
            : _content(),
      ),
    );
  }

  Widget _content() {
    return RefreshIndicator(
      onRefresh: _controller.initialize,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_controller.errorMessage != null) ...[
            _MessagePanel(
              key: const Key('automation-logic-error'),
              message: _controller.errorMessage!,
              isError: true,
            ),
            const SizedBox(height: 16),
          ],
          _sectionTitle('Active Configuration'),
          const SizedBox(height: 12),
          _activeConfigurationCard(),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                key: const Key('download-current-logic'),
                onPressed:
                    _controller.activeConfiguration == null ||
                        _controller.isBusy
                    ? null
                    : _download,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Download Current Logic'),
              ),
              FilledButton.icon(
                key: const Key('upload-automation-excel'),
                onPressed: _controller.isBusy ? null : _upload,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Upload New Excel'),
              ),
            ],
          ),
          if (_controller.importResult != null) ...[
            const SizedBox(height: 32),
            _sectionTitle('Validation Summary'),
            const SizedBox(height: 12),
            _validationSummary(_controller.importResult!),
            const SizedBox(height: 16),
            _issues(_controller.importResult!),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  key: const Key('preview-automation-changes'),
                  onPressed: _controller.isBusy
                      ? null
                      : _controller.previewChanges,
                  icon: const Icon(Icons.difference_outlined),
                  label: const Text('Preview Changes'),
                ),
                FilledButton.icon(
                  key: const Key('apply-automation-logic'),
                  onPressed: _controller.canApply ? _apply : null,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Apply Automation Logic'),
                ),
              ],
            ),
            if (_controller.showDiff) ...[
              const SizedBox(height: 24),
              _diffPreview(_controller.importResult!),
            ],
          ],
          const SizedBox(height: 32),
          _sectionTitle('Configuration History'),
          const SizedBox(height: 12),
          _history(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _activeConfigurationCard() {
    final configuration = _controller.activeConfiguration;
    final version = configuration?.version;
    if (version == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No active automation configuration.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 32,
          runSpacing: 16,
          children: [
            _detail('Version', 'v${version.versionNumber}'),
            _detail('Source filename', version.sourceFilename),
            _detail(
              'Created',
              DateFormat('dd MMM yyyy, HH:mm').format(version.createdAt),
            ),
            _detail(
              'Activated',
              version.activatedAt == null
                  ? 'Not activated'
                  : DateFormat(
                      'dd MMM yyyy, HH:mm',
                    ).format(version.activatedAt!),
            ),
            _detail('Status', version.isActive ? 'Active' : 'Inactive'),
          ],
        ),
      ),
    );
  }

  Widget _validationSummary(QuickQuoteConfigImportResult result) {
    final summary = result.summary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 28,
          runSpacing: 16,
          children: [
            _metric('${summary.profileCount}', 'Budget Profiles'),
            _metric('${summary.allocationCount}', 'Allocation Rows'),
            _metric(
              '${summary.strengthPriorityCount}',
              'Strength Priority Rows',
            ),
            _metric('${summary.roleMappingCount}', 'Product Role Rows'),
            _metric(
              '${summary.errorCount}',
              'Errors',
              error: summary.errorCount > 0,
            ),
            _metric('${summary.warningCount}', 'Warnings'),
          ],
        ),
      ),
    );
  }

  Widget _issues(QuickQuoteConfigImportResult result) {
    if (result.issues.isEmpty) {
      return const _MessagePanel(
        message: 'No validation errors or warnings.',
        isError: false,
      );
    }
    return Card(
      child: ExpansionTile(
        initiallyExpanded: result.summary.errorCount > 0,
        title: Text(
          '${result.summary.errorCount} error(s), ${result.summary.warningCount} warning(s)',
        ),
        children: result.issues
            .map(
              (issue) => ListTile(
                dense: true,
                leading: Icon(
                  issue.severity == QuickQuoteConfigIssueSeverity.error
                      ? Icons.error_outline
                      : Icons.warning_amber_outlined,
                  color: issue.severity == QuickQuoteConfigIssueSeverity.error
                      ? AppColors.statusRejectedText
                      : AppColors.statusPendingText,
                ),
                title: Text(issue.message),
                subtitle: issue.location.isEmpty ? null : Text(issue.location),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _diffPreview(QuickQuoteConfigImportResult result) {
    final entries = <MapEntry<String, QuickQuoteConfigDiffCount>>[
      MapEntry('Profiles', result.diff.profiles),
      MapEntry('Allocations', result.diff.allocations),
      MapEntry('Strength priorities', result.diff.strengthPriorities),
      MapEntry('Role mappings', result.diff.roleMappings),
    ];
    return Card(
      key: const Key('automation-diff-preview'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Preview Changes',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...entries.map(
              (entry) => ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(entry.key),
                subtitle: Text(
                  'Added: ${entry.value.added}   Changed: ${entry.value.changed}   Removed: ${entry.value.removed}',
                ),
                children: entry.value.details.isEmpty
                    ? const [ListTile(title: Text('No changes.'))]
                    : entry.value.details
                          .map(
                            (detail) =>
                                ListTile(dense: true, title: Text(detail)),
                          )
                          .toList(),
              ),
            ),
            const Divider(),
            Text(
              'Warnings: ${result.summary.warningCount}   Errors: ${result.summary.errorCount}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _history() {
    if (_controller.history.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No configuration versions have been created.'),
        ),
      );
    }
    return Card(
      child: Column(
        children: _controller.history.map((version) {
          return ListTile(
            key: Key('automation-version-${version.id}'),
            leading: CircleAvatar(child: Text('v${version.versionNumber}')),
            title: Text(version.sourceFilename),
            subtitle: Text(
              '${DateFormat('dd MMM yyyy, HH:mm').format(version.createdAt)}'
              '  •  ${version.createdByName ?? version.createdBy}'
              '  •  ${version.validationSummary.errorCount} errors, '
              '${version.validationSummary.warningCount} warnings',
            ),
            trailing: version.isActive
                ? const Chip(label: Text('Active'))
                : OutlinedButton(
                    key: Key('activate-automation-version-${version.id}'),
                    onPressed: _controller.isBusy
                        ? null
                        : () => _activate(version),
                    child: const Text('Activate / Roll Back'),
                  ),
          );
        }).toList(),
      ),
    );
  }

  Widget _sectionTitle(String value) => Text(
    value.toUpperCase(),
    style: Theme.of(context).textTheme.titleSmall?.copyWith(
      color: AppColors.mutedText,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.6,
    ),
  );

  Widget _detail(String label, String value) => SizedBox(
    width: 210,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.mutedText)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );

  Widget _metric(String value, String label, {bool error = false}) => SizedBox(
    width: 150,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: error ? AppColors.statusRejectedText : AppColors.charcoal,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: const TextStyle(color: AppColors.mutedText)),
      ],
    ),
  );

  Future<void> _upload() async {
    final selected = await (widget.filePicker ?? _pickXlsx)();
    if (selected == null) return;
    await _controller.validateWorkbook(
      filename: selected.key,
      bytes: selected.value,
    );
  }

  Future<MapEntry<String, List<int>>?> _pickXlsx() async {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );
    if (result == null) return null;
    final bytes = await result.readAsBytes();
    return MapEntry(result.name, bytes.toList());
  }

  Future<void> _download() async {
    final success = await _controller.downloadCurrentLogic();
    if (!mounted || !success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Current automation logic downloaded.')),
    );
  }

  Future<void> _apply() async {
    final confirmed = await _confirm(
      title: 'Apply Automation Logic?',
      message:
          'This creates and activates a new immutable configuration version.',
    );
    if (!confirmed) return;
    final success = await _controller.apply();
    if (!mounted || !success) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Automation logic applied.')));
  }

  Future<void> _activate(QuickQuoteConfigVersion version) async {
    final confirmed = await _confirm(
      title: 'Activate version ${version.versionNumber}?',
      message:
          'This makes the selected immutable version active. Newer versions will remain in history.',
    );
    if (!confirmed) return;
    final success = await _controller.activateVersion(version.id);
    if (!mounted || !success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Version ${version.versionNumber} activated.')),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.message,
    required this.isError,
    super.key,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isError
            ? AppColors.statusRejectedBg
            : AppColors.statusApprovedBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isError
              ? AppColors.statusRejectedText
              : AppColors.statusApprovedText,
        ),
      ),
    );
  }
}
