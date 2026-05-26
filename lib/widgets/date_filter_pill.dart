import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_theme.dart';
import '../theme/eleghart_colors.dart';
import '../utils/date_filter.dart';

class DateFilterPill extends StatefulWidget {
  const DateFilterPill({super.key});

  @override
  State<DateFilterPill> createState() => _DateFilterPillState();
}

class _DateFilterPillState extends State<DateFilterPill> {
  @override
  void initState() {
    super.initState();
    DateFilter.notifier.addListener(_onFilterChanged);
    AppThemeNotifier.instance.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    DateFilter.notifier.removeListener(_onFilterChanged);
    AppThemeNotifier.instance.removeListener(_onFilterChanged);
    super.dispose();
  }

  void _onFilterChanged() => setState(() {});

  void _openPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppThemeNotifier.isWhite ? Colors.white : const Color(0xFF120404),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => _FilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFCC0020).withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: const Color(0xFFCC0020).withOpacity(0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_rounded,
                size: 13, color: Color(0xFFCC0020)),
            const SizedBox(width: 5),
            Text(
              DateFilter.label,
              style: GoogleFonts.sora(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 14, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.6) : Colors.white54),
          ],
        ),
      ),
    );
  }
}

// ── Filter bottom sheet ───────────────────────────────────────────────────────
class _FilterSheet extends StatefulWidget {
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  // null = preset view, non-null = custom picker view
  int? _pickerYear;
  final int _nowYear = DateTime.now().year;
  final int _nowMonth = DateTime.now().month;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _labelFor(DateFilterType type) {
    final now = DateTime.now();
    switch (type) {
      case DateFilterType.currentMonth:
        return 'Current Month (${DateFilter.monthName(now.month, now.year)})';
      case DateFilterType.lastMonth:
        final last = DateTime(now.year, now.month - 1);
        return 'Last Month (${DateFilter.monthName(last.month, last.year)})';
      case DateFilterType.allTime:
        return 'All Time';
      case DateFilterType.custom:
        if (DateFilter.customMonth != null) {
          return DateFilter.monthName(
              DateFilter.customMonth!.month, DateFilter.customMonth!.year);
        }
        return 'Picked Month';
    }
  }

