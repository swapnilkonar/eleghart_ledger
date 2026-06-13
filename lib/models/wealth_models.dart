import 'package:flutter/material.dart';

// ─── Goal Type ────────────────────────────────────────────────────────────────

enum GoalType {
  emergencyFund,
  house,
  car,
  marriage,
  retirement,
  vacation,
  education,
  custom;

  String get label {
    switch (this) {
      case GoalType.emergencyFund:
        return 'Emergency Fund';
      case GoalType.house:
        return 'House';
      case GoalType.car:
        return 'Car';
      case GoalType.marriage:
        return 'Marriage';
      case GoalType.retirement:
        return 'Retirement';
      case GoalType.vacation:
        return 'Vacation';
      case GoalType.education:
        return 'Education';
      case GoalType.custom:
        return 'Custom';
    }
  }

  IconData get icon {
    switch (this) {
      case GoalType.emergencyFund:
        return Icons.shield_rounded;
      case GoalType.house:
        return Icons.home_rounded;
      case GoalType.car:
        return Icons.directions_car_rounded;
      case GoalType.marriage:
        return Icons.favorite_rounded;
      case GoalType.retirement:
        return Icons.beach_access_rounded;
      case GoalType.vacation:
        return Icons.flight_rounded;
      case GoalType.education:
        return Icons.school_rounded;
      case GoalType.custom:
        return Icons.stars_rounded;
    }
  }

  Color get color {
    switch (this) {
      case GoalType.emergencyFund:
        return const Color(0xFF0EA5E9);
      case GoalType.house:
        return const Color(0xFFCC0020);
      case GoalType.car:
        return const Color(0xFF6366F1);
      case GoalType.marriage:
        return const Color(0xFFEC4899);
      case GoalType.retirement:
        return const Color(0xFF22C55E);
      case GoalType.vacation:
        return const Color(0xFFF59E0B);
      case GoalType.education:
        return const Color(0xFF8B5CF6);
      case GoalType.custom:
        return const Color(0xFFE97C00);
    }
  }
}

// ─── Goal Health ──────────────────────────────────────────────────────────────

enum GoalHealth {
  ahead,
  onTrack,
  slightlyBehind,
  critical;

  String get label {
    switch (this) {
      case GoalHealth.ahead:
        return 'Ahead';
      case GoalHealth.onTrack:
        return 'On Track';
      case GoalHealth.slightlyBehind:
        return 'Slightly Behind';
      case GoalHealth.critical:
        return 'Critical';
    }
  }

  Color get color {
    switch (this) {
      case GoalHealth.ahead:
        return const Color(0xFF22C55E);
      case GoalHealth.onTrack:
        return const Color(0xFF22C55E);
      case GoalHealth.slightlyBehind:
        return const Color(0xFFF97316);
      case GoalHealth.critical:
        return const Color(0xFFCC0020);
    }
  }

  String get emoji {
    switch (this) {
      case GoalHealth.ahead:
        return '🟢';
      case GoalHealth.onTrack:
        return '🟡';
      case GoalHealth.slightlyBehind:
        return '🟠';
      case GoalHealth.critical:
        return '🔴';
    }
  }
}

// ─── WealthGoal ───────────────────────────────────────────────────────────────

class WealthGoal {
  final String id;
  final String name;
  final GoalType goalType;
  final double targetAmount;
  final double currentAmount;
  final double startAmount;
  final DateTime targetDate;
  final String? notes;
  final DateTime createdAt;

  const WealthGoal({
    required this.id,
    required this.name,
    required this.goalType,
    required this.targetAmount,
    required this.currentAmount,
    required this.startAmount,
    required this.targetDate,
    this.notes,
    required this.createdAt,
  });

  double get progress =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
  double get progressPercent => progress * 100;
  double get remaining =>
      (targetAmount - currentAmount).clamp(0.0, double.infinity);

  WealthGoal copyWith({
    String? name,
    GoalType? goalType,
    double? targetAmount,
    double? currentAmount,
    double? startAmount,
    DateTime? targetDate,
    String? notes,
  }) {
    return WealthGoal(
      id: id,
      name: name ?? this.name,
      goalType: goalType ?? this.goalType,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      startAmount: startAmount ?? this.startAmount,
      targetDate: targetDate ?? this.targetDate,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'goal_type': goalType.name,
        'target_amount': targetAmount,
        'current_amount': currentAmount,
        'start_amount': startAmount,
        'target_date': targetDate.toIso8601String(),
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory WealthGoal.fromMap(Map<String, dynamic> m) => WealthGoal(
        id: m['id'] as String,
        name: m['name'] as String,
        goalType: GoalType.values.firstWhere(
          (e) => e.name == m['goal_type'],
          orElse: () => GoalType.custom,
        ),
        targetAmount: (m['target_amount'] as num).toDouble(),
        currentAmount: (m['current_amount'] as num).toDouble(),
        startAmount: (m['start_amount'] as num).toDouble(),
        targetDate: DateTime.parse(m['target_date'] as String),
        notes: m['notes'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

// ─── WealthContribution ───────────────────────────────────────────────────────

class WealthContribution {
  final String id;
  final String goalId;
  final double amount;
  final DateTime contributionDate;
  final String? notes;
  final DateTime createdAt;

  const WealthContribution({
    required this.id,
    required this.goalId,
    required this.amount,
    required this.contributionDate,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'goal_id': goalId,
        'amount': amount,
        'contribution_date': contributionDate.toIso8601String(),
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory WealthContribution.fromMap(Map<String, dynamic> m) =>
      WealthContribution(
        id: m['id'] as String,
        goalId: m['goal_id'] as String,
        amount: (m['amount'] as num).toDouble(),
        contributionDate:
            DateTime.parse(m['contribution_date'] as String),
        notes: m['notes'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
