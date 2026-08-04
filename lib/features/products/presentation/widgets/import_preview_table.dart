import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/bulk_import_models.dart';

class ImportPreviewTable extends StatelessWidget {
  final BulkImportPreview preview;

  const ImportPreviewTable({super.key, required this.preview});

  @override
  Widget build(BuildContext context) {
    if (preview.rows.isEmpty) {
      return const Center(child: Text('No data to preview.'));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.background),
        columns: const [
          DataColumn(label: Text('Row')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Image')),
          DataColumn(label: Text('Code')),
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Price')),
          DataColumn(label: Text('Errors')),
        ],
        rows: preview.rows.map((row) {
          final p = row.product;
          final hasImage = row.imageStatus != null;
          final imageOk =
              hasImage && !row.imageStatus!.toLowerCase().contains('error');

          return DataRow(
            color: WidgetStateProperty.all(
              row.isValid ? Colors.white : Colors.red.shade50,
            ),
            cells: [
              DataCell(Text(row.rowIndex.toString())),

              // Status icon
              DataCell(
                Icon(
                  row.isValid ? Icons.check_circle : Icons.error,
                  color: row.isValid ? Colors.green : Colors.red,
                  size: 20,
                ),
              ),

              // Image status
              DataCell(
                hasImage
                    ? Tooltip(
                        message: row.imageStatus!,
                        child: Icon(
                          imageOk ? Icons.image : Icons.broken_image,
                          size: 18,
                          color: imageOk
                              ? AppColors.primaryBlue
                              : Colors.orange,
                        ),
                      )
                    : const Tooltip(
                        message: 'No image',
                        child: Icon(
                          Icons.image_not_supported,
                          size: 18,
                          color: AppColors.border,
                        ),
                      ),
              ),

              DataCell(Text(p?.productCode ?? '')),
              DataCell(Text(p?.name ?? '')),
              DataCell(
                Text(p != null ? p.sellingPrice.toStringAsFixed(2) : ''),
              ),

              // User-friendly errors (no raw exceptions)
              DataCell(
                row.errors.isEmpty
                    ? const SizedBox.shrink()
                    : Tooltip(
                        message: row.errors.join('\n'),
                        child: Text(
                          _friendlyErrors(row.errors),
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// Strips stack traces and technical prefixes from error messages.
  String _friendlyErrors(List<String> errors) {
    return errors
        .map((e) {
          final msg = e.replaceAll(RegExp(r'Exception:\s*'), '').trim();
          return msg.isEmpty ? e : msg;
        })
        .join(' · ');
  }
}
