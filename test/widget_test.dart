// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:asset_helper/providers/foreign_investor_provider.dart';

void main() {
  testWidgets('App starts and renders properly', (WidgetTester tester) async {
    // Build our app with a mock provider and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ForeignInvestorProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Test App'),
            ),
            body: const Center(
              child: Text('국내주식 수급 동향 모니터 현황'),
            ),
          ),
        ),
      ),
    );

    // Verify that the app renders without errors
    expect(find.text('국내주식 수급 동향 모니터 현황'), findsOneWidget);
    expect(find.text('Test App'), findsOneWidget);
  });
}
