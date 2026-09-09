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
  return (
    start: start.toUtc().toIso8601String(),
    end: end.toUtc().toIso8601String(),
  );
}

/// The half-open `[start, end)` UTC bounds of the 7 local calendar days
/// ending on (and including) [endDay]. Follows the same UTC-serialization
/// convention as [dayRangeUtc], for the same reason (`eaten_at` is a
/// `timestamptz` written as UTC).
({String start, String end}) weekRangeUtc(DateTime endDay) {
  final end = DateTime(
    endDay.year,
    endDay.month,
    endDay.day,
  ).add(const Duration(days: 1));
  final start = end.subtract(const Duration(days: 7));
  return (
    start: start.toUtc().toIso8601String(),
    end: end.toUtc().toIso8601String(),
  );
}

class WeeklyAverages {
  const WeeklyAverages(this.calories, this.protein, this.carb, this.fat);
  final double calories;
  final double protein;
  final double carb;
  final double fat;
}

/// Averages [entries]' totals across a fixed 7-day denominator (not the
/// number of days that actually have entries) — a week with only 3 logged
/// days should show a LOWER average than a week logged every day, which is
/// the useful signal for "how consistent have I actually been."
WeeklyAverages computeWeeklyAverages(List<MealEntry> entries) {
  final totalCalories = entries.fold<double>(0, (s, e) => s + e.totalCalories);
  final totalProtein = entries.fold<double>(0, (s, e) => s + e.totalProtein);
  final totalCarb = entries.fold<double>(0, (s, e) => s + e.totalCarb);
  final totalFat = entries.fold<double>(0, (s, e) => s + e.totalFat);
  return WeeklyAverages(
    totalCalories / 7,
    totalProtein / 7,
    totalCarb / 7,
    totalFat / 7,
  );
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
        await _client.storage
            .from('meal-photos')
            .uploadBinary(
              path,
              photoBytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        photoUrl = path;
      } catch (error) {
        // Per spec: a failed photo upload must not block the save. Keep
        // photoUrl null and store the nutrition data anyway.
        debugPrint(
          'meal photo upload failed, saving entry without a photo: $error',
        );
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
    await _client
        .from('food_items')
        .insert(items.map((i) => i.toInsertRow(mealEntryId)).toList());

    return mealEntryId;
  }

  /// Returns a temporary signed URL (1 hour expiry) for the given
  /// `meal-photos` storage [path], or `null` if the request fails for any
  /// reason. The bucket is private, so [MealEntry.photoUrl] (really just an
  /// object path) can't be loaded directly as an image URL.
  Future<String?> signedPhotoUrl(String path) async {
    try {
      return await _client.storage
          .from('meal-photos')
          .createSignedUrl(path, 3600);
    } catch (error) {
      debugPrint('signed photo URL failed for $path: $error');
      return null;
    }
  }

  /// Deletes the `meal_entries` row with [mealEntryId]. Its `food_items`
  /// rows are removed automatically via `on delete cascade`. RLS already
  /// restricts this to the caller's own rows, so no extra `user_id` filter
  /// is needed here (matching the rest of this file).
  Future<void> deleteMealEntry(String mealEntryId) async {
    await _client.from('meal_entries').delete().eq('id', mealEntryId);
  }

  Future<List<MealEntry>> entriesForDay(DateTime day) async {
    final range = dayRangeUtc(day);
    return _entriesInRange(range.start, range.end);
  }

  /// Entries for the 7 local calendar days ending on (and including)
  /// [endDay] — see [weekRangeUtc].
  Future<List<MealEntry>> entriesForWeekEnding(DateTime endDay) async {
    final range = weekRangeUtc(endDay);
    return _entriesInRange(range.start, range.end);
  }

  Future<List<MealEntry>> _entriesInRange(String start, String end) async {
    final rows = await _client
        .from('meal_entries')
        .select('*, food_items(*)')
        .gte('eaten_at', start)
        .lt('eaten_at', end)
        .order('eaten_at');

    return (rows as List)
        .map((row) => _mealEntryFromRow(row as Map<String, dynamic>))
        .toList();
  }

  MealEntry _mealEntryFromRow(Map<String, dynamic> row) {
    final itemsJson = row['food_items'] as List;
    final items = itemsJson
        .map(
          (j) => FoodItem(
            id: j['id'] as String,
            name: j['name'] as String,
            quantity: j['quantity'] as String,
            calories: (j['calories'] as num).toDouble(),
            protein: (j['protein'] as num).toDouble(),
            carb: (j['carb'] as num).toDouble(),
            fat: (j['fat'] as num).toDouble(),
            source: j['source'] as String,
          ),
        )
        .toList();
    return MealEntry.fromRow(row, items);
  }
}
