import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../application/quotation_controller.dart';
import '../domain/quotation.dart';
import '../domain/quotation_defaults.dart';
import 'preview/quotation_layout_spec.dart';
import 'preview/models/quotation_preview_page.dart';
import 'preview/utils/quotation_paginator.dart';
import 'preview/components/quotation_a4_page.dart';
import 'preview/pages/quotation_products_page.dart';
import 'preview/pages/quotation_info_page.dart';

import 'package:printing/printing.dart';
import '../application/quotation_excel_service.dart';
import '../application/quotation_pdf_service.dart';
import '../application/salesperson_name_resolver.dart';
import '../../../core/utils/file_download_util.dart';
import '../../../core/utils/pdf_saver.dart';
import '../../../core/utils/pdf_share_helper.dart';
import '../../../../core/di/service_locator.dart';

typedef QuotationExcelGenerator =
    List<int> Function(Quotation quotation, {String? salespersonName});
typedef QuotationFileDownloader =
    Future<void> Function({required List<int> bytes, required String filename});
typedef QuotationPdfGenerator = Future<Uint8List> Function(Quotation quotation);
typedef QuotationPdfSaver =
    Future<String?> Function(Uint8List bytes, String filename);

class QuotationPreviewScreen extends StatefulWidget {
  const QuotationPreviewScreen({
    super.key,
    this.excelGenerator,
    this.fileDownloader,
    this.pdfGenerator,
    this.pdfSaver,
    this.pdfShareHelper,
  });

  final QuotationExcelGenerator? excelGenerator;
  final QuotationFileDownloader? fileDownloader;
  final QuotationPdfGenerator? pdfGenerator;
  final QuotationPdfSaver? pdfSaver;
  final PdfShareHelper? pdfShareHelper;

  @override
  State<QuotationPreviewScreen> createState() => _QuotationPreviewScreenState();
}

class _QuotationPreviewScreenState extends State<QuotationPreviewScreen> {
  static const int _minZoomPercent = 60;
  static const int _maxZoomPercent = 160;
  static const int _zoomStepPercent = 10;

