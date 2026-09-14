import 'package:flutter/material.dart';
import '../../../../../../app/theme/app_colors.dart';

class CustomerInformationCard extends StatefulWidget {
  final String initialName;
  final String initialCompany;
  final String initialPhone;
  final String initialEmail;
  final String initialProjectLocation;
  final ValueChanged<String>? onNameChanged;
  final ValueChanged<String>? onCompanyChanged;
  final ValueChanged<String>? onPhoneChanged;
  final ValueChanged<String>? onEmailChanged;
  final ValueChanged<String>? onProjectLocationChanged;

  const CustomerInformationCard({
    super.key,
    this.initialName = '',
    this.initialCompany = '',
    this.initialPhone = '',
    this.initialEmail = '',
    this.initialProjectLocation = '',
    this.onNameChanged,
    this.onCompanyChanged,
    this.onPhoneChanged,
    this.onEmailChanged,
    this.onProjectLocationChanged,
  });

  @override
  State<CustomerInformationCard> createState() =>
      _CustomerInformationCardState();
}

class _CustomerInformationCardState extends State<CustomerInformationCard> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _addressController = TextEditingController(text: widget.initialProjectLocation);
  }

  @override
  void didUpdateWidget(CustomerInformationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialName != widget.initialName &&
        _nameController.text != widget.initialName) {
      _nameController.text = widget.initialName;
    }
    if (oldWidget.initialPhone != widget.initialPhone &&
        _phoneController.text != widget.initialPhone) {
      _phoneController.text = widget.initialPhone;
    }
    if (oldWidget.initialProjectLocation != widget.initialProjectLocation &&
        _addressController.text != widget.initialProjectLocation) {
      _addressController.text = widget.initialProjectLocation;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_outline, color: AppColors.charcoal, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Customer Information',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {},
                child: const Row(
                  children: [
                    Icon(Icons.add, color: AppColors.primaryBlue, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'New Customer',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Customer Field
          RichText(
            text: const TextSpan(
              text: 'Customer ',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.charcoal),
              children: [
                TextSpan(text: '*', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _nameController,
            onChanged: widget.onNameChanged,
            decoration: InputDecoration(
              hintText: 'Search or select customer...',
              hintStyle: const TextStyle(color: AppColors.mutedText, fontSize: 13),
              suffixIcon: const Icon(Icons.search, color: AppColors.mutedText, size: 18),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.primaryBlue),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildField(
                  label: 'Phone',
                  controller: _phoneController,
                  onChanged: widget.onPhoneChanged,
                  hintText: 'Enter phone...',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildField(
                  label: 'Project / Location',
                  controller: _addressController,
                  onChanged: widget.onProjectLocationChanged,
                  hintText: 'Enter project / location...',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    ValueChanged<String>? onChanged,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.charcoal),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: AppColors.mutedText, fontSize: 13),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.primaryBlue),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          style: const TextStyle(fontSize: 13, color: AppColors.charcoal),
        ),
      ],
    );
  }
}
