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
  late final TextEditingController _companyController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _projectController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _companyController = TextEditingController(text: widget.initialCompany);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _emailController = TextEditingController(text: widget.initialEmail);
    _projectController = TextEditingController(
      text: widget.initialProjectLocation,
    );
  }

  @override
  void didUpdateWidget(CustomerInformationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialName != widget.initialName &&
        _nameController.text != widget.initialName) {
      _nameController.text = widget.initialName;
    }
    if (oldWidget.initialCompany != widget.initialCompany &&
        _companyController.text != widget.initialCompany) {
      _companyController.text = widget.initialCompany;
    }
    if (oldWidget.initialPhone != widget.initialPhone &&
        _phoneController.text != widget.initialPhone) {
      _phoneController.text = widget.initialPhone;
    }
    if (oldWidget.initialEmail != widget.initialEmail &&
        _emailController.text != widget.initialEmail) {
      _emailController.text = widget.initialEmail;
    }
    if (oldWidget.initialProjectLocation != widget.initialProjectLocation &&
        _projectController.text != widget.initialProjectLocation) {
      _projectController.text = widget.initialProjectLocation;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _projectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return _buildCard(
          isMobile,
          title: isMobile ? 'Customer' : 'Customer Information',
          child: Column(
            children: [
              if (isMobile) ...[
                SizedBox(
                  width: double.infinity,
                  child: _buildTextField(
                    'Customer Name',
                    _nameController,
                    widget.onNameChanged,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: _buildTextField(
                    'Company',
                    _companyController,
                    widget.onCompanyChanged,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: _buildTextField(
                    'Phone',
                    _phoneController,
                    widget.onPhoneChanged,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: _buildTextField(
                    'Email',
                    _emailController,
                    widget.onEmailChanged,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: _buildTextField(
                    'Project / Location',
                    _projectController,
                    widget.onProjectLocationChanged,
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        'Customer Name',
                        _nameController,
                        widget.onNameChanged,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        'Company',
                        _companyController,
                        widget.onCompanyChanged,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        'Phone',
                        _phoneController,
                        widget.onPhoneChanged,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        'Email',
                        _emailController,
                        widget.onEmailChanged,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Project / Location',
                  _projectController,
                  widget.onProjectLocationChanged,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard(
    bool isMobile, {
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, [
    ValueChanged<String>? onChanged,
  ]) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.mutedText),
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
        filled: true,
        fillColor: AppColors.surface,
      ),
    );
  }
}
