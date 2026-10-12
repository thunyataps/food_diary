import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/muscles/body_viewer.dart';

void main() {
  test('parses every message type', () {
    expect(parseViewerMessage({'type': 'ready'}), isA<ViewerReady>());
    expect(
      parseViewerMessage({'type': 'muscleTapped', 'id': 'soleus'}),
      isA<MuscleTapped>().having((e) => e.muscleId, 'muscleId', 'soleus'),
    );
    expect(parseViewerMessage({'type': 'backgroundTapped'}), isA<BackgroundTapped>());
    expect(
      parseViewerMessage({'type': 'error', 'message': 'boom'}),
      isA<ViewerFailed>().having((e) => e.message, 'message', 'boom'),
    );
  });

  test('ignores malformed messages', () {
    expect(parseViewerMessage(null), isNull);
    expect(parseViewerMessage('ready'), isNull);
    expect(parseViewerMessage({'type': 'muscleTapped'}), isNull);
    expect(parseViewerMessage({'type': 'muscleTapped', 'id': 3}), isNull);
    expect(parseViewerMessage({'type': 'unknown'}), isNull);
  });

  test('error without message still fails the viewer', () {
    expect(
      parseViewerMessage({'type': 'error'}),
      isA<ViewerFailed>().having((e) => e.message, 'message', 'unknown error'),
    );
  });
}