  IconData _iconFor(DateFilterType type) {
    switch (type) {
      case DateFilterType.currentMonth:
        return Icons.today_rounded;
      case DateFilterType.lastMonth:
        return Icons.history_rounded;
      case DateFilterType.allTime:
        return Icons.all_inclusive_rounded;
      case DateFilterType.custom:
        return Icons.calendar_month_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.25) : Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          if (_pickerYear == null) _buildPresetList() else _buildMonthGrid(),
        ],
      ),
    );
  }

  Widget _buildPresetList() {
    // Only show the 3 quick presets (not "custom" in the list — that's the "Choose Month" button)
    final quickTypes = [
      DateFilterType.currentMonth,
      DateFilterType.lastMonth,
      DateFilterType.allTime,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Filter by Period',
            style: GoogleFonts.sora(
                fontSize: 16, fontWeight: FontWeight.w700, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white)),
        const SizedBox(height: 20),
        ...quickTypes.map((type) {
          final isSelected = DateFilter.current == type;
          return GestureDetector(
            onTap: () {
              DateFilter.notifier.value = type;
              Navigator.pop(context);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFCC0020).withOpacity(0.10)
                    : (AppThemeNotifier.isWhite ? Colors.white : Colors.white.withOpacity(0.05)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFCC0020).withOpacity(0.6)
                      : (AppThemeNotifier.isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.10)),
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: (!isSelected && AppThemeNotifier.isWhite) ? [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 1))] : [],
              ),
              child: Row(
                children: [
                  Icon(_iconFor(type),
                      size: 18,
                      color: isSelected
                          ? const Color(0xFFCC0020)
                          : (AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.45) : Colors.white38)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_labelFor(type),
                        style: GoogleFonts.sora(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white,
                        )),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_rounded,
                        color: Color(0xFFCC0020), size: 18),
                ],
              ),
            ),
          );
        }),
        // Choose custom month button
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => setState(() => _pickerYear = _nowYear),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: DateFilter.current == DateFilterType.custom
                  ? const Color(0xFFCC0020).withOpacity(0.10)
                  : (AppThemeNotifier.isWhite ? Colors.white : Colors.white.withOpacity(0.05)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DateFilter.current == DateFilterType.custom
                    ? const Color(0xFFCC0020).withOpacity(0.6)
                    : (AppThemeNotifier.isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.10)),
                width: DateFilter.current == DateFilterType.custom ? 1.5 : 1,
              ),
              boxShadow: (DateFilter.current != DateFilterType.custom && AppThemeNotifier.isWhite) ? [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 1))] : [],
            ),
            child: Row(
              children: [
                Icon(Icons.edit_calendar_rounded,
                    size: 18,
                    color: DateFilter.current == DateFilterType.custom
                        ? const Color(0xFFCC0020)
                        : (AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.45) : Colors.white38)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateFilter.current == DateFilterType.custom
                        ? _labelFor(DateFilterType.custom)
                        : 'Pick a Month...',
                    style: GoogleFonts.sora(
                        fontSize: 14,
                        fontWeight: DateFilter.current == DateFilterType.custom
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white),
                  ),
                ),
                if (DateFilter.current == DateFilterType.custom)
                  const Icon(Icons.check_rounded,
                      color: Color(0xFFCC0020), size: 18)
                else
                  Icon(Icons.chevron_right_rounded,
                      color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.3) : Colors.white24, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthGrid() {
    // Year tabs: from 3 years ago up to 2 years ahead
    final years = List.generate(6, (i) => _nowYear - 3 + i);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _pickerYear = null),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppThemeNotifier.isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.07),
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white54, size: 14),
              ),
            ),
            const SizedBox(width: 12),
            Text('Pick a Month',
                style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white)),
          ],
        ),
        const SizedBox(height: 16),

        // Year chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: years.map((y) {
              final active = _pickerYear == y;
              return GestureDetector(
                onTap: () => setState(() => _pickerYear = y),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFFCC0020).withOpacity(0.18)
                        : (AppThemeNotifier.isWhite ? Colors.white : Colors.white.withOpacity(0.06)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active
                          ? const Color(0xFFCC0020)
                          : (AppThemeNotifier.isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.15)),
                      width: active ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    '$y',
                    style: GoogleFonts.sora(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : (AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white54)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Month grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 12,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2,
          ),
          itemBuilder: (_, i) {
            final month = i + 1;
            final isFuture = false; // allow all months including future
            final isCustomSelected = DateFilter.current ==
                    DateFilterType.custom &&
                DateFilter.customMonth?.year == _pickerYear &&
                DateFilter.customMonth?.month == month;

            return GestureDetector(
              onTap: isFuture
                  ? null
                  : () {
                      DateFilter.setCustomMonth(_pickerYear!, month);
                      Navigator.pop(context);
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isCustomSelected
                      ? const Color(0xFFCC0020).withOpacity(0.12)
                      : isFuture
                          ? (AppThemeNotifier.isWhite ? Colors.grey.withOpacity(0.06) : Colors.white.withOpacity(0.02))
                          : (AppThemeNotifier.isWhite ? Colors.white : Colors.white.withOpacity(0.06)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isCustomSelected
                        ? const Color(0xFFCC0020)
                        : (AppThemeNotifier.isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.10)),
                    width: isCustomSelected ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    _months[i],
                    style: GoogleFonts.sora(
                      fontSize: 13,
                      fontWeight: isCustomSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isFuture
                          ? (AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.2) : Colors.white12)
                          : isCustomSelected
                              ? Colors.white
                              : (AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white70),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
