import 'package:flutter/material.dart';

/// Framing overlay shown on top of the camera preview.
class ScanGuide extends StatelessWidget {
  const ScanGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Align(
              alignment: Alignment.topCenter,
              child: Text(
                'Frame the entire EC 8A sheet, flat and in light',
                style: TextStyle(
                  color: Colors.white,
                  backgroundColor: Colors.black45,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
