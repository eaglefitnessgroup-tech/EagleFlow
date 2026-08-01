import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import '../../../../../../app/theme/app_colors.dart';
import '../../../domain/quotation_line_item.dart';

class CustomProductForm {
  static Future<QuotationLineItem?> show(
    BuildContext context, {
    QuotationLineItem? initialItem,
  }) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return showModalBottomSheet<QuotationLineItem>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) =>
            _CustomProductFormContent(isModal: true, initialItem: initialItem),
      );
    } else {
      return showDialog<QuotationLineItem>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: _CustomProductFormContent(
            isModal: false,
            initialItem: initialItem,
          ),
        ),
      );
    }
  }
}

class _CustomProductFormContent extends StatefulWidget {
  final bool isModal;
  final QuotationLineItem? initialItem;

  const _CustomProductFormContent({required this.isModal, this.initialItem});

  @override
  State<_CustomProductFormContent> createState() =>
      _CustomProductFormContentState();
}

class _CustomProductFormContentState extends State<_CustomProductFormContent> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _qtyController;
  late TextEditingController _priceController;
  late TextEditingController _discountController;
  late TextEditingController _descController;
  late TextEditingController _codeController;
  late TextEditingController _brandController;

  Uint8List? _imageBytes;
  bool _imageRemoved = false;
  bool _isProcessingImage = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;

    _nameController = TextEditingController(text: item?.name ?? '');
    _qtyController = TextEditingController(
      text: item?.quantity.toString() ?? '1',
    );
    _priceController = TextEditingController(
      text: item?.unitPrice.toStringAsFixed(2) ?? '',
    );
    _discountController = TextEditingController(
      text: (item?.discount ?? 0.0) > 0
          ? item!.discount.toStringAsFixed(2)
          : '',
    );
    _descController = TextEditingController(text: item?.description ?? '');
    _codeController = TextEditingController(text: item?.productCode ?? '');
    _brandController = TextEditingController(text: item?.brand ?? '');

    _imageBytes = item?.imageBytes;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _descController.dispose();
    _codeController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isProcessingImage || _isSubmitting) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile == null) return;

      setState(() => _isProcessingImage = true);

      final bytes = await pickedFile.readAsBytes();
      if (bytes.lengthInBytes > 10 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image is too large (Max 10MB)')),
        );
        return;
      }

      // Process image in isolate to avoid freezing UI
      final processedBytes = await compute(_resizeImage, bytes);

      if (processedBytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to process image')),
        );
        return;
      }

      setState(() {
        _imageBytes = processedBytes;
        _imageRemoved = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    } finally {
      if (mounted) setState(() => _isProcessingImage = false);
    }
  }

  static Uint8List? _resizeImage(Uint8List bytes) {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      img.Image resized = image;
      const int maxSize = 1200;
      if (image.width > maxSize || image.height > maxSize) {
        if (image.width > image.height) {
          resized = img.copyResize(image, width: maxSize);
        } else {
          resized = img.copyResize(image, height: maxSize);
        }
      }

      // Convert to JPG to save space
      return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
    } catch (e) {
      debugPrint('Error resizing image: $e');
      return null;
    }
  }

  void _submit() {
    if (_isSubmitting || _isProcessingImage) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final name = _nameController.text.trim();
    final qty = int.tryParse(_qtyController.text) ?? 1;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final discount = double.tryParse(_discountController.text) ?? 0.0;
    final desc = _descController.text.trim();
    final code = _codeController.text.trim();
    final brand = _brandController.text.trim();

    final newItem = QuotationLineItem(
      id: widget.initialItem?.id ?? '', // Handled by controller if empty
      name: name,
      quantity: qty,
      unitPrice: price,
      discount: discount,
      description: desc.isNotEmpty ? desc : null,
      productCode: code.isNotEmpty ? code : null,
      brand: brand.isNotEmpty ? brand : '—',
      imageBytes: _imageRemoved ? null : _imageBytes,
      imagePath: _imageRemoved ? null : widget.initialItem?.imagePath,
      isCustom: true,
    );

    Navigator.of(context).pop(newItem);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.isModal ? double.infinity : 600,
      height: widget.isModal ? MediaQuery.of(context).size.height * 0.9 : 750,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: widget.isModal
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImageSection(),
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Product Name *',
                      validator: (v) {
                        final text = v?.trim() ?? '';
                        if (text.isEmpty) return 'Required';
                        if (text.length < 2) return 'Min 2 chars';
                        if (text.length > 120) return 'Max 120 chars';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _qtyController,
                            label: 'Quantity *',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (v) {
                              final text = v?.trim() ?? '';
                              if (text.isEmpty) return 'Required';
                              final num = int.tryParse(text);
                              if (num == null) return 'Invalid';
                              if (num < 1) return 'Min 1';
                              if (num > 9999) return 'Max 9999';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _priceController,
                            label: 'Unit Price *',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}'),
                              ),
                            ],
                            validator: (v) {
                              final text = v?.trim() ?? '';
                              if (text.isEmpty) return 'Required';
                              final num = double.tryParse(text);
                              if (num == null) return 'Invalid';
                              if (num < 0.01) return 'Min 0.01';
                              if (num > 99999999.99) return 'Max 99,999,999.99';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _codeController,
                            label: 'Product Code / SKU',
                            validator: (v) {
                              final text = v?.trim() ?? '';
                              if (text.length > 60) return 'Max 60 chars';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _brandController,
                            label: 'Brand',
                            validator: (v) {
                              final text = v?.trim() ?? '';
                              if (text.length > 60) return 'Max 60 chars';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _discountController,
                      label: 'Discount %',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      validator: (v) {
                        final text = v?.trim() ?? '';
                        if (text.isEmpty) return null;
                        final num = double.tryParse(text);
                        if (num == null) return 'Invalid';
                        if (num < 0 || num > 100) return '0 - 100';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _descController,
                      label: 'Description',
                      maxLines: 3,
                      validator: (v) {
                        final text = v?.trim() ?? '';
                        if (text.length > 500) return 'Max 500 chars';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    final bool hasExistingAsset =
        widget.initialItem?.imagePath != null && !_imageRemoved;
    final bool hasImage = _imageBytes != null || hasExistingAsset;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Product Image',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.charcoal,
          ),
        ),
        const SizedBox(height: 12),
        if (hasImage)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _imageBytes != null
                      ? Image.memory(_imageBytes!, fit: BoxFit.contain)
                      : Image.asset(
                          widget.initialItem!.imagePath!,
                          fit: BoxFit.contain,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isProcessingImage
                          ? null
                          : () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library, size: 18),
                      label: const Text('Replace'),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _imageBytes = null;
                          _imageRemoved = true;
                        });
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Remove'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _isProcessingImage
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.border,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: _isProcessingImage
                        ? const Center(child: CircularProgressIndicator())
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 32,
                                color: AppColors.mutedText,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Gallery',
                                style: TextStyle(
                                  color: AppColors.mutedText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              if (!kIsWeb) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: _isProcessingImage
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.border,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: _isProcessingImage
                          ? const Center(child: CircularProgressIndicator())
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt_outlined,
                                  size: 32,
                                  color: AppColors.mutedText,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Camera',
                                  style: TextStyle(
                                    color: AppColors.mutedText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        filled: true,
        fillColor: AppColors.surface,
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.initialItem == null
                ? 'Add Custom Product'
                : 'Edit Custom Product',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.charcoal,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 16),
          FilledButton(
            onPressed: _isSubmitting || _isProcessingImage ? null : _submit,
            child: Text(
              widget.initialItem == null ? 'Add Product' : 'Save Changes',
            ),
          ),
        ],
      ),
    );
  }
}
