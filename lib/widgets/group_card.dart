import 'package:flutter/material.dart';
import '../theme/eleghart_colors.dart';

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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: EleghartColors.textPrimary,
          ),
        ),
        subtitle: Text(
          lastExpense,
          style: const TextStyle(
            color: EleghartColors.textSecondary,
          ),
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
    );
  }
}
