import '../models/wealth_models.dart';

class WealthService {
  // ─── Health Calculation ────────────────────────────────────────────────────

  static GoalHealth calculateHealth(WealthGoal goal) {
    final exp = expectedSaved(goal);
    if (exp <= 0) return GoalHealth.onTrack;
    final ratio = (goal.currentAmount / exp) * 100;
    if (ratio >= 110) return GoalHealth.ahead;
    if (ratio >= 95) return GoalHealth.onTrack;
    if (ratio >= 75) return GoalHealth.slightlyBehind;
    return GoalHealth.critical;
  }

  // ─── Monthly Required ──────────────────────────────────────────────────────

  static double calculateMonthlyRequired(WealthGoal goal) {
    final now = DateTime.now();
    final remaining =
        (goal.targetAmount - goal.currentAmount).clamp(0.0, double.infinity);
    final monthsLeft =
        goal.targetDate.difference(now).inDays / 30.4375;
    if (monthsLeft <= 0) return remaining;
    if (remaining <= 0) return 0;
    return remaining / monthsLeft;
  }

  // ─── Timeline Helpers ─────────────────────────────────────────────────────

  static int elapsedMonths(WealthGoal goal) {
    final now = DateTime.now();
    return ((now.difference(goal.createdAt).inDays) / 30.4375)
        .floor()
        .clamp(0, 999);
  }

  static int remainingMonths(WealthGoal goal) {
    final now = DateTime.now();
    final days = goal.targetDate.difference(now).inDays;
    return (days / 30.4375).ceil().clamp(0, 999);
  }

  static int totalMonths(WealthGoal goal) {
    return ((goal.targetDate.difference(goal.createdAt).inDays) /
            30.4375)
        .round()
        .clamp(1, 999);
  }

  static double expectedSaved(WealthGoal goal) {
    final total = totalMonths(goal);
    if (total <= 0) return goal.targetAmount;
    // Use at least 1 month so brand-new goals show the first month's target
    final elapsed = elapsedMonths(goal).clamp(1, total);
    final ratio = elapsed / total;
    return (goal.startAmount +
            (goal.targetAmount - goal.startAmount) * ratio)
        .clamp(0.0, goal.targetAmount);
  }

  static double gap(WealthGoal goal) {
    final exp = expectedSaved(goal);
    return (exp - goal.currentAmount).clamp(0.0, double.infinity);
  }

  // ─── AI Coach Message ─────────────────────────────────────────────────────

  static String coachMessage(WealthGoal goal) {
    final health = calculateHealth(goal);
    final monthly = calculateMonthlyRequired(goal);
    final elapsed = elapsedMonths(goal);
    final total = totalMonths(goal);
    final g = gap(goal);

    switch (health) {
      case GoalHealth.ahead:
        if (monthly <= 0) {
          return 'Congratulations! You have achieved your goal. 🎉';
        }
        final earlyEstimate =
            ((goal.currentAmount - expectedSaved(goal)) / monthly)
                .round()
                .clamp(0, 99);
        return earlyEstimate > 0
            ? 'You are ahead of schedule! At this pace, you may achieve your goal $earlyEstimate months early.'
            : 'Great work! You\'re ahead of schedule. Keep it up!';

      case GoalHealth.onTrack:
        return 'You\'re right on track. Save ${formatAmount(monthly)} this month to stay on course.';

      case GoalHealth.slightlyBehind:
        return 'You are behind by ${formatAmount(g)}. Save ${formatAmount(monthly)} this month to get back on track.';

      case GoalHealth.critical:
        return 'You are behind by ${formatAmount(g)}. To achieve your goal on time, save ${formatAmount(monthly)} per month.';
    }
  }

  // ─── Amount Formatter ─────────────────────────────────────────────────────

  static String formatAmount(double v) {
    if (v >= 10000000) {
      return '₹${(v / 10000000).toStringAsFixed(v % 10000000 == 0 ? 0 : 2)}Cr';
    }
    if (v >= 100000) {
      return '₹${(v / 100000).toStringAsFixed(v % 100000 == 0 ? 0 : 1)}L';
    }
    if (v >= 1000) {
      return '₹${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}K';
    }
    return '₹${v.toStringAsFixed(0)}';
  }

  static String formatAmountFull(double v) {
    if (v >= 10000000) {
      return '₹${(v / 10000000).toStringAsFixed(2)}Cr';
    }
    if (v >= 100000) {
      return '₹${(v / 100000).toStringAsFixed(2)}L';
    }
    return '₹${v.toStringAsFixed(0)}';
  }
}
