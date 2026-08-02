import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/service_locator.dart';
import '../domain/product.dart';
import 'package:image_picker/image_picker.dart';

class AddEditProductScreen extends StatefulWidget {
  final Product? product; // null if adding

  const AddEditProductScreen({super.key, this.product});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _codeController;
  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _categoryController;
  late TextEditingController _priceController;
  late TextEditingController _unitController;
  late TextEditingController _openingStockController;
  late TextEditingController _minStockController;
  late TextEditingController _descriptionController;

  bool _isVatApplicable = true;
  bool _isActive = true;
  Uint8List? _imageBytes;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _codeController = TextEditingController(text: p?.productCode ?? '');
    _nameController = TextEditingController(text: p?.name ?? '');
    _brandController = TextEditingController(text: p?.brand ?? '');
    _categoryController = TextEditingController(text: p?.category ?? '');
    _priceController = TextEditingController(
      text: p?.sellingPrice.toString() ?? '',
    );
    _unitController = TextEditingController(text: p?.unit ?? 'Nos');
    _openingStockController = TextEditingController(
      text: p?.openingStock.toString() ?? '0',
    );
    _minStockController = TextEditingController(
      text: p?.minStockLevel.toString() ?? '5',
    );
    _descriptionController = TextEditingController(text: p?.description ?? '');

    if (p != null) {
      _isVatApplicable = p.isVatApplicable;
      _isActive = p.isActive;
      // Image would be passed or we need to load it
      _imageBytes = p.imageBytes;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _brandController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _unitController.dispose();
    _openingStockController.dispose();
    _minStockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile != null) {
      final bytes = await xfile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  void _removeImage() {
    setState(() {
      _imageBytes = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final p =
        widget.product ??
        Product(
          id: '',
          name: '',
          brand: '',
          productCode: '',
          category: '',
          sellingPrice: 0.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    final updatedProduct = p.copyWith(
      productCode: _codeController.text.trim(),
      name: _nameController.text.trim(),
      brand: _brandController.text.trim(),
      category: _categoryController.text.trim(),
      sellingPrice: double.tryParse(_priceController.text) ?? 0.0,
      unit: _unitController.text.trim(),
      openingStock: int.tryParse(_openingStockController.text) ?? 0,
      minStockLevel: int.tryParse(_minStockController.text) ?? 0,
      description: _descriptionController.text.trim(),
      isVatApplicable: _isVatApplicable,
      isActive: _isActive,
      imageBytes: _imageBytes,
      // If we removed the image, we should probably clear the imageId, but copyWith doesn't allow setting null easily if it expects non-null.
      // We will handle it in the repository.
    );

    final controller = ServiceLocator().productMasterController;

    bool success;
    if (widget.product == null) {
      final newProduct = await controller.addProduct(updatedProduct);
      success = newProduct != null;
    } else {
      success = await controller.updateProduct(updatedProduct);
    }

    if (success) {
      if (mounted) Navigator.pop(context);
    } else {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = controller.error ?? 'Failed to save product';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.product == null ? 'Add Product' : 'Edit Product';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.charcoal,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.charcoal),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 20.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            // Image Picker
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _imageBytes != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(_imageBytes!, fit: BoxFit.cover),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: _removeImage,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              color: AppColors.mutedText,
                              size: 32,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Add Image',
                              style: TextStyle(
                                color: AppColors.mutedText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            _buildTextField(
              'Product Code / SKU *',
              _codeController,
              required: true,
            ),
            _buildTextField('Product Name *', _nameController, required: true),

            Row(
              children: [
                Expanded(
                  child: _buildTextField('Category', _categoryController),
                ),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField('Brand', _brandController)),
              ],
            ),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    'Selling Price *',
                    _priceController,
                    isNumber: true,
                    required: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField('Unit', _unitController)),
              ],
            ),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    'Opening Stock',
                    _openingStockController,
                    isNumber: true,
                    readOnly: widget.product != null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    'Min Stock Level',
                    _minStockController,
                    isNumber: true,
                  ),
                ),
              ],
            ),

            _buildTextField(
              'Description / Notes',
              _descriptionController,
              maxLines: 3,
            ),

            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('VAT Applicable'),
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.primaryBlue,
              value: _isVatApplicable,
              onChanged: (val) => setState(() => _isVatApplicable = val),
            ),
            SwitchListTile(
              title: const Text('Active Product'),
              subtitle: const Text(
                'Inactive products cannot be added to new quotations',
              ),
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.primaryBlue,
              value: _isActive,
              onChanged: (val) => setState(() => _isActive = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    bool required = false,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        enableInteractiveSelection: !readOnly,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          filled: readOnly,
          fillColor: readOnly ? Colors.grey.shade100 : null,
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.mutedText),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryBlue),
          ),
        ),
        validator: required
            ? (val) {
                if (val == null || val.trim().isEmpty) return 'Required';
                return null;
              }
            : null,
      ),
    );
  }
}
