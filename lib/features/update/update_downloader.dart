import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class UpdateDownloader {
  /// Downloads the APK at [url] into the app's cache directory and opens
  /// the system installer for it. Throws if the download or install-intent
  /// launch fails.
  Future<void> downloadAndInstall(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Download failed (${response.statusCode})');
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/food_diary_update.apk');
    await file.writeAsBytes(response.bodyBytes);

    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done) {
      throw Exception(result.message);
    }
  }
}
