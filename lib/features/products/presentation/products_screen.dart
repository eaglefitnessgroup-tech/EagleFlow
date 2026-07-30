import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/eagle_bottom_nav.dart';
import '../domain/product.dart';
import '../data/sample_products.dart';
import 'widgets/product_search_field.dart';
import 'widgets/product_category_chips.dart';
import 'widgets/product_filter_row.dart';
import 'widgets/product_card.dart';
import 'widgets/add_custom_item_sheet.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _selectedCategory = 'All';
  bool _inStockOnly = false;
  bool _lowStockOnly = false;

  List<Product> get _filteredProducts {
    return sampleProducts.where((product) {
      // Category filter
      if (_selectedCategory != 'All' && product.category != _selectedCategory) {
        return false;
      }

      // Stock filters
      if (_inStockOnly && product.stockQuantity <= 0) {
        return false;
      }
      if (_lowStockOnly &&
          (product.stockQuantity <= 0 || product.stockQuantity > 5)) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _filteredProducts;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const EagleBottomNav(currentIndex: 1),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(20.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildHeader(),
                      const SizedBox(height: 24),
                      const ProductSearchField(),
                      const SizedBox(height: 20),
                      ProductCategoryChips(
                        selectedCategory: _selectedCategory,
                        onCategorySelected: (category) {
                          setState(() {
                            _selectedCategory = category;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      ProductFilterRow(
                        inStockOnly: _inStockOnly,
                        lowStockOnly: _lowStockOnly,
                        onInStockToggled: (val) {
                          setState(() {
                            _inStockOnly = val;
                            if (val) _lowStockOnly = false;
                          });
                        },
                        onLowStockToggled: (val) {
                          setState(() {
                            _lowStockOnly = val;
                            if (val) _inStockOnly = false;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildListHeader(filteredProducts.length),
                      const SizedBox(height: 16),
                    ]),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  sliver: filteredProducts.isEmpty
                      ? SliverToBoxAdapter(child: _buildEmptyState())
                      : SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            return ProductCard(
                              product: filteredProducts[index],
                            );
                          }, childCount: filteredProducts.length),
                        ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Products',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.charcoal,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Find and add products to your quotation',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.mutedText,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildListHeader(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '$count Products',
          style: const TextStyle(
            color: AppColors.charcoal,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        TextButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => const AddCustomItemSheet(),
            );
          },
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryBlue,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          child: const Text('+ Custom Item'),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: AppColors.border,
          ),
          const SizedBox(height: 16),
          Text(
            'No products found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.charcoal,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try another product name or code.',
            style: TextStyle(color: AppColors.mutedText, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
