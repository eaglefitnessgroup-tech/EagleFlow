// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../../../../app/theme/app_colors.dart';

class ImageAdjustDialog extends StatefulWidget {
  final Uint8List imageBytes;

  const ImageAdjustDialog({super.key, required this.imageBytes});

  @override
  State<ImageAdjustDialog> createState() => _ImageAdjustDialogState();
}

class _ImageAdjustDialogState extends State<ImageAdjustDialog> {
  ui.Image? _decodedImage;
  bool _isProcessing = false;
  String? _error;

  late TransformationController _transformationController;
  final double _viewportSize = 300.0;
  double _minScale = 1.0;
  double _maxScale = 3.0;
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformChanged);
    _initImage();
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    setState(() {
      _currentScale = _transformationController.value.getMaxScaleOnAxis();
    });
  }

  Future<void> _initImage() async {
    try {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(widget.imageBytes, (image) {
        completer.complete(image);
      });
      final image = await completer.future;

      if (!mounted) return;

      setState(() {
        _decodedImage = image;
      });

      _resetTransform();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load image for adjustment.';
      });
    }
  }

  void _resetTransform() {
    if (_decodedImage == null) return;
    
    final w = _decodedImage!.width.toDouble();
    final h = _decodedImage!.height.toDouble();

    // The scale needed to exactly cover the viewport
    final scaleX = _viewportSize / w;
    final scaleY = _viewportSize / h;
    _minScale = math.max(scaleX, scaleY);
    _maxScale = _minScale * 4.0; // Allow 4x zoom from min

    // Calculate center translation
    final scaledW = w * _minScale;
    final scaledH = h * _minScale;
    
    final dx = (_viewportSize - scaledW) / 2;
    final dy = (_viewportSize - scaledH) / 2;

    _transformationController.value = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(_minScale);
      
    _currentScale = _minScale;
  }

  Future<void> _applyCrop() async {
    if (_decodedImage == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final matrix = _transformationController.value;
      final inverse = Matrix4.inverted(matrix);

      // Map viewport coordinates to image pixel coordinates
      final topLeft = MatrixUtils.transformPoint(inverse, const Offset(0, 0));
      final bottomRight = MatrixUtils.transformPoint(inverse, Offset(_viewportSize, _viewportSize));

      int x = topLeft.dx.round();
      int y = topLeft.dy.round();
      int width = (bottomRight.dx - topLeft.dx).round();
      int height = (bottomRight.dy - topLeft.dy).round();

      // Ensure square and within bounds
      if (width > height) {
        width = height;
      } else {
        height = width;
      }

      x = x.clamp(0, _decodedImage!.width - 1);
      y = y.clamp(0, _decodedImage!.height - 1);
      
      if (x + width > _decodedImage!.width) width = _decodedImage!.width - x;
      if (y + height > _decodedImage!.height) height = _decodedImage!.height - y;
      
      // Keep it strictly square safely
      final size = math.min(width, height);

      // Use compute to perform the heavy image cropping in a background isolate
      final croppedBytes = await compute(_cropImageTask, {
        'bytes': widget.imageBytes,
        'x': x,
        'y': y,
        'size': size,
      });

      if (mounted) {
        Navigator.pop(context, croppedBytes);
      }
    } catch (e) {
      debugPrint('Crop error: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply crop: $e'),
            backgroundColor: AppColors.statusRejectedText,
          ),
        );
      }
    }
  }

  void _onSliderChanged(double value) {
    if (_decodedImage == null) return;
    
    // Calculate how much we need to scale relative to the current scale
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final scaleFactor = value / currentScale;

    // We want to scale around the center of the viewport
    final center = const Offset(150.0, 150.0); // _viewportSize / 2
    
    final matrix = _transformationController.value.clone();
    // Translate to center, scale, translate back
    matrix.translate(center.dx, center.dy);
    matrix.scale(scaleFactor);
    matrix.translate(-center.dx, -center.dy);
    
    _transformationController.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Adjust Image',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Drag to pan and use the slider to zoom.',
              style: TextStyle(color: AppColors.mutedText, fontSize: 13),
            ),
            const SizedBox(height: 24),
            
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red))
            else if (_decodedImage == null)
              const SizedBox(
                width: 300,
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Column(
                children: [
                  Container(
                    width: _viewportSize,
                    height: _viewportSize,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border, width: 2),
                      color: Colors.grey.shade100,
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      minScale: _minScale,
                      maxScale: _maxScale,
                      constrained: false, // Important to allow child to be original size
                      boundaryMargin: const EdgeInsets.all(double.infinity), // Let users pan freely, math handles bounds
                      child: SizedBox(
                        width: _decodedImage!.width.toDouble(),
                        height: _decodedImage!.height.toDouble(),
                        child: Image.memory(
                          widget.imageBytes,
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.zoom_out, size: 20, color: AppColors.mutedText),
                      Expanded(
                        child: Slider(
                          value: _currentScale.clamp(_minScale, _maxScale),
                          min: _minScale,
                          max: _maxScale,
                          activeColor: AppColors.primaryBlue,
                          onChanged: _onSliderChanged,
                        ),
                      ),
                      const Icon(Icons.zoom_in, size: 20, color: AppColors.mutedText),
                    ],
                  ),
                ],
              ),
            
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _isProcessing ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _isProcessing || _decodedImage == null ? null : _resetTransform,
                      child: const Text('Reset'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isProcessing || _decodedImage == null ? null : _applyCrop,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Background isolate task for cropping
Future<Uint8List> _cropImageTask(Map<String, dynamic> args) async {
  final bytes = args['bytes'] as Uint8List;
  final x = args['x'] as int;
  final y = args['y'] as int;
  final size = args['size'] as int;

  // Decode the image synchronously inside the isolate
  final originalImage = img.decodeImage(bytes);
  if (originalImage == null) throw Exception('Could not decode image in isolate');

  // Perform crop
  final cropped = img.copyCrop(originalImage, x: x, y: y, width: size, height: size);

  // Encode back to JPG (with sensible quality of 85)
  return Uint8List.fromList(img.encodeJpg(cropped, quality: 85));
}
