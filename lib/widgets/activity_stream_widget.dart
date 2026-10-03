import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/splitwise_models.dart';
import '../services/firestore_split_service.dart';

class ActivityStreamWidget extends StatelessWidget {
  final String groupId;

  const ActivityStreamWidget({
    super.key,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SplitwiseActivityModel>>(
      stream: FirestoreSplitService().streamGroupActivities(groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final activities = snapshot.data ?? [];
        if (activities.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24.0),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.history,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  'No recent activity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Expenses & settlements will appear here',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: activities.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final activity = activities[index];
            return _buildActivityCard(context, activity);
          },
        );
      },
    );
  }

  Widget _buildActivityCard(BuildContext context, SplitwiseActivityModel activity) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    IconData icon;
    Color iconBgColor;
    Color iconColor;

    switch (activity.type) {
      case 'EXPENSE_CREATED':
        icon = Icons.add_shopping_cart_rounded;
        iconBgColor = const Color(0xFFE3F2FD);
        iconColor = const Color(0xFF1976D2);
        break;
      case 'EXPENSE_UPDATED':
        icon = Icons.edit_note_rounded;
        iconBgColor = const Color(0xFFFFF3E0);
        iconColor = const Color(0xFFF57C00);
        break;
      case 'EXPENSE_DELETED':
        icon = Icons.delete_outline_rounded;
        iconBgColor = const Color(0xFFFFEBEE);
        iconColor = const Color(0xFFD32F2F);
        break;
      case 'PAYMENT_CREATED':
      case 'PAYMENT_UPDATED':
        icon = Icons.payments_rounded;
        iconBgColor = const Color(0xE8E8F5E9);
        iconColor = const Color(0xFF388E3C);
        break;
      case 'MEMBER_JOINED':
      default:
        icon = Icons.group_add_rounded;
        iconBgColor = const Color(0xFFF3E5F5);
        iconColor = const Color(0xFF7B1FA2);
        break;
    }

    final formattedTime = DateFormat('MMM d, h:mm a').format(activity.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      padding: const EdgeInsets.all(12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: iconBgColor,
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        activity.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    Text(
                      formattedTime,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  activity.body,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
