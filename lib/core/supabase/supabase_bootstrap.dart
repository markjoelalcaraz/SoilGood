/// Core bootstrap that initializes the shared Supabase client for the whole app.
///
/// Call once from main. Other features import supabase from here instead of
/// creating their own clients. Uses the anon key only (never service_role).
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_env.dart';

/// Boots the Supabase client using values from [AppEnv].
///
/// Uses legacy anon JWT (`eyJ...`) — verified with Data API.
/// New `sb_publishable_...` keys returned 401 on REST in our setup tests.
Future<void> bootstrapSupabase() async {
  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    anonKey: AppEnv.supabaseAnonKey, // ignore: deprecated_member_use
  );
}

/// Shortcut to the shared Supabase client after bootstrap.
SupabaseClient get supabase => Supabase.instance.client;
