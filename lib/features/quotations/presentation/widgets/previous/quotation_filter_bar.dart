import 'package:flutter/material.dart';
import '../../../../../../app/theme/app_colors.dart';
import '../../../domain/quotation_status.dart';

class QuotationFilterBar extends StatelessWidget {
  final String searchQuery;
  final QuotationStatus? selectedStatus;
  final String sortBy;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<QuotationStatus?> onStatusChanged;
  final ValueChanged<String> onSortChanged;

  const QuotationFilterBar({
    super.key,
    required this.searchQuery,
    required this.selectedStatus,
    required this.sortBy,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearchField(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildStatusDropdown()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSortDropdown()),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 2, child: _buildSearchField()),
            const SizedBox(width: 16),
            Expanded(child: _buildStatusDropdown()),
            const SizedBox(width: 16),
            Expanded(child: _buildSortDropdown()),
            const SizedBox(width: 16),
            _buildDateFilterBtn(),
          ],
        );
      },
    );
  }

  Widget _buildSearchField() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search quotations...',
        prefixIcon: const Icon(Icons.search, color: AppColors.mutedText),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      onChanged: onSearchChanged,
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<QuotationStatus?>(
          value: selectedStatus,
          isExpanded: true,
          hint: const Text('All Status'),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.mutedText,
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Status')),
            ...QuotationStatus.values.map(
              (status) => DropdownMenuItem(
                value: status,
                child: Text(status.displayName),
              ),
            ),
          ],
          onChanged: onStatusChanged,
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    final sortOptions = ['Newest', 'Oldest', 'Highest Amount', 'Lowest Amount'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: sortBy,
          isExpanded: true,
          icon: const Icon(Icons.sort, color: AppColors.mutedText),
          items: sortOptions.map((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
          onChanged: (val) {
            if (val != null) onSortChanged(val);
          },
        ),
      ),
    );
  }

  Widget _buildDateFilterBtn() {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.calendar_today_outlined, size: 18),
      label: const Text('Date Filter'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        side: const BorderSide(color: AppColors.border),
        foregroundColor: AppColors.charcoal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: AppColors.surface,
      ),
    );
  }
}
