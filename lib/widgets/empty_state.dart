import 'package:flutter/material.dart';
import '../theme/eleghart_colors.dart';
import '../theme/glass_theme.dart';
import 'glass_widgets.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassMorphicCard(
        borderRadius: 28,
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            size: 72,
            color: EleghartColors.textSecondary,
          ),
          const SizedBox(height: 20),
          Text(
            'No expenses yet',
            style: GlassTheme.headingMedium.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 10),
          const Text(
            'Start tracking your spending\nby adding your first expense.',
            style: TextStyle(
              fontSize: 15,
              color: EleghartColors.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: 220,
            height: 48,
            child: GlassButton(
              label: 'Add your first expense',
              icon: Icons.add,
              onPressed: () {},
              borderRadius: 14,
            ),
          ),
        ],
        ),
      ),
    );
  }
}
