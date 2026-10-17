import 'package:flutter/material.dart';

import 'hd_theme.dart';

/// 切角路径：右上角斜切 [cut] 像素的矩形路径。
Path _cutCornerPath(Size size, double cut) {
  return Path()
    ..moveTo(0, 0)
    ..lineTo(size.width - cut, 0)
    ..lineTo(size.width, cut)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();
}

class _CutCornerClipper extends CustomClipper<Path> {
  const _CutCornerClipper(this.cut);

  final double cut;

  @override
  Path getClip(Size size) => _cutCornerPath(size, cut);

  @override
  bool shouldReclip(_CutCornerClipper oldClipper) => oldClipper.cut != cut;
}

class _CutCornerBorderPainter extends CustomPainter {
  const _CutCornerBorderPainter({required this.cut, required this.color});

  final double cut;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    // 向内收缩半像素，避免描边被裁剪。
    canvas.save();
    canvas.translate(0.5, 0.5);
    canvas.drawPath(_cutCornerPath(size, cut), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CutCornerBorderPainter oldDelegate) =>
      oldDelegate.cut != cut || oldDelegate.color != color;
}

/// HD2 终端风面板卡片：折角（右上角斜切）、panelGrey 底、lineGrey 1px 边。
class HdPanelCard extends StatelessWidget {
  const HdPanelCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(12),
    this.cutSize = 14,
    this.backgroundColor = HdColors.panelGrey,
    this.borderColor = HdColors.lineGrey,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double cutSize;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _CutCornerClipper(cutSize),
      child: CustomPaint(
        painter: _CutCornerBorderPainter(cut: cutSize, color: borderColor),
        child: Material(
          color: backgroundColor,
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// 黄色大写等宽标题 + 左侧竖条的分区标题。
class HdSectionHeader extends StatelessWidget {
  const HdSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Container(width: 4, height: 18, color: HdColors.helldiverYellow),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: HdColors.helldiverYellow,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// HD 按钮样式：黄底黑字 / 黄色描边。
enum HdButtonVariant { filled, outlined }

/// HD2 终端风按钮（右上角小折角）。
class HdButton extends StatelessWidget {
  const HdButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = HdButtonVariant.filled,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final HdButtonVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bool filled = variant == HdButtonVariant.filled;
    final Color foreground =
        filled ? HdColors.voidBlack : HdColors.helldiverYellow;
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 8),
          ],
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
          ),
        ],
      ),
    );
    return ClipPath(
      clipper: const _CutCornerClipper(8),
      child: CustomPaint(
        painter: filled
            ? null
            : const _CutCornerBorderPainter(
                cut: 8, color: HdColors.helldiverYellow),
        child: Material(
          color:
              filled ? HdColors.helldiverYellow : HdColors.panelGrey,
          child: InkWell(onTap: onPressed, child: content),
        ),
      ),
    );
  }
}

/// 居中加载视图。
class HdLoadingView extends StatelessWidget {
  const HdLoadingView({super.key, this.message = '数据加载中…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: HdColors.dimGrey),
          ),
        ],
      ),
    );
  }
}

/// 错误视图（带重试按钮）。
class HdErrorView extends StatelessWidget {
  const HdErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline,
                color: HdColors.alertRed, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            HdButton(
              label: '重试',
              icon: Icons.refresh,
              variant: HdButtonVariant.outlined,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// HD2 终端风搜索栏。
class HdSearchBar extends StatelessWidget {
  const HdSearchBar({
    super.key,
    this.controller,
    this.hintText = '搜索条目…',
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.autofocus = false,
    this.readOnly = false,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool autofocus;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const _CutCornerClipper(10),
      child: Container(
        color: HdColors.panelGrey,
        child: CustomPaint(
          painter:
              const _CutCornerBorderPainter(cut: 10, color: HdColors.lineGrey),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            onTap: onTap,
            autofocus: autofocus,
            readOnly: readOnly,
            style: const TextStyle(color: HdColors.textPrimary),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(color: HdColors.dimGrey),
              prefixIcon:
                  const Icon(Icons.search, color: HdColors.helldiverYellow),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
      ),
    );
  }
}
