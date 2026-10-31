import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppCardVariant { plain, outlined }

class ValtellinaBackground extends StatelessWidget {
  const ValtellinaBackground({super.key, required this.child});

  final Widget child;

  static Widget builder(BuildContext context, Widget? child) {
    return ValtellinaBackground(child: child ?? const SizedBox.shrink());
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(
          key: ValueKey('valtellina-background-paint-boundary'),
          child: IgnorePointer(
            child: CustomPaint(
              key: ValueKey('valtellina-background-art'),
              painter: _ValtellinaBackgroundPainter(),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _ValtellinaBackgroundPainter extends CustomPainter {
  const _ValtellinaBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final background = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFEAF2FB),
        Color(0xFFE7F0FB),
        Color(0xFFDCEBFA),
      ],
      stops: [0, 0.52, 1],
    ).createShader(bounds);
    canvas.drawRect(bounds, Paint()..shader = background);

    final mountainWidth = (size.width * 0.80).clamp(260.0, 800.0);
    final mountainHeight = (size.height * 0.24).clamp(145.0, 230.0);
    final left = size.width - mountainWidth;
    final fadeBottom = mountainHeight * 1.24;
    final mountainBounds = Rect.fromLTWH(
      left,
      0,
      mountainWidth,
      fadeBottom,
    );

    final rear = Path()
      ..moveTo(left + mountainWidth * 0.08, mountainHeight * 0.78)
      ..cubicTo(
        left + mountainWidth * 0.15,
        mountainHeight * 0.68,
        left + mountainWidth * 0.20,
        mountainHeight * 0.43,
        left + mountainWidth * 0.27,
        mountainHeight * 0.36,
      )
      ..quadraticBezierTo(
        left + mountainWidth * 0.32,
        mountainHeight * 0.43,
        left + mountainWidth * 0.37,
        mountainHeight * 0.58,
      )
      ..cubicTo(
        left + mountainWidth * 0.44,
        mountainHeight * 0.47,
        left + mountainWidth * 0.49,
        mountainHeight * 0.20,
        left + mountainWidth * 0.54,
        mountainHeight * 0.13,
      )
      ..quadraticBezierTo(
        left + mountainWidth * 0.59,
        mountainHeight * 0.25,
        left + mountainWidth * 0.64,
        mountainHeight * 0.51,
      )
      ..cubicTo(
        left + mountainWidth * 0.71,
        mountainHeight * 0.43,
        left + mountainWidth * 0.76,
        mountainHeight * 0.30,
        left + mountainWidth * 0.81,
        mountainHeight * 0.27,
      )
      ..quadraticBezierTo(
        left + mountainWidth * 0.89,
        mountainHeight * 0.45,
        size.width,
        mountainHeight * 0.63,
      )
      ..lineTo(size.width, fadeBottom)
      ..lineTo(left + mountainWidth * 0.08, fadeBottom)
      ..close();
    canvas.drawPath(
      rear,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x2CFFFFFF),
            Color(0x20FFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: [0, 0.52, 1],
        ).createShader(mountainBounds),
    );

    final middle = Path()
      ..moveTo(left + mountainWidth * 0.22, mountainHeight * 0.88)
      ..cubicTo(
        left + mountainWidth * 0.31,
        mountainHeight * 0.75,
        left + mountainWidth * 0.37,
        mountainHeight * 0.50,
        left + mountainWidth * 0.43,
        mountainHeight * 0.46,
      )
      ..quadraticBezierTo(
        left + mountainWidth * 0.49,
        mountainHeight * 0.57,
        left + mountainWidth * 0.54,
        mountainHeight * 0.68,
      )
      ..cubicTo(
        left + mountainWidth * 0.62,
        mountainHeight * 0.56,
        left + mountainWidth * 0.68,
        mountainHeight * 0.34,
        left + mountainWidth * 0.73,
        mountainHeight * 0.31,
      )
      ..quadraticBezierTo(
        left + mountainWidth * 0.80,
        mountainHeight * 0.47,
        left + mountainWidth * 0.84,
        mountainHeight * 0.62,
      )
      ..quadraticBezierTo(
        left + mountainWidth * 0.93,
        mountainHeight * 0.65,
        size.width,
        mountainHeight * 0.75,
      )
      ..lineTo(size.width, fadeBottom)
      ..lineTo(left + mountainWidth * 0.22, fadeBottom)
      ..close();
    canvas.drawPath(
      middle,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x165F7F9F),
            Color(0x0E5F7F9F),
            Color(0x005F7F9F),
          ],
          stops: [0, 0.58, 1],
        ).createShader(mountainBounds),
    );

    final front = Path()
      ..moveTo(left + mountainWidth * 0.40, mountainHeight * 0.94)
      ..cubicTo(
        left + mountainWidth * 0.49,
        mountainHeight * 0.84,
        left + mountainWidth * 0.57,
        mountainHeight * 0.66,
        left + mountainWidth * 0.62,
        mountainHeight * 0.63,
      )
      ..quadraticBezierTo(
        left + mountainWidth * 0.68,
        mountainHeight * 0.70,
        left + mountainWidth * 0.72,
        mountainHeight * 0.80,
      )
      ..cubicTo(
        left + mountainWidth * 0.79,
        mountainHeight * 0.72,
        left + mountainWidth * 0.85,
        mountainHeight * 0.55,
        left + mountainWidth * 0.90,
        mountainHeight * 0.53,
      )
      ..quadraticBezierTo(
        left + mountainWidth * 0.96,
        mountainHeight * 0.63,
        size.width,
        mountainHeight * 0.72,
      )
      ..lineTo(size.width, fadeBottom)
      ..lineTo(left + mountainWidth * 0.40, fadeBottom)
      ..close();
    canvas.drawPath(
      front,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x12496B8D),
            Color(0x0B496B8D),
            Color(0x00496B8D),
          ],
          stops: [0, 0.60, 1],
        ).createShader(mountainBounds),
    );
  }

  @override
  bool shouldRepaint(covariant _ValtellinaBackgroundPainter oldDelegate) =>
      false;
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.sm),
    this.variant = AppCardVariant.plain,
    this.showShadow = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final AppCardVariant variant;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final side = variant == AppCardVariant.outlined
        ? const BorderSide(
            color: AppColors.cardOutline,
            width: AppStrokes.thin,
          )
        : BorderSide.none;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
      side: side,
    );
    final content = Padding(padding: padding, child: child);

    return Material(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: showShadow ? 0.5 : 0,
      shadowColor: const Color(0x1417263C),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              overlayColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.pressed)
                    ? AppColors.cardPressed
                    : null,
              ),
              child: content,
            ),
    );
  }
}

