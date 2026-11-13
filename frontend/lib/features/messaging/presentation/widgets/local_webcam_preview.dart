import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Opens the device camera (front camera when available) and shows the live preview.
class TradeSquareLocalWebcam extends StatefulWidget {
  const TradeSquareLocalWebcam({super.key});

  @override
  State<TradeSquareLocalWebcam> createState() => _TradeSquareLocalWebcamState();
}

class _TradeSquareLocalWebcamState extends State<TradeSquareLocalWebcam> {
  CameraController? _controller;
  String? _error;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    if (_opening) return;
    _opening = true;
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() => _error = 'No camera found on this device.');
        return;
      }
      final camera = cameras.cast<CameraDescription?>().firstWhere(
            (item) => item!.lensDirection == CameraLensDirection.front,
            orElse: () => cameras.first,
          )!;
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Allow camera access so your video can be seen.';
      });
    } finally {
      _opening = false;
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      return ColoredBox(
        color: Colors.black,
        child: CameraPreview(controller),
      );
    }

    return ColoredBox(
      color: const Color(0xFF001A38),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.white),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Opening your camera…',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
