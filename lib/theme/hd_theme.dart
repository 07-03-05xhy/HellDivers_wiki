import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 绝地潜兵2 游戏终端风配色。
///
/// 黄黑军事 HUD：主黄 / 深黑底 / 炭灰面板 / 警示红点缀。
abstract final class HdColors {
  /// 超级地球黄 —— 主强调色。
  static const Color helldiverYellow = Color(0xFFFFD500);

  /// 深黑背景。
  static const Color voidBlack = Color(0xFF0D0D0D);

  /// 炭灰面板。
  static const Color panelGrey = Color(0xFF1A1A1A);

  /// 面板上的次级灰（边框/分隔线）。
  static const Color lineGrey = Color(0xFF3A3A3A);

  /// 警示红（删除/警告/敌人）。
  static const Color alertRed = Color(0xFFFF3B30);

  /// 次要文字灰。
  static const Color dimGrey = Color(0xFF9E9E9E);

  /// 主文字（近白）。
  static const Color textPrimary = Color(0xFFF2F2F2);
}

/// HD2 终端风 ThemeData。
ThemeData buildHdTheme() {
  final TextTheme base = GoogleFonts.robotoMonoTextTheme(
    ThemeData.dark().textTheme,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: HdColors.voidBlack,
    colorScheme: const ColorScheme.dark(
      primary: HdColors.helldiverYellow,
      onPrimary: HdColors.voidBlack,
      secondary: HdColors.helldiverYellow,
      surface: HdColors.panelGrey,
      onSurface: HdColors.textPrimary,
      error: HdColors.alertRed,
      outline: HdColors.lineGrey,
    ),
    textTheme: base.apply(
      bodyColor: HdColors.textPrimary,
      displayColor: HdColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: HdColors.voidBlack,
      foregroundColor: HdColors.helldiverYellow,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: const CardThemeData(
      color: HdColors.panelGrey,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: HdColors.lineGrey,
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: HdColors.helldiverYellow,
    ),
  );
}
