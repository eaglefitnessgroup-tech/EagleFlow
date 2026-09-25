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
  double _fitScale = 1.0;
  double _minScale = 1.0;
  double _maxScale = 3.0;
  double _currentScale = 1.0;

  double get _viewportSize {
    if (!mounted) return 300.0;
    final screenWidth = MediaQuery.sizeOf(context).width;
    return math.min(300.0, math.max(220.0, screenWidth - 64));
  }

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

    final vSize = _viewportSize;
    final scaleX = vSize / w;
    final scaleY = vSize / h;
    _fitScale = math.max(scaleX, scaleY);
    _minScale = imageAdjustMinimumScale(_fitScale);
    _maxScale = _fitScale * 4.0;

    final scaledW = w * _fitScale;
    final scaledH = h * _fitScale;

    final dx = (vSize - scaledW) / 2;
    final dy = (vSize - scaledH) / 2;

    _transformationController.value = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(_fitScale);

    _currentScale = _fitScale;
  }

  Future<void> _applyCrop() async {
    if (_decodedImage == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final matrix = _transformationController.value;
      final vSize = _viewportSize;
      final translation = matrix.getTranslation();
      final outputSize = math.max(1, (vSize / _fitScale).round());

      final adjustedBytes = await compute(renderAdjustedProductImage, {
        'bytes': widget.imageBytes,
        'viewportSize': vSize,
        'outputSize': outputSize,
        'scale': matrix.getMaxScaleOnAxis(),
        'offsetX': translation.x,
        'offsetY': translation.y,
      });

      if (mounted) {
        Navigator.pop(context, adjustedBytes);
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

    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final scaleFactor = value / currentScale;

    final vSize = _viewportSize;
    final center = Offset(vSize / 2, vSize / 2);

    final matrix = _transformationController.value.clone();
    matrix.translate(center.dx, center.dy);
    matrix.scale(scaleFactor);
    matrix.translate(-center.dx, -center.dy);

    _transformationController.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bool isMobile = size.width < 600;
    final vSize = _viewportSize;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Container(
        width: isMobile ? double.infinity : 400,
        padding: EdgeInsets.all(isMobile ? 16 : 24),
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
              SizedBox(
                width: vSize,
                height: vSize,
                child: const Center(child: CircularProgressIndicator()),
              )
            else
              Column(
                children: [
                  Container(
                    key: const Key('image_adjust_canvas'),
                    width: vSize,
                    height: vSize,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border, width: 2),
                      color: Colors.white,
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      minScale: _minScale,
                      maxScale: _maxScale,
                      constrained: false,
                      boundaryMargin: const EdgeInsets.all(double.infinity),
                      child: SizedBox(
                        width: _decodedImage!.width.toDouble(),
                        height: _decodedImage!.height.toDouble(),
                        child: Image.memory(
                          widget.imageBytes,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.zoom_out,
                        size: 20,
                        color: AppColors.mutedText,
                      ),
                      Expanded(
                        child: Slider(
                          key: const Key('image_adjust_zoom_slider'),
                          value: _currentScale.clamp(_minScale, _maxScale),
                          min: _minScale,
                          max: _maxScale,
                          activeColor: AppColors.primaryBlue,
                          onChanged: _onSliderChanged,
                        ),
                      ),
                      const Icon(
                        Icons.zoom_in,
                        size: 20,
                        color: AppColors.mutedText,
                      ),
                    ],
                  ),
                ],
              ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _isProcessing
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                Row(
                  children: [
                    OutlinedButton(
                      key: const Key('image_adjust_reset'),
                      onPressed: _isProcessing || _decodedImage == null
                          ? null
                          : _resetTransform,
                      child: const Text('Reset'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isProcessing || _decodedImage == null
                          ? null
                          : _applyCrop,
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

@visibleForTesting
double imageAdjustMinimumScale(double fitScale) => fitScale * 0.45;

@visibleForTesting
Future<Uint8List> renderAdjustedProductImage(Map<String, dynamic> args) async {
  final bytes = args['bytes'] as Uint8List;
  final viewportSize = args['viewportSize'] as double;
  final outputSize = args['outputSize'] as int;
  final scale = args['scale'] as double;
  final offsetX = args['offsetX'] as double;
  final offsetY = args['offsetY'] as double;

  final originalImage = img.decodeImage(bytes);
  if (originalImage == null) {
    throw Exception('Could not decode image in isolate');
  }

  final canvas = img.Image(width: outputSize, height: outputSize);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

  final outputFactor = outputSize / viewportSize;
  final renderedWidth = math.max(
    1,
    (originalImage.width * scale * outputFactor).round(),
  );
  final renderedImage = img.copyResize(
    originalImage,
    width: renderedWidth,
    interpolation: img.Interpolation.linear,
  );

  img.compositeImage(
    canvas,
    renderedImage,
    dstX: (offsetX * outputFactor).round(),
    dstY: (offsetY * outputFactor).round(),
  );

  return Uint8List.fromList(img.encodeJpg(canvas, quality: 85));
}
