import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/exercise.dart';
import '../../models/muscle.dart';

/// All bundled muscle-map content, loaded once from JSON assets.
class MuscleCatalog {
  MuscleCatalog({
    required List<Muscle> muscles,
    required List<Exercise> exercises,
  }) : muscles = List.unmodifiable(muscles),
       exercises = List.unmodifiable(exercises),
       _byId = {for (final m in muscles) m.id: m};

  static const musclesAsset = 'assets/muscles/muscles.json';
  static const exercisesAsset = 'assets/muscles/exercises.json';

  final List<Muscle> muscles;
  final List<Exercise> exercises;
  final Map<String, Muscle> _byId;

  factory MuscleCatalog.fromJsonStrings(
    String musclesJson,
    String exercisesJson,
  ) => MuscleCatalog(
    muscles: (jsonDecode(musclesJson) as List)
        .map((j) => Muscle.fromJson(j as Map<String, dynamic>))
        .toList(),
    exercises: (jsonDecode(exercisesJson) as List)
        .map((j) => Exercise.fromJson(j as Map<String, dynamic>))
        .toList(),
  );

  static Future<MuscleCatalog> load(AssetBundle bundle) async =>
      MuscleCatalog.fromJsonStrings(
        await bundle.loadString(musclesAsset),
        await bundle.loadString(exercisesAsset),
      );

  Muscle? muscleById(String id) => _byId[id];

  List<Exercise> exercisesFor(String muscleId) => [
    ...exercises.where((e) => e.primary.contains(muscleId)),
    ...exercises.where(
      (e) => !e.primary.contains(muscleId) && e.secondary.contains(muscleId),
    ),
  ];

  List<Muscle> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return muscles;
    return muscles.where((m) {
      return [
        m.name.en,
        m.name.th ?? '',
        m.anatomical,
        m.id,
      ].any((s) => s.toLowerCase().contains(q));
    }).toList();
  }
}
