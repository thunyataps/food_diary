import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/exercise.dart';
import '../../models/muscle.dart';

String equipmentLabel(AppLocalizations l10n, Equipment e) => switch (e) {
  Equipment.bodyweight => l10n.equipmentBodyweight,
  Equipment.dumbbell => l10n.equipmentDumbbell,
  Equipment.barbell => l10n.equipmentBarbell,
  Equipment.cable => l10n.equipmentCable,
  Equipment.machine => l10n.equipmentMachine,
  Equipment.kettlebell => l10n.equipmentKettlebell,
  Equipment.band => l10n.equipmentBand,
};

String difficultyLabel(AppLocalizations l10n, Difficulty d) => switch (d) {
  Difficulty.beginner => l10n.difficultyBeginner,
  Difficulty.intermediate => l10n.difficultyIntermediate,
  Difficulty.advanced => l10n.difficultyAdvanced,
};

/// Draggable sheet over the 3D body listing one muscle's exercises.
class MuscleSheet extends StatefulWidget {
  const MuscleSheet({
    super.key,
    required this.muscle,
    required this.exercises,
    required this.muscleNameOf,
    required this.onExerciseExpanded,
    required this.onClose,
  });

  final Muscle muscle;

  /// Already ordered: primary-role exercises first.
  final List<Exercise> exercises;
  final String Function(String muscleId) muscleNameOf;
  final ValueChanged<Exercise?> onExerciseExpanded;
  final VoidCallback onClose;

  @override
  State<MuscleSheet> createState() => _MuscleSheetState();
}

class _MuscleSheetState extends State<MuscleSheet> {
  String? _expandedId;

  void _toggle(Exercise exercise) {
    final expand = _expandedId != exercise.id;
    setState(() => _expandedId = expand ? exercise.id : null);
    widget.onExerciseExpanded(expand ? exercise : null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final theme = Theme.of(context);
    final muscle = widget.muscle;

    return DraggableScrollableSheet(
      key: const Key('muscle_sheet'),
      initialChildSize: 0.4,
      minChildSize: 0.2,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Material(
        color: Colors.white,
        elevation: 8,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    muscle.name.resolve(locale),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: const Key('muscle_sheet_close'),
                  icon: const Icon(Icons.close),
                  tooltip: l10n.musclesClose,
                  onPressed: widget.onClose,
                ),
              ],
            ),
            Text(
              muscle.anatomical,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
            if (muscle.deep) ...[
              const SizedBox(height: 8),
              Text(
                l10n.musclesDeepNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(muscle.description.resolve(locale)),
            const SizedBox(height: 12),
            if (widget.exercises.isEmpty)
              Text(l10n.musclesNoExercises)
            else
              for (final exercise in widget.exercises)
                _ExerciseTile(
                  exercise: exercise,
                  isPrimary: exercise.primary.contains(muscle.id),
                  expanded: _expandedId == exercise.id,
                  muscleNameOf: widget.muscleNameOf,
                  onTap: () => _toggle(exercise),
                ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({
    required this.exercise,
    required this.isPrimary,
    required this.expanded,
    required this.muscleNameOf,
    required this.onTap,
  });

  final Exercise exercise;
  final bool isPrimary;
  final bool expanded;
  final String Function(String muscleId) muscleNameOf;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    Widget section(String title, List<String> lines) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          for (final line in lines) Text(line),
        ],
      ),
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            key: Key('exercise_${exercise.id}'),
            title: Text(exercise.name.resolve(locale)),
            subtitle: Text(
              '${equipmentLabel(l10n, exercise.equipment)} · '
              '${difficultyLabel(l10n, exercise.difficulty)}',
            ),
            trailing: Chip(
              label: Text(
                isPrimary ? l10n.musclesRolePrimary : l10n.musclesRoleSecondary,
              ),
              backgroundColor: primaryColor.withValues(
                alpha: isPrimary ? 0.2 : 0.08,
              ),
              side: BorderSide.none,
            ),
            onTap: onTap,
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  section(l10n.musclesStepsTitle, [
                    for (final (i, step)
                        in exercise.steps.resolve(locale).indexed)
                      '${i + 1}. $step',
                  ]),
                  section(l10n.musclesTipsTitle, [
                    for (final tip in exercise.tips.resolve(locale)) '• $tip',
                  ]),
                  section(l10n.musclesMistakesTitle, [
                    for (final m in exercise.mistakes.resolve(locale)) '• $m',
                  ]),
                  section(l10n.musclesWorksTitle, [
                    '${l10n.musclesRolePrimary}: '
                        '${exercise.primary.map(muscleNameOf).join(', ')}',
                    if (exercise.secondary.isNotEmpty)
                      '${l10n.musclesRoleSecondary}: '
                          '${exercise.secondary.map(muscleNameOf).join(', ')}',
                  ]),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
