import 'package:flutter/material.dart';
import '../theme/eleghart_colors.dart';
import '../theme/glass_theme.dart';
import 'glass_widgets.dart';

class GroupCard extends StatelessWidget {
  final String name;
  final String amount;
  final String lastExpense;

  const GroupCard({
    super.key,
    required this.name,
    required this.amount,
    required this.lastExpense,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassMorphicCard(
        borderRadius: 18,
        padding: EdgeInsets.zero,
        child: ListTile(
          title: Text(
            name,
            style: GlassTheme.headingSmall.copyWith(fontSize: 15),
          ),
          subtitle: Text(
            lastExpense,
            style: GlassTheme.bodySmall,
          ),
          trailing: Text(
            amount,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: EleghartColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
