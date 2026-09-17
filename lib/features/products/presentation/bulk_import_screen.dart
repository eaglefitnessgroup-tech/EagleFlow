import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'folder_picker/folder_picker.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/utils/file_download_util.dart';
import '../application/bulk_import_service.dart';
import '../domain/bulk_import_models.dart';
import 'widgets/import_preview_table.dart';

/// Signature for the file-save function used by [BulkImportScreen].
/// Defaults to [FileDownloadUtil.save]; can be replaced in tests.
typedef FileSaver =
    Future<void> Function({required List<int> bytes, required String filename});

typedef BulkImportCommitter =
    Future<BulkImportResult> Function(
      BulkImportPreview preview, {
      BulkImportProgressCallback? onProgress,
    });

class BulkImportScreen extends StatefulWidget {
  const BulkImportScreen({
    super.key,
    this.fileSaver,
    this.commitImport,
    this.isOnlineOverride,
  });

  /// Override to inject a mock file-saver in tests.
  final FileSaver? fileSaver;
  final BulkImportCommitter? commitImport;
  final bool? isOnlineOverride;

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

enum _ImportPhase {
  idle,
  parsing,
  readyValid,
  readyInvalid,
  importing,
  success,
  failure,
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  BulkImportPreview? _preview;
  _ImportPhase _phase = _ImportPhase.idle;
  // ── separate inputs ──────────────────────────────────────────────────────
  List<int>? _excelBytes;             // bytes from the chosen Excel/CSV file
  String _excelFileName = '';         // display name shown under the button
  Map<String, List<int>>? _folderFiles; // images from the chosen folder
  String _pickedFileName = '';        // display name shown under folder button
  // ─────────────────────────────────────────────────────────────────────────
  String _userMessage = '';
  bool _submitting = false; // double-submit guard
  int _processedRows = 0;
  int _progressTotalRows = 0;

  /// Resolved file-saver: widget override (tests) or real implementation.
  late final FileSaver _fileSaver = widget.fileSaver ?? FileDownloadUtil.save;

  // ── helpers ────────────────────────────────────────────────────────────────

  bool get _isOnline =>
      widget.isOnlineOverride ?? ServiceLocator().supabaseService.isConnected;

  bool get _canImport =>
      _phase == _ImportPhase.readyValid && !_submitting && _isOnline;

  String get _phaseMessage {
    switch (_phase) {
      case _ImportPhase.idle:
        if (_excelBytes == null && _folderFiles == null) {
          return 'Select an Excel file and an image folder to begin.';
        }
        if (_excelBytes == null) { return 'Now select the Excel file to continue.'; }
        if (_folderFiles == null) { return 'Now select the image folder to continue.'; }
        return 'Ready to parse.';
      case _ImportPhase.parsing:
        return 'Parsing file…';
      case _ImportPhase.readyValid:
        final p = _preview!;
        final img = p.rows
            .where((r) => r.isValid && r.imageStatus != null)
            .length;
        return '${p.validCount} valid row${p.validCount == 1 ? '' : 's'}'
            '${img > 0 ? ', $img with images' : ''} — ready to import.';
      case _ImportPhase.readyInvalid:
        final p = _preview!;
        return '${p.validCount} valid, ${p.errorCount} invalid. Fix errors before importing.';
      case _ImportPhase.importing:
        return 'Importing… please wait.';
      case _ImportPhase.success:
        return _userMessage;
      case _ImportPhase.failure:
        return _userMessage;
    }
  }

  Color get _messageColor {
    switch (_phase) {
      case _ImportPhase.readyInvalid:
      case _ImportPhase.failure:
        return AppColors.statusRejectedText;
      case _ImportPhase.success:
        return AppColors.statusApprovedText;
      default:
        return AppColors.mutedText;
    }
  }

  // ── actions ────────────────────────────────────────────────────────────────

  Future<void> _pickExcelFile() async {
    if (_submitting) return;
    try {
      final picked = await pickExcelFile();
      if (picked == null || picked.isEmpty) return;
      final filename = picked.keys.first;
      final bytes = picked.values.first;
      setState(() {
        _excelBytes = bytes;
        _excelFileName = filename;
        _preview = null;
        _phase = _ImportPhase.idle;
        _userMessage = '';
      });
      await _maybeRunPreview();
    } catch (_) {
      _showError('Could not read the Excel file. Please try again.');
    }
  }

  Future<void> _pickFolder() async {
    if (_submitting) return;
    try {
      final folderFiles = await pickFolderFiles();
      if (folderFiles == null || folderFiles.isEmpty) return;
      setState(() {
        _folderFiles = folderFiles;
        _pickedFileName = 'Image Folder';
        _preview = null;
        _phase = _ImportPhase.idle;
        _userMessage = '';
      });
      await _maybeRunPreview();
    } catch (_) {
      _showError('Could not read the folder. Please try again.');
    }
  }

