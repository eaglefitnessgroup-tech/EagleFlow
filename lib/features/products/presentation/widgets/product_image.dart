import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/service_locator.dart';
import '../../domain/product.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductImage extends StatefulWidget {
  final Product product;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double errorIconSize;
  final SupabaseClient? testClient;

  const ProductImage({
    super.key,
    required this.product,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorIconSize = 24.0,
    this.testClient,
  });

  static final Map<String, Uint8List> _imageCache = {};

  static Future<void> precacheImage({
    String? imageId,
    Uint8List? imageBytes,
    SupabaseClient? testClient,
  }) async {
    // Already have bytes?
    if (imageBytes != null && imageBytes.isNotEmpty) {
      return;
    }

    // No image ID?
    if (imageId == null || imageId.isEmpty) {
      return;
    }

    // Already cached?
    if (_imageCache.containsKey(imageId)) {
      return;
    }

    // Download and cache
    try {
      final client = testClient ?? ServiceLocator().supabaseService.client;
      if (client != null) {
        final downloadPath =
            imageId.contains('/') ? imageId : '$imageId/main.jpg';
        final bytes = await client.storage
            .from('product-images')
            .download(downloadPath);
        _imageCache[imageId] = bytes;
      }
    } catch (_) {
      // Ignore errors silently for precache, it will fall back to error widget when building
    }
  }

  @override
  State<ProductImage> createState() => _ProductImageState();
}

class _ProductImageState extends State<ProductImage> {
  bool _isLoading = false;
  bool _hasError = false;
  Uint8List? _downloadedBytes;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant ProductImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id ||
        oldWidget.product.imageId != widget.product.imageId ||
        oldWidget.product.imageBytes != widget.product.imageBytes) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    // 1. Memory bytes take precedence
    if (widget.product.imageBytes != null &&
        widget.product.imageBytes!.isNotEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = false;
        _downloadedBytes = null;
      });
      return;
    }

    // 2. No image ID -> Show placeholder
    if (widget.product.imageId == null || widget.product.imageId!.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = false;
        _downloadedBytes = null;
      });
      return;
    }

    // 3. Check memory cache
    final imageId = widget.product.imageId!;
    if (ProductImage._imageCache.containsKey(imageId)) {
      setState(() {
        _isLoading = false;
        _hasError = false;
        _downloadedBytes = ProductImage._imageCache[imageId];
      });
      return;
    }

    // 4. Download from Supabase
    setState(() {
      _isLoading = true;
      _hasError = false;
      _downloadedBytes = null;
    });

    try {
      final client =
          widget.testClient ?? ServiceLocator().supabaseService.client;
      if (client == null) {
        throw Exception('Supabase client not available');
      }

      final downloadPath =
          imageId.contains('/') ? imageId : '$imageId/main.jpg';
      final bytes = await client.storage
          .from('product-images')
          .download(downloadPath);

      if (mounted) {
        ProductImage._imageCache[imageId] = bytes;
        setState(() {
          _downloadedBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Memory override (from file picker or newly saved)
    if (widget.product.imageBytes != null &&
        widget.product.imageBytes!.isNotEmpty) {
      return Image.memory(
        widget.product.imageBytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: _buildErrorWidget,
      );
    }

    // Loading state
    if (_isLoading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
          ),
        ),
      );
    }

    // Downloaded from Supabase
    if (_downloadedBytes != null) {
      return Image.memory(
        _downloadedBytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: _buildErrorWidget,
      );
    }

    // Error state
    if (_hasError) {
      return _buildPlaceholder(Icons.broken_image_outlined);
    }

    // Fallback placeholder (no image ID)
    return _buildPlaceholder(Icons.image_outlined);
  }

  Widget _buildErrorWidget(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    return _buildPlaceholder(Icons.inventory_2_outlined);
  }

  Widget _buildPlaceholder(IconData iconData) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: AppColors.primarySoft.withValues(alpha: 0.3),
      child: Center(
        child: Icon(
          iconData,
          size: widget.errorIconSize,
          color: AppColors.mutedText,
        ),
      ),
    );
  }
}
