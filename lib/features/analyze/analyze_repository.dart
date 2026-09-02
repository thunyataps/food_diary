import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/food_item.dart';

List<FoodItem> parseAnalyzeResponse(Map<String, dynamic> data) {
  final items = (data['items'] as List)
      .map((json) => FoodItem.fromGemini(json as Map<String, dynamic>))
      .toList();
  return items;
}

class AnalyzeRepository {
  AnalyzeRepository(this._client);
  final SupabaseClient _client;

  Future<List<FoodItem>> analyzePhoto({
    required Uint8List imageBytes,
    required String mimeType,
    String? note,
  }) async {
    final response = await _client.functions.invoke(
      'analyze-food',
      body: {
        'image': base64Encode(imageBytes),
        'mimeType': mimeType,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );

    if (response.status != 200) {
      final error = (response.data is Map) ? response.data['error'] : 'unknown';
      throw AnalyzeException(error?.toString() ?? 'unknown');
    }

    return parseAnalyzeResponse(response.data as Map<String, dynamic>);
  }
}

class AnalyzeException implements Exception {
  AnalyzeException(this.code);
  final String code;

  String get userMessage {
    switch (code) {
      case 'rate_limited':
        return 'High demand right now, try again shortly.';
      case 'unauthorized':
        return 'Please sign in again.';
      default:
        return 'Analysis failed, try again.';
    }
  }
}
