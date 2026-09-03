import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/analyze/analyze_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('parseAnalyzeResponse maps items to FoodItem list', () {
    final data = {
      'items': [
        {
          'name': 'Rice',
          'quantity': '1 cup',
          'calories': 200,
          'protein': 4,
          'carb': 45,
          'fat': 0.5,
          'confidence': 'high',
        }
      ]
    };
    final items = parseAnalyzeResponse(data);
    expect(items.length, 1);
    expect(items.first.name, 'Rice');
    expect(items.first.confidence, 'high');
  });

  group('analyzeExceptionFrom', () {
    test('uses the Edge Function error code from the JSON body', () {
      final e = analyzeExceptionFrom(const FunctionsHttpException(
        status: 429,
        details: {'error': 'rate_limited'},
      ));
      expect(e.code, 'rate_limited');
      expect(e.userMessage, 'High demand right now, try again shortly.');
    });

    test('maps the 401 unauthorized body to the sign-in message', () {
      final e = analyzeExceptionFrom(const FunctionsHttpException(
        status: 401,
        details: {'error': 'unauthorized'},
      ));
      expect(e.code, 'unauthorized');
      expect(e.userMessage, 'Please sign in again.');
    });

    test('falls back to the HTTP status when the body is not the {error:...} shape', () {
      final rateLimited = analyzeExceptionFrom(
        const FunctionsHttpException(status: 429, details: 'Too Many Requests'),
      );
      expect(rateLimited.code, 'rate_limited');
      expect(rateLimited.userMessage, 'High demand right now, try again shortly.');

      final unauthorized = analyzeExceptionFrom(
        const FunctionsHttpException(status: 401, details: ''),
      );
      expect(unauthorized.code, 'unauthorized');
      expect(unauthorized.userMessage, 'Please sign in again.');
    });

    test('unrecognised failures get the generic analysis-failed message', () {
      final e = analyzeExceptionFrom(const FunctionsHttpException(
        status: 502,
        details: {'error': 'analysis_failed'},
      ));
      expect(e.code, 'analysis_failed');
      expect(e.userMessage, 'Analysis failed, try again.');

      final relay = analyzeExceptionFrom(
        const FunctionsRelayException(status: 500, details: '<html>bad gateway</html>'),
      );
      expect(relay.code, 'unknown');
      expect(relay.userMessage, 'Analysis failed, try again.');
    });
  });
}
