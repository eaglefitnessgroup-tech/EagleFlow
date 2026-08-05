import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../application/quotation_controller.dart';
import '../domain/quotation.dart';
import '../domain/quotation_defaults.dart';
import 'preview/models/quotation_preview_page.dart';
import 'preview/utils/quotation_paginator.dart';
import 'preview/components/quotation_a4_page.dart';
import 'preview/pages/quotation_products_page.dart';
import 'preview/pages/quotation_info_page.dart';

import 'package:printing/printing.dart';
import '../application/quotation_pdf_service.dart';
import '../../../core/utils/pdf_saver.dart';

class QuotationPreviewScreen extends StatefulWidget {
  const QuotationPreviewScreen({super.key});

  @override
  State<QuotationPreviewScreen> createState() => _QuotationPreviewScreenState();
}

class _QuotationPreviewScreenState extends State<QuotationPreviewScreen> {
  int _currentPageIndex = 0;
  QuotationController? _controller;
  List<QuotationPreviewPage> _pages = [];
  bool _isError = false;
  String _errorMsg = '';
  bool _isGeneratingPdf = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is QuotationController) {
      _controller = args;
      _pages = QuotationPaginator.paginate(_controller!.quotation);
    } else if (args is Quotation) {
      _controller = QuotationController(QuotationDefaults.createEmptyDraft());
      _controller!.loadQuotation(args);
      _pages = QuotationPaginator.paginate(_controller!.quotation);
    } else {
      _isError = true;
      _errorMsg = 'Invalid quotation data provided.';
    }
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

  void _onEdit() {
    Navigator.pop(context);
  }

  Future<void> _handlePdfAction(String action) async {
    if (_controller == null) return;

    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      final service = QuotationPdfService();
      final pdfBytes = await service.generatePdf(_controller!.quotation);
      final sanitizedNumber = _controller!.quotation.quotationNumber
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final filename = '$sanitizedNumber.pdf';

      if (action == 'pdf') {
        final outputPath = await savePdf(pdfBytes, filename);
        if (outputPath != null && mounted) {
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
        await Printing.sharePdf(bytes: pdfBytes, filename: filename);
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
      );
    } else if (pageModel is QuotationInfoPageModel) {
      return QuotationInfoPage(quotation: _controller!.quotation);
    }
    return const SizedBox.shrink();
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
        actions: [
          TextButton.icon(
            onPressed: _onEdit,
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Edit'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.charcoal,
              textStyle: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'pdf' || value == 'print' || value == 'share') {
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
                enabled: false,
                child: Text(
                  'Export to Excel (Coming Soon)',
                  style: TextStyle(fontSize: 14),
                ),
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
          const SizedBox(width: 8),
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

                      Widget pageContainer;
                      if (isMobile) {
                        final pageWidth = constraints.maxWidth * 0.95;
                        pageContainer = Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: SizedBox(
                              width: pageWidth,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
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
                        );
                      } else {
                        pageContainer = Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 820),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
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
                        );
                      }

                      return SingleChildScrollView(child: pageContainer);
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: const Border(
                      top: BorderSide(color: AppColors.border),
                    ),
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
