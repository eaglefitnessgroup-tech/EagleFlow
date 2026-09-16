import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/service_locator.dart';
import '../domain/product.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/guards/admin_guard.dart';
import 'widgets/image_adjust_dialog.dart';

class AddEditProductScreen extends StatefulWidget {
  final Product? product; // null if adding
  final bool allowAuthenticatedCreate;

  const AddEditProductScreen({
    super.key,
    this.product,
    this.allowAuthenticatedCreate = false,
  });

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _InsertNewlineIntent extends Intent {
  const _InsertNewlineIntent();
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
  bool _isLoadingImage = false;
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
      if (_imageBytes == null && p.imageId != null) {
        _loadExistingImageBytes(p.imageId!);
      }
    }
  }

  Future<void> _loadExistingImageBytes(String imageId) async {
    setState(() {
      _isLoadingImage = true;
    });
    try {
      final client = ServiceLocator().supabaseService.client;
      if (client != null) {
        final downloadPath = imageId.contains('/') ? imageId : '$imageId/main.jpg';
        final bytes = await client.storage.from('product-images').download(downloadPath);
        if (mounted) {
          setState(() {
            _imageBytes = bytes;
          });
        }
      }
    } catch (e) {
      // Fallback to "Add Image" if fetching fails
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingImage = false;
        });
      }
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
      
      if (!mounted) return;
      
      final adjustedBytes = await showDialog<Uint8List>(
        context: context,
        barrierDismissible: false,
        builder: (context) => ImageAdjustDialog(imageBytes: bytes),
      );
      
      if (adjustedBytes != null) {
        setState(() {
          _imageBytes = adjustedBytes;
        });
      }
    }
  }

  Future<void> _adjustExistingImage() async {
    if (_imageBytes == null) return;
    
    final adjustedBytes = await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ImageAdjustDialog(imageBytes: _imageBytes!),
    );
    
    if (adjustedBytes != null) {
      setState(() {
        _imageBytes = adjustedBytes;
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
    );

    final controller = ServiceLocator().productMasterController;

    bool success;
    Product? savedProduct;
    if (widget.product == null) {
      final newProduct = await controller.addProduct(updatedProduct);
      success = newProduct != null;
      savedProduct = newProduct;
    } else {
      success = await controller.updateProduct(updatedProduct);
    }

    if (success) {
      if (mounted) Navigator.pop(context, savedProduct);
    } else {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = controller.error ?? 'Failed to save product';
        });
      }
    }
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: const Text(
            'Are you sure you want to delete this product? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.statusRejectedText),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final controller = ServiceLocator().productMasterController;
    final success = await controller.deleteProduct(widget.product!.id);

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product deleted successfully'),
            backgroundColor: AppColors.statusApprovedText,
          ),
        );
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = controller.error ?? 'Failed to delete product';
        });
      }
    }
  }

  Widget _buildFormRow(Widget field1, Widget field2, bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          field1,
          field2,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: field1),
        const SizedBox(width: 16),
        Expanded(child: field2),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.product == null ? 'Add Product' : 'Edit Product';
    final bool isMobile = MediaQuery.sizeOf(context).width < 600;

    final scaffold = Scaffold(
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
                    child: _isLoadingImage
                        ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primaryBlue),
                              ),
                            ),
                          )
                        : _imageBytes != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.memory(_imageBytes!, fit: BoxFit.cover),
                                  Positioned(
                                    top: 4,
                                    right: 32,
                                    child: GestureDetector(
                                      onTap: _adjustExistingImage,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.crop,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
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
                                    size: 32,
                                    color: AppColors.mutedText,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Add Image',
                                    style: TextStyle(
                                      color: AppColors.mutedText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
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
              _buildTextField(
                'Product Name *',
                _nameController,
                required: true,
              ),

              _buildFormRow(
                _buildTextField('Category', _categoryController),
                _buildTextField('Brand', _brandController),
                isMobile,
              ),

              _buildFormRow(
                _buildTextField(
                  'Selling Price *',
                  _priceController,
                  isNumber: true,
                  required: true,
                ),
                _buildTextField('Unit', _unitController),
                isMobile,
              ),

              _buildFormRow(
                _buildTextField(
                  'Opening Stock',
                  _openingStockController,
                  isNumber: true,
                  readOnly: widget.product != null,
                ),
                _buildTextField(
                  'Min Stock Level',
                  _minStockController,
                  isNumber: true,
                ),
                isMobile,
              ),

              Shortcuts(
                shortcuts: <ShortcutActivator, Intent>{
                  SingleActivator(LogicalKeyboardKey.enter, control: true): const _InsertNewlineIntent(),
                },
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    _InsertNewlineIntent: CallbackAction<_InsertNewlineIntent>(
                      onInvoke: (intent) {
                        final text = _descriptionController.text;
                        final selection = _descriptionController.selection;
                        
                        if (selection.isValid) {
                          final newText = text.replaceRange(selection.start, selection.end, '\n');
                          _descriptionController.value = TextEditingValue(
                            text: newText,
                            selection: TextSelection.collapsed(offset: selection.start + 1),
                          );
                        }
                        return null;
                      },
                    ),
                  },
                  child: _buildTextField(
                    'Description / Notes',
                    _descriptionController,
                    maxLines: 3,
                    keyboardType: TextInputType.multiline,
                  ),
                ),
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
              if (widget.product != null) ...[
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _deleteProduct,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete Product'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statusRejectedText,
                      side: const BorderSide(color: AppColors.statusRejectedText),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      );

    if (widget.allowAuthenticatedCreate && widget.product == null) {
      return scaffold;
    }

    return AdminGuard(
      child: scaffold,
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    bool required = false,
    int maxLines = 1,
    bool readOnly = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        enableInteractiveSelection: !readOnly,
        keyboardType: keyboardType ?? (isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text),
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
