import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'config/supabase_config.dart';
import 'screens/home_screen.dart';
import 'providers/foreign_investor_provider.dart';
import 'services/auto_sync_scheduler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Supabase 초기화
  await SupabaseConfig.initialize();
  
  // 자동 데이터 동기화 스케줄러 시작
  _initializeAutoSync();
  
  runApp(const MyApp());
}

/// 자동 데이터 동기화 초기화
void _initializeAutoSync() {
  // 스마트 동기화 스케줄러 사용 (거래일 기준)
  final scheduler = SmartSyncScheduler();
  
  // 앱 시작 1분 후부터 30분마다 자동 동기화
  scheduler.startAutoSync(
    intervalMinutes: 30,        // 30분마다 동기화
    initialDelayMinutes: 1,     // 앱 시작 1분 후 첫 동기화
    onSyncComplete: () {
      // 동기화 완료 시 필요한 작업이 있다면 여기에 추가
    },
  );
  
  // 앱 종료 시 스케줄러 정리
  SystemChannels.lifecycle.setMessageHandler((message) async {
    if (message == 'AppLifecycleState.detached') {
      scheduler.dispose();
    }
    return null;
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ForeignInvestorProvider()),
      ],
      child: MaterialApp(
        title: '국내주식 수급 동향 모니터 현황',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
          cardTheme: CardTheme(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