class AppHorizontalScrollHint extends StatefulWidget {
  const AppHorizontalScrollHint({
    super.key,
    required this.child,
    this.backgroundColor = AppColors.background,
  });

  final Widget child;
  final Color backgroundColor;

  @override
  State<AppHorizontalScrollHint> createState() =>
      _AppHorizontalScrollHintState();
}

class _AppHorizontalScrollHintState extends State<AppHorizontalScrollHint> {
  final ScrollController _controller = ScrollController();
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateHint);
    _scheduleHintUpdate();
  }

  @override
  void didUpdateWidget(covariant AppHorizontalScrollHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleHintUpdate();
  }

  void _scheduleHintUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateHint();
    });
  }

  void _updateHint() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final show = position.maxScrollExtent > 0.5 &&
        position.pixels < position.maxScrollExtent - 0.5;
    if (show == _showHint || !mounted) return;
    setState(() => _showHint = show);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_updateHint)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: widget.child,
        ),
        if (_showHint)
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Container(
                  key: const ValueKey('horizontal-scroll-hint'),
                  width: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        widget.backgroundColor.withValues(alpha: 0),
                        widget.backgroundColor.withValues(alpha: 0.94),
                      ],
                    ),
                  ),
                  alignment: Alignment.centerRight,
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin,
    this.borderRadius = AppRadii.large,
    this.color = AppColors.surface,
    this.showShadow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color color;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: showShadow
            ? const [
                BoxShadow(
                  color: Color(0x0F17263C),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: icon == null
          ? null
          : Icon(
              icon,
              size: 17,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
      label: Text(label),
      showCheckmark: false,
      selected: selected,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.compact,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.border,
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      onSelected: onSelected,
    );
  }
}

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 26),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}
