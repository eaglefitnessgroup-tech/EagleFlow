import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/service_locator.dart';
import '../domain/product.dart';
import 'widgets/details/product_image_panel.dart';
import 'widgets/details/product_info_section.dart';
import 'widgets/details/product_stock_section.dart';
import 'widgets/details/product_description_section.dart';
import 'widgets/details/quantity_selector.dart';
import 'widgets/details/product_details_bottom_bar.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product? testProduct;

  const ProductDetailsScreen({super.key, this.testProduct});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int _quantity = 1;
  Product? _product;
  bool _isLoadingStock = true;
  bool _hasStockError = false;
  int _currentStock = 0;
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      _product =
          widget.testProduct ??
          ModalRoute.of(context)?.settings.arguments as Product?;
      if (_product != null) {
        _fetchStock();
      }
      _isInit = true;
    }
  }

  Future<void> _fetchStock() async {
    if (_product == null) return;
    setState(() {
      _isLoadingStock = true;
      _hasStockError = false;
    });
    try {
      final stock = await ServiceLocator().stockController.getCurrentStock(
        _product!,
      );
      if (mounted) {
        setState(() {
          _currentStock = stock;
          _isLoadingStock = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasStockError = true;
          _isLoadingStock = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;

    // Fallback if product is null
    if (product == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Product Details',
            style: TextStyle(color: AppColors.charcoal),
          ),
          backgroundColor: AppColors.background,
          iconTheme: const IconThemeData(color: AppColors.charcoal),
          elevation: 0,
        ),
        body: const Center(child: Text('Product not found.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Product Details',
          style: TextStyle(
            color: AppColors.charcoal,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: AppColors.charcoal),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProductImagePanel(imageBytes: product.imageBytes),
                  const SizedBox(height: 32),
                  ProductInfoSection(
                    product: product,
                    currentStock: _currentStock,
                    isLoading: _isLoadingStock,
                    hasError: _hasStockError,
                  ),
                  const SizedBox(height: 32),
                  ProductStockSection(
                    product: product,
                    currentStock: _currentStock,
                    isLoading: _isLoadingStock,
                    hasError: _hasStockError,
                    onRetry: _fetchStock,
                    onStockAdjusted: _fetchStock,
                  ),
                  const SizedBox(height: 32),
                  ProductDescriptionSection(description: product.description),
                  if (product.description.isNotEmpty)
                    const SizedBox(height: 32),
                  QuantitySelector(
                    quantity: _quantity,
                    onChanged: (val) {
                      setState(() {
                        _quantity = val;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: ProductDetailsBottomBar(
        product: product,
        quantity: _quantity,
      ),
    );
  }
}
