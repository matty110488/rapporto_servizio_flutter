import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppCardVariant { plain, outlined }

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
