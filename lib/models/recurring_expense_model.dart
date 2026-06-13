import 'package:uuid/uuid.dart';

class RecurringExpenseModel {
  final String id;
  final String name;
  final double amount;

  /// 'weekly' | 'monthly' | 'quarterly' | 'yearly'
  final String frequency;

  final DateTime startDate;
  final DateTime? endDate;
  final String groupId;
  final List<String> categories;
  final String description;
  final bool isActive;

  /// Last date on which an expense was auto-generated
  final DateTime? lastGeneratedDate;

  /// Optional custom distribution: category → amount.
  /// null = equal split (default, backward-compatible).
  final Map<String, double>? distribution;

  String get category => categories.isNotEmpty ? categories.first : 'Recurring';

  RecurringExpenseModel({
    required this.id,
    required this.name,
    required this.amount,
    required this.frequency,
    required this.startDate,
    this.endDate,
    required this.groupId,
    required this.categories,
    this.description = '',
    this.isActive = true,
    this.lastGeneratedDate,
    this.distribution,
  });

  factory RecurringExpenseModel.create({
    required String name,
    required double amount,
    required String frequency,
    required DateTime startDate,
    DateTime? endDate,
    required String groupId,
    required List<String> categories,
    String description = '',
    Map<String, double>? distribution,
  }) => RecurringExpenseModel(
    id: const Uuid().v4(),
    name: name,
    amount: amount,
    frequency: frequency,
    startDate: startDate,
    endDate: endDate,
    groupId: groupId,
    categories: categories,
    description: description,
    distribution: distribution,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    'frequency': frequency,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'groupId': groupId,
    'categories': categories,
    'description': description,
    'isActive': isActive,
    'lastGeneratedDate': lastGeneratedDate?.toIso8601String(),
    'distribution': distribution,
  };

  factory RecurringExpenseModel.fromJson(Map<String, dynamic> j) =>
      RecurringExpenseModel(
        id: j['id'],
        name: j['name'],
        amount: (j['amount'] as num).toDouble(),
        frequency: j['frequency'],
        startDate: DateTime.parse(j['startDate']),
        endDate: j['endDate'] != null ? DateTime.parse(j['endDate']) : null,
        groupId: j['groupId'] ?? '',
        categories: j['categories'] != null
            ? (j['categories'] as List<dynamic>).cast<String>()
            : (j['category'] != null ? [j['category'] as String] : []),
        description: j['description'] ?? '',
        isActive: j['isActive'] ?? true,
        lastGeneratedDate: j['lastGeneratedDate'] != null
            ? DateTime.parse(j['lastGeneratedDate'])
            : null,
        distribution: j['distribution'] != null
            ? Map<String, double>.from(
                (j['distribution'] as Map).map(
                  (k, v) => MapEntry(k as String, (v as num).toDouble()),
                ),
              )
            : null,
      );

  RecurringExpenseModel copyWith({
    String? name,
    double? amount,
    String? frequency,
    DateTime? startDate,
    Object? endDate = _sentinel,
    String? groupId,
    List<String>? categories,
    String? description,
    bool? isActive,
    Object? lastGeneratedDate = _sentinel,
    Object? distribution = _sentinel,
  }) => RecurringExpenseModel(
    id: id,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    frequency: frequency ?? this.frequency,
    startDate: startDate ?? this.startDate,
    endDate: endDate == _sentinel ? this.endDate : endDate as DateTime?,
    groupId: groupId ?? this.groupId,
    categories: categories ?? this.categories,
    description: description ?? this.description,
    isActive: isActive ?? this.isActive,
    lastGeneratedDate: lastGeneratedDate == _sentinel
        ? this.lastGeneratedDate
        : lastGeneratedDate as DateTime?,
    distribution: distribution == _sentinel
        ? this.distribution
        : distribution as Map<String, double>?,
  );

  /// Frequency display label
  String get frequencyLabel {
    switch (frequency) {
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      case 'quarterly':
        return 'Quarterly';
      case 'yearly':
        return 'Yearly';
      default:
        return frequency;
    }
  }

  /// Next due date after [from]
  DateTime nextDueDate(DateTime from) {
    var d = startDate;
    while (!d.isAfter(from)) {
      d = _advance(d);
    }
    return d;
  }

  DateTime _advance(DateTime d) {
    switch (frequency) {
      case 'weekly':
        return d.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(d.year, d.month + 1, d.day);
      case 'quarterly':
        return DateTime(d.year, d.month + 3, d.day);
      case 'yearly':
        return DateTime(d.year + 1, d.month, d.day);
      default:
        return DateTime(d.year, d.month + 1, d.day);
    }
  }
}

const _sentinel = Object();
