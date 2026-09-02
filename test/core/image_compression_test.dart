import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/core/image_compression.dart';

void main() {
  test('compressFoodPhoto returns compressed bytes with jpeg mimeType', () async {
    final compressor = ImageCompressor(
      compressFn: (path, minWidth, minHeight, quality) async => Uint8List.fromList([1, 2, 3]),
    );
    final result = await compressor.compressFoodPhoto(File('fake.jpg'));
    expect(result.bytes, Uint8List.fromList([1, 2, 3]));
    expect(result.mimeType, 'image/jpeg');
  });

  test('compressFoodPhoto throws when compression returns null', () async {
    final compressor = ImageCompressor(
      compressFn: (path, minWidth, minHeight, quality) async => null,
    );
    expect(() => compressor.compressFoodPhoto(File('fake.jpg')), throwsException);
  });
}
