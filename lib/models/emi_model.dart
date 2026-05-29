import 'package:uuid/uuid.dart';

class EmiModel {
  final String id;
  final String productName;

  /// Amount per EMI instalment
  final double amount;

  /// Total number of instalments
  final int tenure;

  /// How many have been paid / generated so far
  final int completed;

  final DateTime startDate;
  final String groupId;
  final List<String> categories;
  final String description;

  /// Last date on which an EMI expense was auto-generated
  final DateTime? lastGeneratedDate;

  EmiModel({
    required this.id,
    required this.productName,
    required this.amount,
    required this.tenure,
    required this.completed,
    required this.startDate,
    required this.groupId,
    this.categories = const ['EMI'],
    this.description = '',
    this.lastGeneratedDate,
  });

  factory EmiModel.create({
    required String productName,
    required double amount,
    required int tenure,
    required DateTime startDate,
    required String groupId,
    List<String> categories = const ['EMI'],
    String description = '',
  }) => EmiModel(
    id: const Uuid().v4(),
    productName: productName,
    amount: amount,
    tenure: tenure,
    completed: 0,
    startDate: startDate,
    groupId: groupId,
    categories: categories,
    description: description,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'productName': productName,
    'amount': amount,
    'tenure': tenure,
    'completed': completed,
    'startDate': startDate.toIso8601String(),
    'groupId': groupId,
    'categories': categories,
    'description': description,
    'lastGeneratedDate': lastGeneratedDate?.toIso8601String(),
  };

  factory EmiModel.fromJson(Map<String, dynamic> j) => EmiModel(
    id: j['id'],
    productName: j['productName'],
    amount: (j['amount'] as num).toDouble(),
    tenure: j['tenure'],
    completed: j['completed'] ?? 0,
    startDate: DateTime.parse(j['startDate']),
    groupId: j['groupId'] ?? '',
    categories: j['categories'] != null
        ? (j['categories'] as List<dynamic>).cast<String>()
        : (j['category'] != null ? [j['category'] as String] : ['EMI']),
    description: j['description'] ?? '',
    lastGeneratedDate: j['lastGeneratedDate'] != null
        ? DateTime.parse(j['lastGeneratedDate'])
        : null,
  );

  EmiModel copyWith({
    String? productName,
    double? amount,
    int? tenure,
    int? completed,
    DateTime? startDate,
    String? groupId,
    List<String>? categories,
    String? description,
    Object? lastGeneratedDate = _sentinel,
  }) => EmiModel(
    id: id,
    productName: productName ?? this.productName,
    amount: amount ?? this.amount,
    tenure: tenure ?? this.tenure,
    completed: completed ?? this.completed,
    startDate: startDate ?? this.startDate,
    groupId: groupId ?? this.groupId,
    categories: categories ?? this.categories,
    description: description ?? this.description,
    lastGeneratedDate: lastGeneratedDate == _sentinel
        ? this.lastGeneratedDate
        : lastGeneratedDate as DateTime?,
  );

  int get remaining => (tenure - completed).clamp(0, tenure);
  bool get isCompleted => completed >= tenure;
  double get progress => tenure > 0 ? completed / tenure : 0.0;
  double get totalPaid => completed * amount;
  double get totalRemaining => remaining * amount;

  /// Due date for the next EMI
  DateTime get nextDueDate {
    return DateTime(startDate.year, startDate.month + completed, startDate.day);
  }
}

const _sentinel = Object();
