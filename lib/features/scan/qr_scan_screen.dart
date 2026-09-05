import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import 'ec8a_parser.dart';
import 'qr_payload_parser.dart';
import 'review_screen.dart';

/// Scans the QR code printed on newer EC 8A sheets. The QR encodes the
/// results digitally - far more reliable than handwriting OCR. Payloads
/// that don't parse as results are ignored and scanning continues; the
/// agent can always fall back to photo OCR or manual entry.
class QrScanScreen extends ConsumerStatefulWidget {
  final PollingUnit pollingUnit;
  const QrScanScreen({super.key, required this.pollingUnit});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  final _controller = MobileScannerController();
  bool _handled = false;
  String? _lastReject;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || !mounted) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.trim().isEmpty) continue;
      final known =
          ref.read(partiesProvider).valueOrNull?.map((p) => p.abbr).toSet() ??
              <String>{};
      final result = parseEc8aQr(raw, known);
      if (result.rows.isEmpty) {
        // Not a results QR code - keep scanning.
        setState(() => _lastReject = raw.trim());
        continue;
      }
      _handled = true;
      _controller.stop();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReviewScreen(
            pollingUnit: widget.pollingUnit,
            parse: Ec8aParseResult(rows: result.rows),
            photoPath: null,
            sourceOverride: 'qr',
          ),
        ),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scan QR — ${widget.pollingUnit.code}')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          IgnorePointer(
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 48),
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Point at the QR code at the bottom of the EC 8A',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        backgroundColor: Colors.black45,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_lastReject != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'That QR code did not contain results - keep scanning, '
                    'or go back and use the photo scan instead.',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
