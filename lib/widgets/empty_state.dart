import 'package:flutter/material.dart';
import '../theme/eleghart_colors.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            size: 72,
            color: EleghartColors.textSecondary,
          ),
          const SizedBox(height: 20),
          const Text(
            'No expenses yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: EleghartColors.textPrimary,
            ),
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
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Add your first expense'),
              style: ElevatedButton.styleFrom(
                backgroundColor: EleghartColors.accentDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
