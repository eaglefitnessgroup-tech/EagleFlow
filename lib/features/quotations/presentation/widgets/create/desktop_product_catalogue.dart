import 'package:flutter/material.dart';
import '../../../../../../app/theme/app_colors.dart';
import '../../../../products/domain/product.dart';
import '../../../../products/presentation/widgets/product_image.dart';
import '../../../../../../core/di/service_locator.dart';

class DesktopProductCatalogue extends StatefulWidget {
  final Function(List<Product>) onProductsAdded;
  final Widget rightPanel;

  const DesktopProductCatalogue({
    super.key,
    required this.onProductsAdded,
    required this.rightPanel,
  });

  @override
  State<DesktopProductCatalogue> createState() => _DesktopProductCatalogueState();
}

class _DesktopProductCatalogueState extends State<DesktopProductCatalogue> {
  final TextEditingController _searchController = TextEditingController();
  
  String _searchQuery = '';
  String? _selectedCategory;
  
  List<Product> _allActiveProducts = [];
  List<Product> _filteredProducts = [];
  Map<String, int> _stockMap = {};
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Ensure products are loaded
    await ServiceLocator().productMasterController.loadProducts();
    
    _allActiveProducts = ServiceLocator().productMasterController.products
        .where((p) => p.isActive)
        .toList();

    // Preload stock for fast filtering
    final stockFutures = _allActiveProducts.map((p) async {
      final stock = await ServiceLocator().stockController.getCurrentStock(p);
      return MapEntry(p.id, stock);
    });
    
    final stockEntries = await Future.wait(stockFutures);
    final stockMap = Map.fromEntries(stockEntries);

    if (mounted) {
      setState(() {
        _stockMap = stockMap;
        _isLoading = false;
        _applyFilters();
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.length < 2 && query.isNotEmpty) {
      // Wait for 2+ characters
      return;
    }
    setState(() {
      _searchQuery = query.toLowerCase();
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<Product> filtered = _allActiveProducts;

    // Apply category filter
    if (_selectedCategory != null) {
      filtered = filtered.where((p) => p.category == _selectedCategory).toList();
    }

    // Apply search filter (if 2+ chars)
    if (_searchQuery.isNotEmpty && _searchQuery.length >= 2) {
      filtered = filtered.where((p) {
        final nameMatches = p.name.toLowerCase().contains(_searchQuery);
        final codeMatches = p.productCode.toLowerCase().contains(_searchQuery);
        final brandMatches = p.brand.toLowerCase().contains(_searchQuery);
        final modelMatches = (p.modelNumber ?? '').toLowerCase().contains(_searchQuery);
        return nameMatches || codeMatches || brandMatches || modelMatches;
      }).toList();
    }

    // Sort: In stock first, then alphabetically
    filtered.sort((a, b) {
      final aStock = _stockMap[a.id] ?? 0;
      final bStock = _stockMap[b.id] ?? 0;
      
      final aInStock = aStock > 0;
      final bInStock = bStock > 0;

      if (aInStock && !bInStock) return -1;
      if (!aInStock && bInStock) return 1;

      return a.name.compareTo(b.name);
    });

    _filteredProducts = filtered;
  }

  void _selectCategory(String? category) {
    setState(() {
      _selectedCategory = category;
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(color: AppColors.primaryBlue),
        ),
      );
    }

    // Extract unique categories from actual data
    final categories = _allActiveProducts.map((p) => p.category).toSet().toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Categories
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildCategoryCard('All Products', isSelected: _selectedCategory == null, onTap: () => _selectCategory(null)),
              const SizedBox(width: 8),
              ...categories.map((cat) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: _buildCategoryCard(
                    cat,
                    isSelected: _selectedCategory == cat,
                    onTap: () => _selectCategory(cat),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LEFT: Search and Results (42%)
              Expanded(
                flex: 42,
                child: Column(
                  children: [
                    // 2. Smart Search
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search by product name, model, SKU or brand...',
            hintStyle: const TextStyle(color: AppColors.mutedText),
            prefixIcon: const Icon(Icons.search, color: AppColors.mutedText),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _applyFilters();
                      });
                    },
                  )
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primaryBlue),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // 3. Search Results
        SizedBox(
          height: 600,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: _filteredProducts.isEmpty
                ? const Center(
                    child: Text(
                      'No products found.',
                      style: TextStyle(color: AppColors.mutedText),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: _filteredProducts.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      final stock = _stockMap[product.id] ?? 0;
                      final bool inStock = stock > 0;
                      
                      return _buildProductRow(product, stock, inStock);
                    },
                  ),
          ),
        ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // RIGHT: Quotation Items (58%)
              Expanded(
                flex: 58,
                child: widget.rightPanel,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildCategoryCard(String label, {required bool isSelected, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryBlue : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primaryBlue : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.charcoal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductRow(Product product, int stock, bool inStock) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 40,
              height: 40,
              child: ProductImage(
                product: product,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.charcoal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      product.productCode,
                      style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
                    ),
                    if (product.brand.isNotEmpty && product.brand != 'Unknown') ...[
                      const SizedBox(width: 8),
                      Container(width: 4, height: 4, decoration: const BoxDecoration(color: AppColors.border, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(
                        product.brand,
                        style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Price and Stock
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'AED ${product.sellingPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.charcoal,
                ),
              ),
            ],
          ),
          
          const SizedBox(width: 16),
          
          // Add Action
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => widget.onProductsAdded([product]),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.primaryBlue.withValues(alpha: 0.5),
                  ),
                ),
                child: const Text(
                  'Add',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
