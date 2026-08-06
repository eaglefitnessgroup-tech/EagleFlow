import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/service_locator.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/widgets/product_image.dart';
import '../domain/reservation.dart';
import 'widgets/reservation_bottom_sheet.dart';
import 'widgets/reservation_card.dart';

class ItemReservationScreen extends StatefulWidget {
  const ItemReservationScreen({super.key});

  @override
  State<ItemReservationScreen> createState() => _ItemReservationScreenState();
}

class _ItemReservationScreenState extends State<ItemReservationScreen> {
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  List<Reservation> _activeReservations = [];
  bool _isLoading = true;
  String _searchQuery = '';

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Auto-refresh every 30 seconds to update expired reservations
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadReservations();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final products = await ServiceLocator().productRepository.getAllProducts();
      final activeProducts = products.where((p) => p.isActive).toList();
      final reservations = await ServiceLocator().reservationRepository.getActiveReservations();
      
      if (mounted) {
        setState(() {
          _allProducts = activeProducts;
          _filteredProducts = activeProducts;
          _activeReservations = reservations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadReservations() async {
    try {
      final reservations = await ServiceLocator().reservationRepository.getActiveReservations();
      if (mounted) {
        setState(() {
          _activeReservations = reservations;
        });
      }
    } catch (e) {
      // Handle silently
    }
  }

  Future<void> _cancelReservation(String id) async {
    await ServiceLocator().reservationRepository.cancelReservation(id);
    await _loadReservations();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredProducts = _allProducts;
      } else {
        _filteredProducts = _allProducts.where((p) {
          return p.name.toLowerCase().contains(_searchQuery) ||
                 p.productCode.toLowerCase().contains(_searchQuery);
        }).toList();
      }
    });
  }

  void _onProductTapped(Product product) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReservationBottomSheet(product: product),
    );
    // Refresh reservations after the sheet is closed
    await _loadReservations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Item Reservation'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.charcoal,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: AppColors.border,
            height: 1.0,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildSearchField(),
                ),
                if (_filteredProducts.isEmpty)
                  SliverToBoxAdapter(child: _buildEmptyState())
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildProductCard(_filteredProducts[index]),
                          );
                        },
                        childCount: _filteredProducts.length,
                      ),
                    ),
                  ),
                if (_activeReservations.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                      child: Text(
                        'Active Reservations',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.charcoal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: ReservationCard(
                              reservation: _activeReservations[index],
                              onCancel: () => _cancelReservation(_activeReservations[index].id),
                            ),
                          );
                        },
                        childCount: _activeReservations.length,
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: TextField(
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search by Product Name or Code',
          prefixIcon: const Icon(Icons.search, color: AppColors.mutedText),
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 24.0),
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
                : 'There are no active products available.',
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 15,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  int _getReservedQuantity(String productId) {
    return _activeReservations
        .where((r) => r.productId == productId)
        .fold(0, (sum, r) => sum + r.quantity);
  }

  Widget _buildProductCard(Product product) {
    final reservedQty = _getReservedQuantity(product.id);
    final availableQty = product.openingStock - reservedQty;
    return InkWell(
      onTap: () => _onProductTapped(product),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primarySoft.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: ProductImage(
                product: product,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorIconSize: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.charcoal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (reservedQty > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Reserved',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.productCode,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.mutedText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStockPill('Physical', product.openingStock),
                      const SizedBox(width: 8),
                      _buildStockPill('Reserved', reservedQty),
                      const SizedBox(width: 8),
                      _buildStockPill('Available', availableQty),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: AppColors.mutedText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockPill(String label, int quantity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.mutedText,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$quantity',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.charcoal,
            ),
          ),
        ],
      ),
    );
  }
}
