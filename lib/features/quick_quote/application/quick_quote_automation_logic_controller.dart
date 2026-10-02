import 'package:flutter/foundation.dart';

import '../../../core/utils/file_download_util.dart';
import '../../products/domain/product.dart';
import '../domain/quick_quote_config_repository.dart';
import '../domain/quick_quote_configuration.dart';
import 'quick_quote_config_workbook_service.dart';

typedef QuickQuoteConfigProductLoader = Future<List<Product>> Function();
typedef QuickQuoteConfigFileSaver =
    Future<void> Function({required List<int> bytes, required String filename});

enum QuickQuoteAutomationLogicStatus {
  loading,
  ready,
  validating,
  applying,
  downloading,
  error,
}

class QuickQuoteAutomationLogicController extends ChangeNotifier {
  QuickQuoteAutomationLogicController({
    required this.repository,
    required this.productLoader,
    required this.isAdmin,
    QuickQuoteConfigWorkbookService? workbookService,
    QuickQuoteConfigFileSaver? fileSaver,
  }) : workbookService = workbookService ?? QuickQuoteConfigWorkbookService(),
       fileSaver = fileSaver ?? FileDownloadUtil.save;

  final QuickQuoteConfigRepository repository;
  final QuickQuoteConfigProductLoader productLoader;
  final bool Function() isAdmin;
  final QuickQuoteConfigWorkbookService workbookService;
  final QuickQuoteConfigFileSaver fileSaver;

  QuickQuoteAutomationLogicStatus _status =
      QuickQuoteAutomationLogicStatus.loading;
  QuickQuoteConfiguration? _activeConfiguration;
  List<QuickQuoteConfigVersion> _history = const [];
  QuickQuoteConfigImportResult? _importResult;
  String? _errorMessage;
  bool _showDiff = false;

  QuickQuoteAutomationLogicStatus get status => _status;
  QuickQuoteConfiguration? get activeConfiguration => _activeConfiguration;
  List<QuickQuoteConfigVersion> get history => _history;
  QuickQuoteConfigImportResult? get importResult => _importResult;
  String? get errorMessage => _errorMessage;
  bool get showDiff => _showDiff;
  bool get isBusy =>
      _status == QuickQuoteAutomationLogicStatus.loading ||
      _status == QuickQuoteAutomationLogicStatus.validating ||
      _status == QuickQuoteAutomationLogicStatus.applying ||
      _status == QuickQuoteAutomationLogicStatus.downloading;
  bool get canApply =>
      !isBusy && (_importResult?.canApply ?? false) && isAdmin();

  Future<void> initialize() async {
    _requireAdmin();
    _status = QuickQuoteAutomationLogicStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      await _reload();
      _status = QuickQuoteAutomationLogicStatus.ready;
    } catch (_) {
      _status = QuickQuoteAutomationLogicStatus.error;
      _errorMessage =
          'Unable to load Quick Quote automation configuration. Please try again.';
    }
    notifyListeners();
  }

  Future<void> validateWorkbook({
    required String filename,
    required List<int> bytes,
  }) async {
    _requireAdmin();
    if (!filename.toLowerCase().endsWith('.xlsx')) {
      _errorMessage = 'Only .xlsx workbooks are supported.';
      _importResult = null;
      _status = QuickQuoteAutomationLogicStatus.ready;
      notifyListeners();
      return;
    }
    _status = QuickQuoteAutomationLogicStatus.validating;
    _errorMessage = null;
    _importResult = null;
    _showDiff = false;
    notifyListeners();
    try {
      final products = await productLoader();
      _importResult = workbookService.parseAndValidate(
        bytes: bytes,
        sourceFilename: filename,
        products: products,
        currentConfiguration: _activeConfiguration,
      );
      _status = QuickQuoteAutomationLogicStatus.ready;
    } on FormatException catch (error) {
      _status = QuickQuoteAutomationLogicStatus.ready;
      _errorMessage = error.message;
    } catch (_) {
      _status = QuickQuoteAutomationLogicStatus.ready;
      _errorMessage =
          'The workbook could not be validated. Check the file and try again.';
    }
    notifyListeners();
  }

  void previewChanges() {
    if (_importResult == null) return;
    _showDiff = true;
    notifyListeners();
  }

  Future<bool> apply() async {
    _requireAdmin();
    final result = _importResult;
    if (result == null || !result.canApply || isBusy) return false;
    _status = QuickQuoteAutomationLogicStatus.applying;
    _errorMessage = null;
    notifyListeners();
    try {
      _activeConfiguration = await repository.applyConfiguration(
        sourceFilename: result.sourceFilename,
        configuration: result.configuration,
        validationSummary: result.summary,
      );
      _history = await repository.getVersionHistory();
      _importResult = null;
      _showDiff = false;
      _status = QuickQuoteAutomationLogicStatus.ready;
      notifyListeners();
      return true;
    } catch (_) {
      _status = QuickQuoteAutomationLogicStatus.ready;
      _errorMessage =
          'Apply failed. The current active configuration was not changed.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> activateVersion(String versionId) async {
    _requireAdmin();
    if (isBusy) return false;
    _status = QuickQuoteAutomationLogicStatus.applying;
    _errorMessage = null;
    notifyListeners();
    try {
      _activeConfiguration = await repository.activateVersion(versionId);
      _history = await repository.getVersionHistory();
      _status = QuickQuoteAutomationLogicStatus.ready;
      notifyListeners();
      return true;
    } catch (_) {
      _status = QuickQuoteAutomationLogicStatus.ready;
      _errorMessage =
          'Activation failed. The current active configuration was not changed.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> downloadCurrentLogic() async {
    _requireAdmin();
    final configuration = _activeConfiguration;
    if (configuration == null || isBusy) return false;
    _status = QuickQuoteAutomationLogicStatus.downloading;
    _errorMessage = null;
    notifyListeners();
    try {
      await fileSaver(
        bytes: workbookService.export(configuration),
        filename: QuickQuoteConfigWorkbookService.exportFilename,
      );
      _status = QuickQuoteAutomationLogicStatus.ready;
      notifyListeners();
      return true;
    } catch (_) {
      _status = QuickQuoteAutomationLogicStatus.ready;
      _errorMessage =
          'The active configuration workbook could not be downloaded.';
      notifyListeners();
      return false;
    }
  }

  Future<void> _reload() async {
    final results = await Future.wait<Object?>([
      repository.getActiveConfiguration(),
      repository.getVersionHistory(),
    ]);
    _activeConfiguration = results[0] as QuickQuoteConfiguration?;
    _history = List<QuickQuoteConfigVersion>.unmodifiable(
      results[1] as List<QuickQuoteConfigVersion>,
    );
  }

  void _requireAdmin() {
    if (!isAdmin()) {
      throw StateError('Admin access required.');
    }
  }
}
