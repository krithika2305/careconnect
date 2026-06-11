import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Result returned from the Flask AI backend.
class MriPredictionResult {
  final String label;
  final double confidence;
  final Map<String, double> allClasses;

  MriPredictionResult({
    required this.label,
    required this.confidence,
    required this.allClasses,
  });

  factory MriPredictionResult.fromJson(Map<String, dynamic> json) {
    final rawClasses = json['all_classes'] as Map<String, dynamic>? ?? {};
    return MriPredictionResult(
      label: json['prediction'] as String? ?? 'Unknown',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      allClasses: rawClasses
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
    );
  }
}

/// Sends MRI images to the CareConnect Python Flask backend for classification.
/// Replaces the deprecated on-device TFLite implementation.
class AlzheimersModelService {
  // ─── CONFIGURATION ──────────────────────────────────────────────────────────
  // Change this to your deployed Flask server URL in production.
  // For local development use http://10.0.2.2:5000 (Android emulator)
  // or http://localhost:5000 (iOS simulator / web).
  static const String _baseUrl =
      String.fromEnvironment('FLASK_API_URL', defaultValue: 'http://10.0.2.2:5000');

  static const Duration _timeout = Duration(seconds: 30);

  static const List<String> classes = [
    'Mild Demented',
    'Moderate Demented',
    'Non Demented',
    'Very Mild Demented',
  ];

  // Kept for API compatibility – nothing to load remotely.
  Future<void> loadModel() async {
    // No-op: model lives on the backend server.
  }

  // Kept for API compatibility.
  void close() {}

  /// Sends [imagePath] to the Flask /predict endpoint.
  /// Returns null if the request fails or the server is unreachable.
  Future<MriPredictionResult?> predict(String imagePath) async {
    final uri = Uri.parse('$_baseUrl/predict');
    final request = http.MultipartRequest('POST', uri);

    try {
      request.files.add(
        await http.MultipartFile.fromPath('image', imagePath),
      );

      final streamed = await request.send().timeout(_timeout);
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode == 200) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        return MriPredictionResult.fromJson(json);
      } else {
        // Parse error message if available
        String errorMsg = 'Server error ${streamed.statusCode}';
        try {
          final errorJson = jsonDecode(body) as Map<String, dynamic>;
          errorMsg = errorJson['error'] as String? ?? errorMsg;
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } on SocketException {
      throw Exception(
          'Cannot reach AI server. Ensure the Flask backend is running at $_baseUrl');
    } catch (e) {
      rethrow;
    }
  }

  /// Pings the /health endpoint; returns true if the server is reachable.
  Future<bool> isServerHealthy() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