  int _currentPageIndex = 0;
  int _zoomPercent = 100;
  QuotationController? _controller;
  bool _returnsToOriginatingEditor = false;
  List<QuotationPreviewPage> _pages = [];
  bool _isError = false;
  String _errorMsg = '';
  bool _isSaving = false;
  bool _isGeneratingPdf = false;
  String? _resolvedSalespersonName;
  int _salespersonResolutionRequest = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is QuotationController) {
      _controller = args;
      _returnsToOriginatingEditor = true;
      _pages = QuotationPaginator.paginate(_controller!.quotation);
    } else if (args is Quotation) {
      _controller = QuotationController(QuotationDefaults.createEmptyDraft());
      _controller!.loadQuotation(args);
      _returnsToOriginatingEditor = false;
      _pages = QuotationPaginator.paginate(_controller!.quotation);
    } else {
      _isError = true;
      _errorMsg = 'Invalid quotation data provided.';
    }

    _resolveSalespersonName();
  }

  Future<void> _resolveSalespersonName() async {
    if (_controller == null) return;
    final request = ++_salespersonResolutionRequest;
    final controller = _controller!;
    final quotation = controller.quotation;
    final quotationId = quotation.id;
    final quotationNumber = quotation.quotationNumber;
    final salespersonId = quotation.salespersonId;
    final currentUser = ServiceLocator().authController.currentUser;

    if (currentUser != null && currentUser.id == salespersonId) {
      _resolvedSalespersonName = SalespersonNameResolver.resolve(
        salespersonId: salespersonId,
        currentUser: currentUser,
      );
      return;
    }

    try {
      final users = await ServiceLocator().authRepository.getUsers();
      final latestCurrentUser = ServiceLocator().authController.currentUser;
      final currentQuotation = _controller?.quotation;
      final authenticationIsCurrent =
          latestCurrentUser?.id == currentUser?.id ||
          latestCurrentUser?.id == salespersonId;
      final isCurrentRequest =
          mounted &&
          authenticationIsCurrent &&
          request == _salespersonResolutionRequest &&
          identical(_controller, controller) &&
          currentQuotation?.id == quotationId &&
          currentQuotation?.quotationNumber == quotationNumber &&
          currentQuotation?.salespersonId == salespersonId;

      if (isCurrentRequest) {
        setState(() {
          _resolvedSalespersonName = SalespersonNameResolver.resolve(
            salespersonId: salespersonId,
            currentUser: latestCurrentUser,
            profiles: users,
          );
        });
      }
    } catch (_) {}
  }

  void _nextPage() {
    if (_currentPageIndex < _pages.length - 1) {
      setState(() {
        _currentPageIndex++;
      });
    }
  }

  void _prevPage() {
    if (_currentPageIndex > 0) {
      setState(() {
        _currentPageIndex--;
      });
    }
  }

  void _zoomIn() {
    if (_zoomPercent >= _maxZoomPercent) return;
    setState(() {
      _zoomPercent = (_zoomPercent + _zoomStepPercent).clamp(
        _minZoomPercent,
        _maxZoomPercent,
      );
    });
  }

  void _zoomOut() {
    if (_zoomPercent <= _minZoomPercent) return;
    setState(() {
      _zoomPercent = (_zoomPercent - _zoomStepPercent).clamp(
        _minZoomPercent,
        _maxZoomPercent,
      );
    });
  }

  void _resetZoom() {
    if (_zoomPercent == 100) return;
    setState(() => _zoomPercent = 100);
  }

  void _onEdit() {
    if (_controller == null) return;

    if (_returnsToOriginatingEditor) {
      Navigator.pop(context, _controller!.quotation);
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      '/create-quotation',
      arguments: _controller!.quotation,
    );
  }

  Future<void> _handleSave() async {
    if (_isSaving || _controller == null) return;

    final user = ServiceLocator().authController.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in again to save the quotation.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final savedQuotation = await _controller!.save(
        ServiceLocator().quotationRepository,
      );
      if (mounted) {
        setState(() {
          _pages = QuotationPaginator.paginate(savedQuotation);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Quotation saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleExcelExport() async {
    if (_controller == null) return;

    try {
      final quotation = _controller!.quotation;
      final generator = widget.excelGenerator;
      final workbookBytes = generator == null
          ? QuotationExcelService().generateWorkbook(
              quotation,
              salespersonName: _resolvedSalespersonName,
            )
          : generator(quotation, salespersonName: _resolvedSalespersonName);
      final sanitizedNumber = quotation.quotationNumber.replaceAll(
        RegExp(r'[\\/:*?"<>|]'),
        '_',
      );
      final filename = '$sanitizedNumber.xlsx';
      final downloader = widget.fileDownloader ?? FileDownloadUtil.save;

      await downloader(bytes: workbookBytes, filename: filename);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating Excel: $e')));
      }
    }
  }

  Future<void> _handlePdfAction(
    String action, {
    bool showSaveConfirmation = true,
  }) async {
    if (_controller == null || _isGeneratingPdf) return;

    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      final generator = widget.pdfGenerator;
      final pdfBytes = generator == null
          ? await QuotationPdfService().generatePdf(_controller!.quotation)
          : await generator(_controller!.quotation);
      final sanitizedNumber = _controller!.quotation.quotationNumber.replaceAll(
        RegExp(r'[\\/:*?"<>|]'),
        '_',
      );
      final filename = '$sanitizedNumber.pdf';
      final pdfSaver = widget.pdfSaver ?? savePdf;

      if (action == 'pdf') {
        final outputPath = await pdfSaver(pdfBytes, filename);
        if (showSaveConfirmation && outputPath != null && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Saved to $outputPath')));
        }
      } else if (action == 'print') {
        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: filename,
        );
      } else if (action == 'share') {
        try {
          await (widget.pdfShareHelper ?? PdfShareHelper()).sharePdf(
            bytes: pdfBytes,
            filename: filename,
          );
        } catch (_) {
          await pdfSaver(pdfBytes, filename);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "File sharing isn't supported in this browser. "
                  'The PDF was downloaded instead.',
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
  }

  Widget _buildPageContent(QuotationPreviewPage pageModel) {
    if (pageModel is QuotationProductsPageModel) {
      int startIndex = 0;
      for (int i = 0; i < _currentPageIndex; i++) {
        if (_pages[i] is QuotationProductsPageModel) {
          startIndex += (_pages[i] as QuotationProductsPageModel).items.length;
        }
      }
      return QuotationProductsPage(
        quotation: _controller!.quotation,
        model: pageModel,
        startIndex: startIndex,
        salespersonName: _resolvedSalespersonName,
      );
    } else if (pageModel is QuotationInfoPageModel) {
      return QuotationInfoPage(
        quotation: _controller!.quotation,
        salespersonName: _resolvedSalespersonName,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildZoomControls() {
    return SizedBox(
      height: 36,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('preview-zoom-out'),
            onPressed: _zoomPercent > _minZoomPercent ? _zoomOut : null,
            icon: const Icon(Icons.remove, size: 18),
            tooltip: 'Zoom out',
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          ),
          TextButton(
            key: const Key('preview-zoom-reset'),
            onPressed: _zoomPercent == 100 ? null : _resetZoom,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 32),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
              foregroundColor: AppColors.charcoal,
              disabledForegroundColor: AppColors.charcoal,
            ),
            child: Text(
              '$_zoomPercent%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            key: const Key('preview-zoom-in'),
            onPressed: _zoomPercent < _maxZoomPercent ? _zoomIn : null,
            icon: const Icon(Icons.add, size: 18),
            tooltip: 'Zoom in',
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isError || _controller == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Preview Error',
            style: TextStyle(color: AppColors.charcoal, fontSize: 16),
          ),
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: const IconThemeData(color: AppColors.charcoal),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMsg,
                style: const TextStyle(fontSize: 16, color: AppColors.charcoal),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final isNarrow = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = MediaQuery.of(context).size.width < 400;
            return Text(
              isSmall ? 'Preview' : 'Quotation Preview',
              style: const TextStyle(
                color: AppColors.charcoal,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            );
          },
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        iconTheme: const IconThemeData(color: AppColors.charcoal, size: 20),
        bottom: isNarrow
            ? PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _buildZoomControls(),
                ),
              )
            : null,
        actions: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = MediaQuery.of(context).size.width < 400;
              if (isSmall) {
                return TextButton(
                  onPressed: _isSaving ? null : _handleSave,
                  child: const Text('Save'),
                );
              }
              return TextButton.icon(
                onPressed: _isSaving ? null : _handleSave,
                icon: const Icon(Icons.save_outlined, size: 16),
                label: const Text('Save'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.charcoal,
                  textStyle: const TextStyle(fontWeight: FontWeight.w500),
                ),
              );
            },
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = MediaQuery.of(context).size.width < 400;
              if (isSmall) {
                return IconButton(
                  onPressed: _onEdit,
                  icon: const Icon(Icons.edit, size: 18),
                  tooltip: 'Edit',
                  color: AppColors.charcoal,
                );
              }
              return TextButton.icon(
                onPressed: _onEdit,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Edit'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.charcoal,
                  textStyle: const TextStyle(fontWeight: FontWeight.w500),
                ),
              );
            },
          ),
          if (!isNarrow) _buildZoomControls(),
          IconButton(
            onPressed: _isGeneratingPdf
                ? null
                : () => _handlePdfAction('pdf', showSaveConfirmation: false),
            icon: const Icon(Icons.download_outlined, size: 18),
            tooltip: 'Download PDF',
            color: AppColors.charcoal,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'excel') {
                _handleExcelExport();
              } else if (value == 'pdf' ||
                  value == 'print' ||
                  value == 'share') {
                _handlePdfAction(value);
              }
            },
            icon: const Icon(Icons.ios_share, size: 18),
            tooltip: 'Export',
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pdf',
                child: Text('Export to PDF', style: TextStyle(fontSize: 14)),
              ),
              const PopupMenuItem(
                value: 'excel',
                child: Text('Export to Excel', style: TextStyle(fontSize: 14)),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'print',
                child: Text('Print', style: TextStyle(fontSize: 14)),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Text('Share PDF', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      final availablePageWidth = isMobile
                          ? constraints.maxWidth * 0.95
                          : 820.0;
                      final basePageWidth =
                          availablePageWidth <
                              QuotationLayoutSpec.a4LogicalWidth
                          ? availablePageWidth
                          : QuotationLayoutSpec.a4LogicalWidth;
                      final zoomScale = _zoomPercent / 100;
                      final scaledPageWidth = basePageWidth * zoomScale;
                      final scaledPageHeight =
                          basePageWidth /
                          QuotationLayoutSpec.a4LogicalWidth *
                          QuotationLayoutSpec.a4LogicalHeight *
                          zoomScale;
                      final verticalPadding = isMobile ? 24.0 : 32.0;
                      final contentWidth = scaledPageWidth + 32;
                      final scrollContentWidth =
                          contentWidth > constraints.maxWidth
                          ? contentWidth
                          : constraints.maxWidth;

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: scrollContentWidth,
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: verticalPadding,
                                horizontal: 16,
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: scaledPageWidth,
                                  height: scaledPageHeight,
                                  child: FittedBox(
                                    fit: BoxFit.contain,
                                    alignment: Alignment.topCenter,
                                    child: QuotationA4Page(
                                      child: Stack(
                                        children: [
                                          _buildPageContent(
                                            _pages[_currentPageIndex],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _currentPageIndex > 0 ? _prevPage : null,
                          icon: const Icon(Icons.chevron_left, size: 24),
                          color: AppColors.charcoal,
                          disabledColor: AppColors.mutedText.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Page ${_currentPageIndex + 1} of ${_pages.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: AppColors.charcoal,
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: _currentPageIndex < _pages.length - 1
                              ? _nextPage
                              : null,
                          icon: const Icon(Icons.chevron_right, size: 24),
                          color: AppColors.charcoal,
                          disabledColor: AppColors.mutedText.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_isGeneratingPdf)
              Container(
                color: Colors.white.withValues(alpha: 0.8),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Generating PDF...',
                        style: TextStyle(
                          color: AppColors.charcoal,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
