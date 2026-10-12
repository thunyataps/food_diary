import 'package:food_diary/features/muscles/muscle_catalog.dart';
import 'package:food_diary/models/exercise.dart';
import 'package:food_diary/models/localized_text.dart';
import 'package:food_diary/models/muscle.dart';

Muscle _muscle(String id, MuscleGroup group, String en, String th, {bool deep = false}) => Muscle(
  id: id,
  group: group,
  deep: deep,
  name: LocalizedText(en: en, th: th),
  anatomical: '$en (anatomical)',
  description: LocalizedText(en: '$en description', th: '$th คำอธิบาย'),
);

Exercise _exercise(String id, String en, List<String> primary, List<String> secondary) => Exercise(
  id: id,
  name: LocalizedText(en: en, th: '$en TH'),
  equipment: Equipment.dumbbell,
  difficulty: Difficulty.beginner,
  primary: primary,
  secondary: secondary,
  steps: const LocalizedList(en: ['Step one', 'Step two', 'Step three'], th: ['ขั้นหนึ่ง', 'ขั้นสอง', 'ขั้นสาม']),
  tips: const LocalizedList(en: ['A tip'], th: ['เคล็ดลับ']),
  mistakes: const LocalizedList(en: ['A mistake'], th: ['ข้อผิด']),
);

MuscleCatalog testCatalog() => MuscleCatalog(
  muscles: [
    _muscle('pec_major_clavicular', MuscleGroup.chest, 'Upper chest', 'อกบน'),
    _muscle('deltoid_anterior', MuscleGroup.shoulders, 'Front delt', 'ไหล่หน้า'),
    _muscle('subscapularis', MuscleGroup.shoulders, 'Subscapularis', 'ซับสแคป', deep: true),
  ],
  exercises: [
    _exercise('incline_dumbbell_press', 'Incline Dumbbell Press', ['pec_major_clavicular'], ['deltoid_anterior']),
    _exercise('front_raise', 'Front Raise', ['deltoid_anterior'], ['pec_major_clavicular']),
    _exercise('cable_internal_rotation', 'Cable Internal Rotation', ['subscapularis'], []),
  ],
);
