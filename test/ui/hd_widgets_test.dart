import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helldivers_wiki/theme/hd_theme.dart';
import 'package:helldivers_wiki/theme/hd_widgets.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: buildHdTheme(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  testWidgets('HdSectionHeader 显示大写标题', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(const HdSectionHeader(title: '装备数据')));
    expect(find.text('装备数据'), findsOneWidget);
    // 纯英文标题会被转为大写。
    await tester.pumpWidget(_wrap(const HdSectionHeader(title: 'arsenal')));
    expect(find.text('ARSENAL'), findsOneWidget);
  });

  testWidgets('HdPanelCard 显示内容并响应点击', (WidgetTester tester) async {
    bool tapped = false;
    await tester.pumpWidget(_wrap(HdPanelCard(
      onTap: () => tapped = true,
      child: const Text('面板内容'),
    )));
    expect(find.text('面板内容'), findsOneWidget);
    await tester.tap(find.text('面板内容'));
    expect(tapped, isTrue);
  });

  testWidgets('HdButton 两种样式均可点击', (WidgetTester tester) async {
    int count = 0;
    await tester.pumpWidget(_wrap(Column(
      children: <Widget>[
        HdButton(label: '执行', onPressed: () => count++),
        HdButton(
          label: '取消',
          variant: HdButtonVariant.outlined,
          onPressed: () => count += 10,
        ),
      ],
    )));
    await tester.tap(find.text('执行'));
    await tester.tap(find.text('取消'));
    expect(count, 11);
  });

  testWidgets('HdLoadingView 显示加载文案', (WidgetTester tester) async {
    await tester.pumpWidget(
        _wrap(const HdLoadingView(message: '正在接入超级地球终端…')));
    expect(find.text('正在接入超级地球终端…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('HdErrorView 显示错误并触发重试', (WidgetTester tester) async {
    bool retried = false;
    await tester.pumpWidget(_wrap(HdErrorView(
      message: '连接失败',
      onRetry: () => retried = true,
    )));
    expect(find.text('连接失败'), findsOneWidget);
    await tester.tap(find.text('重试'));
    expect(retried, isTrue);
  });

  testWidgets('HdSearchBar 接受输入并回调', (WidgetTester tester) async {
    String changed = '';
    String submitted = '';
    await tester.pumpWidget(_wrap(HdSearchBar(
      onChanged: (String v) => changed = v,
      onSubmitted: (String v) => submitted = v,
    )));
    await tester.enterText(find.byType(TextField), '解放者');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(changed, '解放者');
    expect(submitted, '解放者');
  });
}
