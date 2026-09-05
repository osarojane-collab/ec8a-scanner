import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import 'ec8a_parser.dart';
import 'ocr_service.dart';
import 'qr_scan_screen.dart';
import 'review_screen.dart';
import 'scan_guide.dart';

/// Camera capture with an EC 8A framing guide. On capture: on-device ML Kit
/// OCR -> parsed per-party votes -> review screen. "Enter manually" skips OCR.
class CaptureScreen extends ConsumerStatefulWidget {
  final PollingUnit pollingUnit;
  final bool alreadyRecorded;
  const CaptureScreen({
    super.key,
    required this.pollingUnit,
    this.alreadyRecorded = false,
  });

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  CameraController? _controller;
  bool _ready = false;
  bool _processing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        setState(() => _error = 'No camera available on this device.');
        return;
      }
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _ready = true;
      });
    } catch (e) {
      setState(() => _error = 'Camera failed to start: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !_ready || _processing) return;
    setState(() => _processing = true);
    try {
      final file = await controller.takePicture();
      final known =
          ref.read(partiesProvider).valueOrNull?.map((p) => p.abbr).toSet() ??
              <String>{};
      final parse = await runEc8aOcr(file.path, known);
      if (!mounted) return;
      _openReview(parse, file.path);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Capture failed: $e';
          _processing = false;
        });
      }
    }
  }

  void _openReview(Ec8aParseResult parse, String? photoPath) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          pollingUnit: widget.pollingUnit,
          parse: parse,
          photoPath: photoPath,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pu = widget.pollingUnit;
    return Scaffold(
      appBar: AppBar(title: Text('Scan ${pu.code}')),
      body: Column(
        children: [
          if (widget.alreadyRecorded)
            Material(
              color: Colors.deepOrange.shade100,
              child: const ListTile(
                dense: true,
                leading: Icon(Icons.warning_amber_rounded),
                title: Text(
                  'Results for this polling unit were already recorded. '
                  'A new entry is kept as history; the tally uses the latest.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_ready)
                  CameraPreview(_controller!)
                else if (_error != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, textAlign: TextAlign.center),
                    ),
                  )
                else
                  const Center(child: CircularProgressIndicator()),
                const ScanGuide(),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _processing
                              ? null
                              : () => _openReview(
                                  const Ec8aParseResult(rows: []), null),
                          child: const Text('Enter manually'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _processing ? null : _capture,
                          icon: _processing
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.camera_alt),
                          label: const Text('Scan form'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                onPressed: _processing
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                QrScanScreen(pollingUnit: widget.pollingUnit),
                          ),
                        ),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR code instead (newer forms)'),
              ),
                  ],
                ),
              ),
          ),
        ],
      ),
    );
  }
}
