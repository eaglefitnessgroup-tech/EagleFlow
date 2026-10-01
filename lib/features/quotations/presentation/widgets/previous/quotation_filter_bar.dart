import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../../app/theme/app_colors.dart';

class QuotationFilterBar extends StatelessWidget {
  final String searchQuery;
  final String sortBy;
  final DateTimeRange? selectedDateRange;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onDateFilterPressed;
  final VoidCallback onDateFilterCleared;

  const QuotationFilterBar({
    super.key,
    required this.searchQuery,
    required this.sortBy,
    required this.selectedDateRange,
    required this.onSearchChanged,
    required this.onSortChanged,
    required this.onDateFilterPressed,
    required this.onDateFilterCleared,
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
              _buildSortDropdown(),
              const SizedBox(height: 12),
              _buildDateFilterControls(),
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 2, child: _buildSearchField()),
            const SizedBox(width: 16),
            Expanded(child: _buildSortDropdown()),
            const SizedBox(width: 16),
            Expanded(child: _buildDateFilterControls()),
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

  Widget _buildDateFilterControls() {
    final range = selectedDateRange;
    final label = range == null
        ? 'Date Filter'
        : '${DateFormat('dd MMM yyyy').format(range.start)} '
              '– ${DateFormat('dd MMM yyyy').format(range.end)}';
    final filterButton = OutlinedButton.icon(
      key: const Key('quotation-date-filter'),
      onPressed: onDateFilterPressed,
      icon: const Icon(Icons.calendar_today_outlined, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: BorderSide(
          color: range == null ? AppColors.border : AppColors.primaryBlue,
        ),
        foregroundColor: range == null
            ? AppColors.charcoal
            : AppColors.primaryBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: AppColors.surface,
      ),
    );

    if (range == null) return filterButton;

    return Row(
      children: [
        Expanded(child: filterButton),
        const SizedBox(width: 8),
        TextButton(
          key: const Key('quotation-date-filter-clear'),
          onPressed: onDateFilterCleared,
          child: const Text('Clear'),
        ),
      ],
    );
  }
}
