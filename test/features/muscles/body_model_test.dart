import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/muscles/muscle_catalog.dart';

const _glbPath = 'assets/body_viewer/body.glb';

/// Node names from a GLB's JSON chunk.
List<String> glbNodeNames(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  expect(data.getUint32(0, Endian.little), 0x46546C67, reason: 'not a GLB');
  final jsonLength = data.getUint32(12, Endian.little);
  expect(data.getUint32(16, Endian.little), 0x4E4F534A, reason: 'first chunk is not JSON');
  final json = jsonDecode(utf8.decode(bytes.sublist(20, 20 + jsonLength)))
      as Map<String, dynamic>;
  return [
    for (final n in (json['nodes'] as List? ?? const []))
      if ((n as Map<String, dynamic>)['name'] case final String name) name,
  ];
}

void main() {
  final bytes = File(_glbPath).readAsBytesSync();
  final catalog = MuscleCatalog.fromJsonStrings(
    File(MuscleCatalog.musclesAsset).readAsStringSync(),
    File(MuscleCatalog.exercisesAsset).readAsStringSync(),
  );
  // Parsed in setUpAll: glbNodeNames uses expect, which is only allowed
  // inside a test or setup callback.
  late final Set<String> meshIds;
  setUpAll(() {
    meshIds = glbNodeNames(bytes)
        .where((n) => !n.startsWith('_ctx_') && n.contains('__'))
        .map((n) => n.split('__').first)
        .toSet();
  });

  test('body.glb is at most 4 MB', () {
    expect(bytes.length, lessThanOrEqualTo(4 * 1024 * 1024));
  });

  test('every muscle mesh maps to a known muscle', () {
    for (final id in meshIds) {
      expect(catalog.muscleById(id), isNotNull, reason: 'mesh id $id');
    }
  });

  test('every non-deep muscle has a mesh and deep muscles have none', () {
    for (final m in catalog.muscles) {
      expect(meshIds.contains(m.id), !m.deep, reason: m.id);
    }
  });
}
