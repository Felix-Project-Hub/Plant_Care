// 基本 Flutter widget 測試
// 驗證 PlantAPP 可正常啟動並顯示啟動畫面

import 'package:flutter_test/flutter_test.dart';

import 'package:plant/main.dart';

void main() {
  testWidgets('App 啟動時顯示啟動畫面', (WidgetTester tester) async {
    // 建立 APP 並觸發一幀
    await tester.pumpWidget(const MyApp());

    // 驗證 LaunchGate 顯示主要元素
    expect(find.text('Plant Care'), findsOneWidget);
    expect(find.text('Care for your green friends'), findsOneWidget);
  });
}
