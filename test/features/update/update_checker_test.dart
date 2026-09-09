import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/update/update_checker.dart';

void main() {
  group('isNewerVersion', () {
    test('returns true when the latest major is higher', () {
      expect(isNewerVersion(latest: '2.0.0', current: '1.5.3'), true);
    });

    test('returns true when the latest minor is higher', () {
      expect(isNewerVersion(latest: '1.2.0', current: '1.1.9'), true);
    });

    test('returns true when the latest patch is higher', () {
      expect(isNewerVersion(latest: '1.1.4', current: '1.1.3'), true);
    });

    test('returns false when versions are equal', () {
      expect(isNewerVersion(latest: '1.2.3', current: '1.2.3'), false);
    });

    test('returns false when the latest is older', () {
      expect(isNewerVersion(latest: '1.0.0', current: '1.2.0'), false);
    });

    test('handles a leading "v" on the latest tag', () {
      expect(isNewerVersion(latest: 'v1.3.0', current: '1.2.0'), true);
    });

    test('treats a missing component as zero', () {
      expect(isNewerVersion(latest: '1.2', current: '1.1.9'), true);
    });
  });

  group('parseLatestRelease', () {
    test('extracts the tag name and the .apk asset download URL', () {
      final release = parseLatestRelease({
        'tag_name': 'v1.1.0',
        'assets': [
          {
            'name': 'app-release.apk',
            'browser_download_url': 'https://github.com/x/y/releases/download/v1.1.0/app-release.apk',
          },
          {
            'name': 'source.zip',
            'browser_download_url':
                'https://github.com/x/y/releases/download/v1.1.0/source.zip',
          },
        ],
      });

      expect(release.version, '1.1.0');
      expect(
        release.apkDownloadUrl,
        'https://github.com/x/y/releases/download/v1.1.0/app-release.apk',
      );
    });

    test('throws when the release has no .apk asset', () {
      expect(
        () => parseLatestRelease({
          'tag_name': 'v1.1.0',
          'assets': [
            {
              'name': 'source.zip',
              'browser_download_url': 'https://example.com/source.zip',
            },
          ],
        }),
        throwsException,
      );
    });
  });
}
