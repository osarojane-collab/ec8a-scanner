import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'ec8a_parser.dart';

/// Runs on-device ML Kit OCR over an EC 8A photo (free, works offline)
/// and parses the text into structured per-party votes.
Future<Ec8aParseResult> runEc8aOcr(
  String imagePath,
  Set<String> knownAbbrs,
) async {
  final input = InputImage.fromFilePath(imagePath);
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(input);
    return parseEc8aText(result.text, knownAbbrs);
  } finally {
    recognizer.close();
  }
}
