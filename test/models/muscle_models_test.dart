import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/models/exercise.dart';
import 'package:food_diary/models/localized_text.dart';
import 'package:food_diary/models/muscle.dart';

void main() {
  const en = Locale('en');
  const th = Locale('th');

  group('LocalizedText', () {
    test('resolves by language code', () {
      final t = LocalizedText.fromJson({'en': 'Chest', 'th': 'อก'});
      expect(t.resolve(en), 'Chest');
      expect(t.resolve(th), 'อก');
      expect(t.resolve(const Locale('th', 'TH')), 'อก');
    });

    test('falls back to English when Thai is empty or missing', () {
      expect(LocalizedText.fromJson({'en': 'Chest', 'th': ''}).resolve(th), 'Chest');
      expect(LocalizedText.fromJson({'en': 'Chest'}).resolve(th), 'Chest');
    });
  });

  group('LocalizedList', () {
    test('resolves and falls back', () {
      final l = LocalizedList.fromJson({
        'en': ['a', 'b'],
        'th': ['ก', 'ข'],
      });
      expect(l.resolve(th), ['ก', 'ข']);
      expect(l.resolve(en), ['a', 'b']);
      expect(LocalizedList.fromJson({'en': ['a'], 'th': <String>[]}).resolve(th), ['a']);
    });
  });

  test('Muscle.fromJson parses all fields', () {
    final m = Muscle.fromJson({
      'id': 'gastrocnemius_medial',
      'group': 'lower_legs',
      'deep': false,
      'name': {'en': 'Inner calf', 'th': 'น่องด้านใน'},
      'anatomical': 'Gastrocnemius, medial head',
      'description': {'en': 'Plantar-flexes the ankle.', 'th': 'เหยียดปลายเท้า'},
    });
    expect(m.id, 'gastrocnemius_medial');
    expect(m.group, MuscleGroup.lowerLegs);
    expect(m.deep, isFalse);
    expect(m.name.resolve(const Locale('th')), 'น่องด้านใน');
    expect(m.anatomical, 'Gastrocnemius, medial head');
  });

  test('Muscle.fromJson defaults deep to false and rejects unknown groups', () {
    final base = {
      'id': 'x',
      'group': 'chest',
      'name': {'en': 'X'},
      'anatomical': 'X',
      'description': {'en': 'X'},
    };
    expect(Muscle.fromJson(base).deep, isFalse);
    expect(
      () => Muscle.fromJson({...base, 'group': 'tail'}),
      throwsFormatException,
    );
  });

  test('Exercise.fromJson parses all fields', () {
    final e = Exercise.fromJson({
      'id': 'push_up',
      'name': {'en': 'Push-up', 'th': 'วิดพื้น'},
      'equipment': 'bodyweight',
      'difficulty': 'beginner',
      'primary': ['pec_major_sternocostal'],
      'secondary': ['triceps_lateral'],
      'steps': {'en': ['1', '2', '3'], 'th': ['๑', '๒', '๓']},
      'tips': {'en': ['t'], 'th': ['ท']},
      'mistakes': {'en': ['m'], 'th': ['ม']},
    });
    expect(e.equipment, Equipment.bodyweight);
    expect(e.difficulty, Difficulty.beginner);
    expect(e.primary, ['pec_major_sternocostal']);
    expect(e.secondary, ['triceps_lateral']);
    expect(e.steps.resolve(const Locale('th')), ['๑', '๒', '๓']);
  });

  test('Exercise.fromJson defaults secondary to empty', () {
    final e = Exercise.fromJson({
      'id': 'heel_walk',
      'name': {'en': 'Heel Walk'},
      'equipment': 'bodyweight',
      'difficulty': 'beginner',
      'primary': ['tibialis_anterior'],
      'steps': {'en': ['1', '2', '3']},
      'tips': {'en': ['t']},
      'mistakes': {'en': ['m']},
    });
    expect(e.secondary, isEmpty);
  });
}
