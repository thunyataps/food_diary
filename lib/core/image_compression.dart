import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

typedef CompressFn = Future<Uint8List?> Function(
    String path, int minWidth, int minHeight, int quality);

class ImageCompressionResult {
  ImageCompressionResult(this.bytes, this.mimeType);
  final Uint8List bytes;
  final String mimeType;
}

class ImageCompressor {
  ImageCompressor({CompressFn? compressFn}) : _compressFn = compressFn ?? _defaultCompress;

  final CompressFn _compressFn;

  static Future<Uint8List?> _defaultCompress(
      String path, int minWidth, int minHeight, int quality) {
    return FlutterImageCompress.compressWithFile(
      path,
      minWidth: minWidth,
      minHeight: minHeight,
      quality: quality,
      format: CompressFormat.jpeg,
    );
  }

  Future<ImageCompressionResult> compressFoodPhoto(File file) async {
    final bytes = await _compressFn(file.absolute.path, 1024, 1024, 80);
    if (bytes == null) {
      throw Exception('Failed to compress image');
    }
    return ImageCompressionResult(bytes, 'image/jpeg');
  }
}
