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

/// Maps the [FunctionException] that `functions.invoke` throws on a non-2xx
/// response onto an [AnalyzeException] carrying the Edge Function's error code.
///
/// `analyze-food` answers errors with a JSON body `{"error": "<code>"}`, which
/// arrives here as [FunctionException.details]. When the body isn't that shape
/// (a gateway/relay error page, an empty body, non-JSON text) the HTTP status
/// is used to pick the closest code so the user still gets a useful message.
AnalyzeException analyzeExceptionFrom(FunctionException e) {
  final details = e.details;
  final code = (details is Map) ? details['error'] : null;
  if (code != null) return AnalyzeException(code.toString());

  return AnalyzeException(switch (e.status) {
    429 => 'rate_limited',
    401 || 403 => 'unauthorized',
    _ => 'unknown',
  });
}

class AnalyzeRepository {
  AnalyzeRepository(this._client);
  final SupabaseClient _client;

  Future<List<FoodItem>> analyzePhoto({
    required Uint8List imageBytes,
    required String mimeType,
    String? note,
  }) async {
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'analyze-food',
        body: {
          'image': base64Encode(imageBytes),
          'mimeType': mimeType,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );
    } on FunctionsFetchException {
      // The request never reached the function (no network / transport
      // failure). Let it through so the UI shows its connectivity message.
      rethrow;
    } on FunctionException catch (e) {
      // Any non-2xx response — invoke throws rather than returning a
      // FunctionResponse with a non-200 status.
      throw analyzeExceptionFrom(e);
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
