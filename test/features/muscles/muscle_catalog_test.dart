import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/muscles/muscle_catalog.dart';

Map<String, dynamic> _muscle(String id, String en, String th, String anat) => {
  'id': id,
  'group': 'chest',
  'name': {'en': en, 'th': th},
  'anatomical': anat,
  'description': {'en': 'd', 'th': 'ด'},
};

Map<String, dynamic> _exercise(String id, List<String> p, List<String> s) => {
  'id': id,
  'name': {'en': id, 'th': id},
  'equipment': 'bodyweight',
  'difficulty': 'beginner',
  'primary': p,
  'secondary': s,
  'steps': {'en': ['1', '2', '3'], 'th': ['1', '2', '3']},
  'tips': {'en': ['t'], 'th': ['t']},
  'mistakes': {'en': ['m'], 'th': ['m']},
};

void main() {
  final catalog = MuscleCatalog.fromJsonStrings(
    jsonEncode([
      _muscle('pec_major_clavicular', 'Upper chest', 'อกบน', 'Pectoralis major, clavicular head'),
      _muscle('deltoid_anterior', 'Front delt', 'ไหล่หน้า', 'Deltoid, clavicular part'),
    ]),
    jsonEncode([
      _exercise('a_secondary', ['deltoid_anterior'], ['pec_major_clavicular']),
      _exercise('b_primary', ['pec_major_clavicular'], []),
      _exercise('c_unrelated', ['deltoid_anterior'], []),
      _exercise('d_primary', ['pec_major_clavicular', 'deltoid_anterior'], []),
    ]),
  );

  test('muscleById finds known ids and returns null otherwise', () {
    expect(catalog.muscleById('deltoid_anterior')!.name.en, 'Front delt');
    expect(catalog.muscleById('nope'), isNull);
  });

  test('exercisesFor lists primary first, then secondary, in file order', () {
    expect(
      catalog.exercisesFor('pec_major_clavicular').map((e) => e.id),
      ['b_primary', 'd_primary', 'a_secondary'],
    );
    expect(catalog.exercisesFor('unknown'), isEmpty);
  });

  test('search matches English, Thai, anatomical name and id, case-insensitively', () {
    expect(catalog.search('upper').map((m) => m.id), ['pec_major_clavicular']);
    expect(catalog.search('ไหล่').map((m) => m.id), ['deltoid_anterior']);
    expect(catalog.search('PECTORALIS').map((m) => m.id), ['pec_major_clavicular']);
    expect(catalog.search('deltoid_').map((m) => m.id), ['deltoid_anterior']);
  });

  test('blank search returns every muscle', () {
    expect(catalog.search('  ').length, 2);
  });
}
