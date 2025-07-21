import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Supabase 프로젝트 설정 (earthquake 프로젝트와 동일한 설정 사용)
  static const String supabaseUrl = 'https://myvuxuwczrlhwnnceile.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im15dnV4dXdjenJsaHdubmNlaWxlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI4MjE3MTcsImV4cCI6MjA2ODM5NzcxN30.-DZ4pyYwRmG3dRwR3jkXIc37ARo2mPui36Ji9PmJ690';
  
  static SupabaseClient get client => Supabase.instance.client;
  
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}