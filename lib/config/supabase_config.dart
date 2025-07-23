import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Supabase 프로젝트 설정 (asset_manager 프로젝트)
  static const String supabaseUrl = 'https://ggkhmksvypmlxhttqthb.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdna2hta3N2eXBtbHhodHRxdGhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMyNDQ1MTUsImV4cCI6MjA2ODgyMDUxNX0.pCQE4Hr7NNpX2zjAmLYq--j9CDyodK1PlDZX3kJRFJ8';
  
  static SupabaseClient get client => Supabase.instance.client;
  
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}