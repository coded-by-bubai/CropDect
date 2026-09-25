import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class OfflineAIService {
  static final OfflineAIService _instance = OfflineAIService._internal();
  factory OfflineAIService() => _instance;
  OfflineAIService._internal();

  Interpreter? _interpreter;
  List<String>? _labels;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      // Load the model
      _interpreter = await Interpreter.fromAsset('assets/ml/cropdect_model.tflite');
      
      // Load the labels
      final labelData = await rootBundle.loadString('assets/ml/labels.txt');
      _labels = labelData.split('\n').where((s) => s.trim().isNotEmpty).toList();
      
      _isInitialized = true;
      print('✅ Offline AI Model initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize Offline AI Model: $e');
    }
  }

  Future<String?> scanImage(String imagePath) async {
    if (!_isInitialized || _interpreter == null || _labels == null) {
      print('Offline AI not initialized yet');
      return null;
    }

    try {
      // 1. Read and decode the image
      final imageBytes = await File(imagePath).readAsBytes();
      final originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) return null;

      // 2. Resize to 224x224 (The size our model expects)
      final resizedImage = img.copyResize(originalImage, width: 224, height: 224);

      // 3. Convert image to a 3D float array [1, 224, 224, 3] and normalize to [-1, 1]
      // MobileNetV2 uses (pixel / 127.5) - 1.0
      var input = List.generate(
        1,
        (i) => List.generate(
          224,
          (y) => List.generate(
            224,
            (x) {
              final pixel = resizedImage.getPixel(x, y);
              final r = (pixel.r / 127.5) - 1.0;
              final g = (pixel.g / 127.5) - 1.0;
              final b = (pixel.b / 127.5) - 1.0;
              return [r, g, b];
            },
          ),
        ),
      );

      // 4. Create output array [1, NUM_CLASSES]
      var output = List.generate(1, (i) => List.filled(_labels!.length, 0.0));

      // 5. Run inference
      _interpreter!.run(input, output);

      // 6. Find the highest probability
      final probabilities = output[0];
      double maxProb = 0.0;
      int maxIndex = 0;
      
      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          maxIndex = i;
        }
      }

      // 7. Return the label if confident enough
      if (maxProb > 0.5) {
        return _labels![maxIndex].replaceAll('___', ' - ').replaceAll('_', ' ');
      } else {
        return 'UNKNOWN - Low Confidence (${(maxProb * 100).toStringAsFixed(1)}%)';
      }
    } catch (e) {
      print('❌ Offline AI Scan Error: $e');
      return null;
    }
  }
}
