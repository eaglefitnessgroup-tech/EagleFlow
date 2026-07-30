import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../domain/product.dart';
import 'widgets/details/product_image_panel.dart';
import 'widgets/details/product_info_section.dart';
import 'widgets/details/product_description_section.dart';
import 'widgets/details/product_specifications_section.dart';
import 'widgets/details/quantity_selector.dart';
import 'widgets/details/product_details_bottom_bar.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    // Extract product from arguments
    final product = ModalRoute.of(context)?.settings.arguments as Product?;

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
                  ProductImagePanel(imagePath: product.imagePath),
                  const SizedBox(height: 32),
                  ProductInfoSection(product: product),
                  const SizedBox(height: 32),
                  ProductDescriptionSection(description: product.description),
                  if (product.description != null &&
                      product.description!.isNotEmpty)
                    const SizedBox(height: 32),
                  ProductSpecificationsSection(
                    specifications: product.specifications,
                  ),
                  if (product.specifications != null &&
                      product.specifications!.isNotEmpty)
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
