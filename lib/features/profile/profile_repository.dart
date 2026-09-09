import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_profile.dart';

class ProfileRepository {
  ProfileRepository(this._client);
  final SupabaseClient _client;

  Future<UserProfile?> fetchProfile() async {
    final userId = _client.auth.currentUser!.id;
    final rows = await _client
        .from('user_profiles')
        .select()
        .eq('user_id', userId)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return UserProfile.fromRow(list.first as Map<String, dynamic>);
  }

  Future<void> saveProfile(UserProfile profile) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('user_profiles').upsert(profile.toRow(userId));
  }
}
