import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/eagle_bottom_nav.dart';
import '../domain/product.dart';
import '../../../../core/di/service_locator.dart';
import '../application/product_master_controller.dart';
import 'widgets/product_search_field.dart';
import 'widgets/product_category_chips.dart';
import 'widgets/product_filter_row.dart';
import 'widgets/product_card.dart';
import 'add_edit_product_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _inStockOnly = false;
  bool _lowStockOnly = false;

  int _scoreProduct(Product p, String q) {
    final n = p.name.toLowerCase();
    final b = p.brand.toLowerCase();
    final c = p.productCode.toLowerCase();

    final namePrefix = n.startsWith(q);
    final namePartial = n.contains(q) && !namePrefix;

    final inStock = p.openingStock > 5;
    final lowStock =
        p.openingStock > 0 &&
        p.openingStock <= (p.minStockLevel > 0 ? p.minStockLevel : 5);
    final outOfStock = p.openingStock <= 0;

    if (namePrefix || namePartial) {
      if (outOfStock) return 5;

      if (inStock) {
        if (namePrefix) return 1;
        return 2;
      }

      if (lowStock) {
        if (namePrefix) return 3;
        return 4;
      }
    }

    if (b.contains(q)) return 6;
    if (c.contains(q)) return 7;

    return 99;
  }

  List<Product> _getFilteredProducts(ProductMasterController controller) {
    var list = controller.products.where((product) {
      // Category filter
      if (_selectedCategory != 'All' && product.category != _selectedCategory) {
        return false;
      }

      // Stock filters
      if (_inStockOnly && product.openingStock <= 0) {
        return false;
      }
      if (_lowStockOnly &&
          (product.openingStock <= 0 ||
              product.openingStock >
                  (product.minStockLevel > 0 ? product.minStockLevel : 5))) {
        return false;
      }

      return true;
    }).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery;
      list = list.where((product) {
        final n = product.name.toLowerCase();
        final c = product.productCode.toLowerCase();
        final b = product.brand.toLowerCase();
        return n.contains(q) || c.contains(q) || b.contains(q);
      }).toList();

      list.sort((a, b) {
        final scoreA = _scoreProduct(a, q);
        final scoreB = _scoreProduct(b, q);
        if (scoreA == scoreB) {
          return a.name.compareTo(b.name);
        }
        return scoreA.compareTo(scoreB);
      });
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final controller = ServiceLocator().productMasterController;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final filteredProducts = _getFilteredProducts(controller);

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
                          ProductSearchField(
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val.trim().toLowerCase();
                              });
                            },
                          ),
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
      },
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
        if (ServiceLocator().authController.isAdmin)
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => const AddEditProductScreen(),
                ),
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
            child: const Text('+ Add Product'),
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.search_off_outlined,
              size: 48,
              color: AppColors.mutedText,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty
                ? 'No matches for "$_searchQuery"'
                : 'No products found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.charcoal,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty
                ? 'Check the spelling or try a different search term.'
                : 'Try adjusting your filters or search criteria.',
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 15,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isNotEmpty ||
              _selectedCategory != 'All' ||
              _inStockOnly ||
              _lowStockOnly) ...[
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _selectedCategory = 'All';
                  _inStockOnly = false;
                  _lowStockOnly = false;
                });
              },
              icon: const Icon(Icons.clear_all, size: 20),
              label: const Text(
                'Clear Filters',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
