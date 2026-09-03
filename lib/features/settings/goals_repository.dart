import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/goals.dart';

class GoalsRepository {
  GoalsRepository(this._client);
  final SupabaseClient _client;

  Future<Goals?> fetchGoals() async {
    final userId = _client.auth.currentUser!.id;
    final rows = await _client.from('user_goals').select().eq('user_id', userId).limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return Goals.fromRow(list.first as Map<String, dynamic>);
  }

  Future<void> saveGoals(Goals goals) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('user_goals').upsert(goals.toRow(userId));
  }
}
