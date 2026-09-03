import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/food_item.dart';
import '../../models/meal_entry.dart';

class Totals {
  Totals(this.calories, this.protein, this.carb, this.fat);
  final double calories;
  final double protein;
  final double carb;
  final double fat;
}

Totals computeTotals(List<FoodItem> items) {
  return Totals(
    items.fold(0, (s, i) => s + i.calories),
    items.fold(0, (s, i) => s + i.protein),
    items.fold(0, (s, i) => s + i.carb),
    items.fold(0, (s, i) => s + i.fat),
  );
}

/// The half-open `[start, end)` bounds of the *local* calendar day containing
/// [day], serialized as UTC ISO-8601 (`...Z`).
///
/// `eaten_at` is a `timestamptz` and is written as UTC (see [DiaryRepository.saveMealEntry]),
/// so the day filter has to be expressed in UTC too — otherwise a naive local
/// string is interpreted as UTC by Postgres and every row is off by the
/// device's offset.
({String start, String end}) dayRangeUtc(DateTime day) {
  final start = DateTime(day.year, day.month, day.day);
  final end = start.add(const Duration(days: 1));
  return (start: start.toUtc().toIso8601String(), end: end.toUtc().toIso8601String());
}

class DiaryRepository {
  DiaryRepository(this._client);
  final SupabaseClient _client;

  Future<String> saveMealEntry({
    required List<FoodItem> items,
    required DateTime eatenAt,
    String? note,
    Uint8List? photoBytes,
  }) async {
    final userId = _client.auth.currentUser!.id;
    String? photoUrl;

    if (photoBytes != null) {
      final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      try {
        await _client.storage.from('meal-photos').uploadBinary(
              path,
              photoBytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        photoUrl = path;
      } catch (error) {
        // Per spec: a failed photo upload must not block the save. Keep
        // photoUrl null and store the nutrition data anyway.
        debugPrint('meal photo upload failed, saving entry without a photo: $error');
        photoUrl = null;
      }
    }

    final totals = computeTotals(items);
    final entryRow = await _client
        .from('meal_entries')
        .insert({
          'user_id': userId,
          'photo_url': photoUrl,
          'note': note,
          'eaten_at': eatenAt.toUtc().toIso8601String(),
          'total_calories': totals.calories,
          'total_protein': totals.protein,
          'total_carb': totals.carb,
          'total_fat': totals.fat,
        })
        .select()
        .single();

    final mealEntryId = entryRow['id'] as String;
    await _client.from('food_items').insert(items.map((i) => i.toInsertRow(mealEntryId)).toList());

    return mealEntryId;
  }

  Future<List<MealEntry>> entriesForDay(DateTime day) async {
    final range = dayRangeUtc(day);

    final rows = await _client
        .from('meal_entries')
        .select('*, food_items(*)')
        .gte('eaten_at', range.start)
        .lt('eaten_at', range.end)
        .order('eaten_at');

    return (rows as List).map((row) {
      final itemsJson = row['food_items'] as List;
      final items = itemsJson
          .map((j) => FoodItem(
                id: j['id'] as String,
                name: j['name'] as String,
                quantity: j['quantity'] as String,
                calories: (j['calories'] as num).toDouble(),
                protein: (j['protein'] as num).toDouble(),
                carb: (j['carb'] as num).toDouble(),
                fat: (j['fat'] as num).toDouble(),
                source: j['source'] as String,
              ))
          .toList();
      return MealEntry.fromRow(row as Map<String, dynamic>, items);
    }).toList();
  }
}
