import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/muscles/muscle_catalog.dart';
import 'package:food_diary/models/localized_text.dart';
import 'package:food_diary/models/muscle.dart';

/// Groups whose exercise content is complete. Extended as content tasks land;
/// removed (checking every group) once all content exists.
const authoredGroups = <String>{'chest', 'shoulders', 'back', 'neck'};

void main() {
  final catalog = MuscleCatalog.fromJsonStrings(
    File(MuscleCatalog.musclesAsset).readAsStringSync(),
    File(MuscleCatalog.exercisesAsset).readAsStringSync(),
  );
  final idPattern = RegExp(r'^[a-z][a-z0-9_]*$');

  void expectText(LocalizedText t, String where) {
    expect(t.en.trim(), isNotEmpty, reason: '$where: en empty');
    expect(t.th?.trim() ?? '', isNotEmpty, reason: '$where: th missing');
  }

  void expectList(LocalizedList l, String where, int min, int max) {
    final th = l.th ?? const [];
    expect(l.en.length, inInclusiveRange(min, max), reason: '$where: en count');
    expect(th.length, l.en.length, reason: '$where: th count differs from en');
    for (final s in [...l.en, ...th]) {
      expect(s.trim(), isNotEmpty, reason: '$where: empty item');
    }
  }

  test('muscle ids are unique and well-formed', () {
    final ids = catalog.muscles.map((m) => m.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final id in ids) {
      expect(idPattern.hasMatch(id), isTrue, reason: id);
    }
  });

  test('every muscle has both languages', () {
    for (final m in catalog.muscles) {
      expectText(m.name, '${m.id}.name');
      expectText(m.description, '${m.id}.description');
      expect(m.anatomical.trim(), isNotEmpty, reason: '${m.id}.anatomical');
    }
  });

  test('exercise ids are unique and reference known muscles', () {
    final ids = catalog.exercises.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final e in catalog.exercises) {
      expect(idPattern.hasMatch(e.id), isTrue, reason: e.id);
      expect(e.primary, isNotEmpty, reason: '${e.id}: no primary');
      for (final id in [...e.primary, ...e.secondary]) {
        expect(catalog.muscleById(id), isNotNull, reason: '${e.id} -> $id');
      }
      expect(
        e.primary.toSet().intersection(e.secondary.toSet()),
        isEmpty,
        reason: '${e.id}: muscle both primary and secondary',
      );
    }
  });

  test('every exercise has complete bilingual content', () {
    for (final e in catalog.exercises) {
      expectText(e.name, '${e.id}.name');
      expectList(e.steps, '${e.id}.steps', 3, 5);
      expectList(e.tips, '${e.id}.tips', 1, 99);
      expectList(e.mistakes, '${e.id}.mistakes', 1, 99);
    }
  });

  test('authored muscles have enough primary exercises', () {
    for (final m in catalog.muscles) {
      if (!authoredGroups.contains(m.group.jsonName)) continue;
      final count = catalog.exercises.where((e) => e.primary.contains(m.id)).length;
      expect(
        count,
        greaterThanOrEqualTo(m.deep ? 1 : 3),
        reason: '${m.id} has $count primary exercises',
      );
    }
  });

  test('muscle groups cover every MuscleGroup', () {
    expect(catalog.muscles.map((m) => m.group).toSet(), MuscleGroup.values.toSet());
  });
}
