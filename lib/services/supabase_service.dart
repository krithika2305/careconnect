import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://dvewmkjqytcribdasoxt.supabase.co',
      anonKey: 'sb_publishable_CI0fsm3UqgzFPnB0SVQljA_-lSMiMsn',
    );
  }
}