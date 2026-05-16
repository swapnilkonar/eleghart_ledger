// Example implementations for applying glassmorphic effects to other screens
// Copy and adapt these patterns to your screens

// ============================================================
// EXAMPLE 1: Glassmorphic Input Fields (for Create Group Screen)
// ============================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/glass_theme.dart';
import '../theme/eleghart_colors.dart';

class GlassTextField extends StatefulWidget {
  final String label;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final int maxLines;
  final IconData? prefixIcon;

  const GlassTextField({
    Key? key,
    required this.label,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.prefixIcon,
  }) : super(key: key);

  @override
  State<GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<GlassTextField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() => _isFocused = hasFocus);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: _isFocused ? 15 : 12,
              sigmaY: _isFocused ? 15 : 12,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withOpacity(_isFocused ? 0.2 : 0.15),
                border: Border.all(
                  color: _isFocused
                      ? EleghartColors.accentLight.withOpacity(0.4)
                      : Colors.white.withOpacity(0.25),
                  width: _isFocused ? 2 : 1.5,
                ),
              ),
              child: TextField(
                controller: widget.controller,
                keyboardType: widget.keyboardType,
                maxLines: widget.maxLines,
                decoration: InputDecoration(
                  hintText: widget.label,
                  border: InputBorder.none,
                  prefixIcon: widget.prefixIcon != null
                      ? Icon(
                          widget.prefixIcon,
                          color: EleghartColors.accentDark.withOpacity(0.6),
                        )
                      : null,
                  hintStyle: TextStyle(
                    color: EleghartColors.textHint.withOpacity(0.6),
                    letterSpacing: 0.3,
                  ),
                ),
                style: const TextStyle(
                  color: EleghartColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Usage in Create Group Screen:
/*
Column(
  children: [
    GlassTextField(
      label: 'Group Name',
      prefixIcon: Icons.group,
      controller: groupNameController,
    ),
    const SizedBox(height: 16),
    GlassTextField(
      label: 'Description',
      maxLines: 3,
      controller: descriptionController,
    ),
  ],
)
*/

// ============================================================
// EXAMPLE 2: Glassmorphic Dropdown/Selector
// ============================================================

class GlassDropdown<T> extends StatefulWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final Function(T?) onChanged;
  final IconData? icon;

  const GlassDropdown({
    Key? key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.icon,
  }) : super(key: key);

  @override
  State<GlassDropdown<T>> createState() => _GlassDropdownState<T>();
}

class _GlassDropdownState<T> extends State<GlassDropdown<T>> {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withOpacity(0.15),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1.5,
            ),
          ),
          child: DropdownButton<T>(
            value: widget.value,
            items: widget.items,
            onChanged: widget.onChanged,
            isExpanded: true,
            underline: const SizedBox(),
            icon: Icon(
              widget.icon ?? Icons.arrow_drop_down,
              color: EleghartColors.accentDark,
            ),
            dropdownColor: Colors.white.withOpacity(0.95),
            style: const TextStyle(
              color: EleghartColors.textPrimary,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// EXAMPLE 3: Glassmorphic List Tile (for Group Details)
// ============================================================

class GlassListTile extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData leadingIcon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  const GlassListTile({
    Key? key,
    required this.title,
    this.subtitle,
    required this.leadingIcon,
    this.iconColor,
    this.onTap,
    this.trailing,
  }) : super(key: key);

  @override
  State<GlassListTile> createState() => _GlassListTileState();
}

class _GlassListTileState extends State<GlassListTile>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap?.call();
        },
        onTapCancel: () => _controller.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.white.withOpacity(_isHovered ? 0.2 : 0.15),
                  border: Border.all(
                    color: Colors.white.withOpacity(_isHovered ? 0.3 : 0.2),
                    width: 1.5,
                  ),
                  boxShadow: _isHovered
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (widget.iconColor ?? EleghartColors.accentDark)
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        widget.leadingIcon,
                        color: widget.iconColor ?? EleghartColors.accentDark,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: GlassTheme.headingSmall,
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle!,
                              style: GlassTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.trailing != null)
                      widget.trailing!
                    else
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: EleghartColors.textSecondary.withOpacity(0.5),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Usage:
/*
GlassListTile(
  title: 'Total Expenses',
  subtitle: '₹5,240.50',
  leadingIcon: Icons.receipt_long,
  iconColor: Colors.greenAccent,
)
*/

// ============================================================
// EXAMPLE 4: Glassmorphic Section Header
// ============================================================

class GlassSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;

  const GlassSectionHeader({
    Key? key,
    required this.title,
    this.subtitle,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: EleghartColors.accentDark, size: 24),
            const SizedBox(width: 12),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GlassTheme.headingMedium.copyWith(fontSize: 20),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: GlassTheme.bodySmall,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EXAMPLE 5: Animated Counter (for stats)
// ============================================================

class AnimatedCounter extends StatefulWidget {
  final double value;
  final String prefix;
  final String suffix;
  final Duration duration;

  const AnimatedCounter({
    Key? key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 1500),
  }) : super(key: key);

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(begin: _animation.value, end: widget.value)
          .animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          '${widget.prefix}${_animation.value.toStringAsFixed(0)}${widget.suffix}',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: EleghartColors.textPrimary,
          ),
        );
      },
    );
  }
}

// Usage:
/*
AnimatedCounter(
  value: totalExpenses,
  prefix: '₹',
  duration: const Duration(milliseconds: 1000),
)
*/
