import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/weight_log.dart';

class WeightRepository {
  WeightRepository(this._client);
  final SupabaseClient _client;

  Future<WeightLog?> fetchWeightForDate(DateTime date) async {
    final userId = _client.auth.currentUser!.id;
    final rows = await _client
        .from('weight_logs')
        .select()
        .eq('user_id', userId)
        .eq('logged_date', formatLoggedDate(date))
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return WeightLog.fromRow(list.first as Map<String, dynamic>);
  }

  Future<WeightLog?> fetchLatestWeight() async {
    final userId = _client.auth.currentUser!.id;
    final rows = await _client
        .from('weight_logs')
        .select()
        .eq('user_id', userId)
        .order('logged_date', ascending: false)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return WeightLog.fromRow(list.first as Map<String, dynamic>);
  }

  Future<List<WeightLog>> fetchRecentWeights({int days = 30}) async {
    final userId = _client.auth.currentUser!.id;
    final since = DateTime.now().subtract(Duration(days: days - 1));
    final rows = await _client
        .from('weight_logs')
        .select()
        .eq('user_id', userId)
        .gte('logged_date', formatLoggedDate(since))
        .order('logged_date', ascending: true);
    return (rows as List)
        .map((r) => WeightLog.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveWeightForDate(DateTime date, double weightKg) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('weight_logs').upsert({
      'user_id': userId,
      'logged_date': formatLoggedDate(date),
      'weight_kg': weightKg,
    }, onConflict: 'user_id,logged_date');
  }
}
