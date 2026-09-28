import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Handles OCR text extraction (UC-05 Extract Text) using Google ML Kit.
/// Called after a note image is captured or uploaded (UC-04/UC-06).
class OcrService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> extractTextFromImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final RecognizedText recognizedText =
        await _recognizer.processImage(inputImage);
    return recognizedText.text;
  }

  void dispose() {
    _recognizer.close();
  }
}