  /// Runs previewImport only when BOTH Excel and image folder have been selected.
  Future<void> _maybeRunPreview() async {
    if (_excelBytes == null || _folderFiles == null) return;
    if (!mounted) return;
    setState(() {
      _phase = _ImportPhase.parsing;
    });
    try {
      final service = ServiceLocator().bulkImportService;
      // Distinguish CSV from Excel by filename extension.
      String csvData = '';
      List<int>? excelBytes;
      if (_excelFileName.toLowerCase().endsWith('.csv')) {
        csvData = String.fromCharCodes(_excelBytes!);
      } else {
        excelBytes = _excelBytes;
      }
      final preview = await service.previewImport(
        csvData,
        excelBytes: excelBytes,
        folderFiles: _folderFiles,
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        if (preview.globalError != null) {
          _phase = _ImportPhase.readyInvalid;
          _userMessage = preview.globalError!;
        } else if (preview.canImport) {
          _phase = _ImportPhase.readyValid;
        } else {
          _phase = _ImportPhase.readyInvalid;
        }
      });
    } catch (_) {
      _showError('Could not parse the import files. Please try again.');
    }
  }

  Future<void> _downloadTemplate() async {
    if (_submitting) return;
    try {
      final bytes = ServiceLocator().bulkImportService.generateTemplate();
      await _fileSaver(bytes: bytes, filename: 'products_import_template.xlsx');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template downloaded: products_import_template.xlsx'),
        ),
      );
    } catch (_) {
      _showError('Could not download template. Please try again.');
    }
  }

  Future<void> _downloadSampleFolder() async {
    if (_submitting) return;
    try {
      final bytes = ServiceLocator().bulkImportService.generateSampleZip();
      await _fileSaver(bytes: bytes, filename: 'products_sample_import.zip');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sample downloaded: products_sample_import.zip'),
        ),
      );
    } catch (_) {
      _showError('Could not download sample. Please try again.');
    }
  }

  Future<void> _confirmImport() async {
    if (!_canImport || _submitting) return;
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bulk import requires an internet connection.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _submitting = true;
      _phase = _ImportPhase.importing;
      _processedRows = 0;
      _progressTotalRows = _preview!.validCount;
    });

    try {
      final service = ServiceLocator().bulkImportService;
      final commitImport = widget.commitImport ?? service.commitImport;
      final result = await commitImport(
        _preview!,
        onProgress: _updateImportProgress,
      );

      if (!mounted) return;
      if (result.success) {
        setState(() {
          _phase = _ImportPhase.success;
          _userMessage = result.message;
          _submitting = false;
          _processedRows = _progressTotalRows;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppColors.statusApprovedText,
          ),
        );
        ServiceLocator().productMasterController.loadProducts();
      } else {
        setState(() {
          _phase = _ImportPhase.failure;
          _userMessage = result.message;
          _submitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppColors.statusRejectedText,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _ImportPhase.failure;
        _userMessage = 'Import failed. No products were added.';
        _submitting = false;
      });
    }
  }

  void _updateImportProgress(int processedRows, int totalRows) {
    if (!mounted) return;
    setState(() {
      _progressTotalRows = totalRows;
      _processedRows = processedRows.clamp(0, totalRows);
    });
  }

  void _copyErrors() {
    if (_preview == null) return;
    final service = ServiceLocator().bulkImportService;
    final report = service.generateErrorReport(_preview!);
    Clipboard.setData(ClipboardData(text: report));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Error report copied to clipboard')),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() {
      _phase = _ImportPhase.failure;
      _userMessage = msg;
    });
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bulk Import Products'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.charcoal,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── offline notice ─────────────────────────────────────────────
              if (!_isOnline)
                Container(
                  key: const Key('offline_banner'),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.statusRejectedBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.wifi_off,
                        color: AppColors.statusRejectedText,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You are offline. Import requires an internet connection.',
                          style: TextStyle(
                            color: AppColors.statusRejectedText,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── action card ────────────────────────────────────────────────
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Excel file picker ─────────────────────────────────
                      ElevatedButton.icon(
                        key: const Key('pick_excel_btn'),
                        onPressed:
                            (_phase == _ImportPhase.parsing || _submitting)
                            ? null
                            : _pickExcelFile,
                        icon: const Icon(Icons.table_chart_outlined),
                        label: Text(
                          _excelFileName.isEmpty
                              ? 'Select Excel File'
                              : 'Replace Excel File',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),

                      if (_excelFileName.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.attach_file,
                              size: 14,
                              color: AppColors.mutedText,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _excelFileName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mutedText,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 12),

                      // ── Image folder picker ───────────────────────────────
                      // Pick button
                      ElevatedButton.icon(
                        key: const Key('pick_folder_btn'),
                        onPressed:
                            (_phase == _ImportPhase.parsing || _submitting)
                            ? null
                            : _pickFolder,
                        icon: const Icon(Icons.folder),
                        label: Text(
                          _pickedFileName.isEmpty
                              ? 'Select Image Folder'
                              : 'Replace Folder',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),

                      if (_pickedFileName.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.attach_file,
                              size: 14,
                              color: AppColors.mutedText,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _pickedFileName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mutedText,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],


                      const SizedBox(height: 12),

                      // Status message
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          _phase == _ImportPhase.parsing
                              ? 'Parsing file…'
                              : _phaseMessage,
                          key: ValueKey(_phaseMessage),
                          style: TextStyle(
                            color: _messageColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 16),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 16),

                      // Template + Sample buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const Key('download_template_btn'),
                              onPressed: _submitting ? null : _downloadTemplate,
                              icon: const Icon(Icons.download, size: 16),
                              label: const Text('Excel Template'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryBlue,
                                side: const BorderSide(
                                  color: AppColors.primaryBlue,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const Key('download_sample_btn'),
                              onPressed: _submitting
                                  ? null
                                  : _downloadSampleFolder,
                              icon: const Icon(Icons.download_for_offline, size: 16),
                              label: const Text('Sample Data'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.mutedText,
                                side: const BorderSide(color: AppColors.border),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── preview section ────────────────────────────────────────────
              if (_preview != null && _preview!.rows.isNotEmpty) ...[
                const SizedBox(height: 20),
                _SummaryBar(preview: _preview!),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Preview  ·  ${_preview!.totalRows} rows',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_preview!.errorCount > 0)
                      TextButton.icon(
                        key: const Key('copy_errors_btn'),
                        onPressed: _copyErrors,
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('Copy Errors'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.statusRejectedText,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ImportPreviewTable(preview: _preview!),
                  ),
                ),
                const SizedBox(height: 20),

                if (_phase == _ImportPhase.importing ||
                    _phase == _ImportPhase.success) ...[
                  _ImportProgress(
                    processedRows: _processedRows,
                    totalRows: _progressTotalRows,
                  ),
                  const SizedBox(height: 12),
                ],

                // ── import button ────────────────────────────────────────────
                ElevatedButton(
                  key: const Key('confirm_import_btn'),
                  onPressed: _canImport ? _confirmImport : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.statusApprovedText,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _phase == _ImportPhase.importing
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text('Importing…'),
                          ],
                        )
                      : Text(
                          _phase == _ImportPhase.success
                              ? 'Import Complete'
                              : 'Confirm Import',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── summary bar ─────────────────────────────────────────────────────────────

class _ImportProgress extends StatelessWidget {
  const _ImportProgress({
    required this.processedRows,
    required this.totalRows,
  });

  final int processedRows;
  final int totalRows;

  @override
  Widget build(BuildContext context) {
    final progress = totalRows == 0 ? 0.0 : processedRows / totalRows;
    final percentage = (progress * 100).floor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          key: const Key('bulk_import_progress_bar'),
          value: progress,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
          backgroundColor: AppColors.border,
          color: AppColors.primaryBlue,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$processedRows / $totalRows',
              key: const Key('bulk_import_progress_count'),
            ),
            Text(
              '$percentage%',
              key: const Key('bulk_import_progress_percentage'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final BulkImportPreview preview;
  const _SummaryBar({required this.preview});

  @override
  Widget build(BuildContext context) {
    final withImages = preview.rows
        .where((r) => r.isValid && r.imageStatus != null)
        .length;

    return Container(
      key: const Key('summary_bar'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _Chip(
            label: 'Total',
            value: preview.totalRows.toString(),
            color: AppColors.mutedText,
          ),
          const _Divider(),
          _Chip(
            label: 'Valid',
            value: preview.validCount.toString(),
            color: AppColors.statusApprovedText,
          ),
          const _Divider(),
          _Chip(
            label: 'Invalid',
            value: preview.errorCount.toString(),
            color: preview.errorCount > 0
                ? AppColors.statusRejectedText
                : AppColors.mutedText,
          ),
          if (withImages > 0) ...[
            const _Divider(),
            _Chip(
              label: 'Images',
              value: withImages.toString(),
              color: AppColors.primaryBlue,
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Chip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: AppColors.border);
  }
}
