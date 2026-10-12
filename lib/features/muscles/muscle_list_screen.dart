import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/muscle.dart';
import 'muscle_catalog.dart';

String muscleGroupLabel(AppLocalizations l10n, MuscleGroup g) => switch (g) {
  MuscleGroup.chest => l10n.muscleGroupChest,
  MuscleGroup.shoulders => l10n.muscleGroupShoulders,
  MuscleGroup.back => l10n.muscleGroupBack,
  MuscleGroup.arms => l10n.muscleGroupArms,
  MuscleGroup.core => l10n.muscleGroupCore,
  MuscleGroup.hips => l10n.muscleGroupHips,
  MuscleGroup.thighs => l10n.muscleGroupThighs,
  MuscleGroup.lowerLegs => l10n.muscleGroupLowerLegs,
  MuscleGroup.neck => l10n.muscleGroupNeck,
};

Future<Muscle?> pushMuscleList(BuildContext context, MuscleCatalog catalog) =>
    Navigator.push<Muscle>(
      context,
      MaterialPageRoute(builder: (_) => MuscleListScreen(catalog: catalog)),
    );

/// Searchable list of every muscle, grouped by body region. The only way to
/// reach deep muscles, which have no mesh on the 3D body.
class MuscleListScreen extends StatefulWidget {
  const MuscleListScreen({super.key, required this.catalog});

  final MuscleCatalog catalog;

  @override
  State<MuscleListScreen> createState() => _MuscleListScreenState();
}

class _MuscleListScreenState extends State<MuscleListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final results = widget.catalog.search(_query);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.musclesListTooltip)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const Key('muscle_search_field'),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.musclesSearchHint,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? Center(child: Text(l10n.musclesNoResults))
                : ListView(
                    children: [
                      for (final group in MuscleGroup.values)
                        if (results.any((m) => m.group == group)) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              muscleGroupLabel(l10n, group),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          for (final m in results.where((m) => m.group == group))
                            ListTile(
                              key: Key('muscle_tile_${m.id}'),
                              title: Text(m.name.resolve(locale)),
                              subtitle: Text(m.anatomical),
                              trailing: m.deep
                                  ? const Icon(Icons.layers_outlined)
                                  : null,
                              onTap: () => Navigator.pop(context, m),
                            ),
                        ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
