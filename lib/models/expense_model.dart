class ExpenseModel {
  final String id;
  final String groupId;
  final double amount;
  final String description;
  final List<String> categories;
  final DateTime date;
  final String? imagePath;

  /// Transaction type → 'debit' | 'credit'
  final String type;

  /// Custom distribution: member/category → amount owed.
  /// null = equal split (default, backward-compatible).
  final Map<String, double>? distribution;

  /// Multi-payer breakdown: member → amount paid (e.g. {"Swapnil": 1000.0, "Rahul": 500.0})
  final Map<String, double>? paidBy;

  /// Split method → 'equal' | 'exact' | 'percentage' | 'shares'
  final String splitType;

  ExpenseModel({
    required this.id,
    required this.groupId,
    required this.amount,
    required this.description,
    required this.categories,
    required this.date,
    this.imagePath,
    this.type = 'debit',
    this.distribution,
    this.paidBy,
    this.splitType = 'equal',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'groupId': groupId,
        'amount': amount,
        'description': description,
        'categories': categories,
        'date': date.toIso8601String(),
        'imagePath': imagePath,
        'type': type,
        'distribution': distribution,
        'paidBy': paidBy,
        'splitType': splitType,
      };

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'],
      groupId: json['groupId'],
      amount: (json['amount'] as num).toDouble(),
      description: json['description'],
      categories: List<String>.from(json['categories'] ?? []),
      date: DateTime.parse(json['date']),
      imagePath: json['imagePath'],
      type: json['type'] ?? 'debit',
      splitType: json['splitType'] ?? 'equal',
      distribution: json['distribution'] != null
          ? Map<String, double>.from(
              (json['distribution'] as Map).map(
                (k, v) => MapEntry(k as String, (v as num).toDouble()),
              ),
            )
          : null,
      paidBy: json['paidBy'] != null
          ? Map<String, double>.from(
              (json['paidBy'] as Map).map(
                (k, v) => MapEntry(k as String, (v as num).toDouble()),
              ),
            )
          : null,
    );
  }

  ExpenseModel copyWith({
    String? groupId,
    double? amount,
    String? description,
    List<String>? categories,
    DateTime? date,
    String? imagePath,
    String? type,
    Object? distribution = _sentinel,
    Object? paidBy = _sentinel,
    String? splitType,
  }) {
    return ExpenseModel(
      id: id,
      groupId: groupId ?? this.groupId,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      categories: categories ?? this.categories,
      date: date ?? this.date,
      imagePath: imagePath ?? this.imagePath,
      type: type ?? this.type,
      splitType: splitType ?? this.splitType,
      distribution: distribution == _sentinel
          ? this.distribution
          : distribution as Map<String, double>?,
      paidBy: paidBy == _sentinel ? this.paidBy : paidBy as Map<String, double>?,
    );
  }

  static const _sentinel = Object();

  bool get isDebit => type == 'debit';
  bool get isCredit => type == 'credit';

  List<String> get validCategories {
    final valid = categories.where((cat) {
      final lower = cat.toLowerCase().trim();
      return lower != 'emi' && lower != 'recurring';
    }).toList();
    return valid.isEmpty ? ['Uncategorized'] : valid;
  }

  double get categoryShare => amount / validCategories.length;

  double shareForCategory(String category) {
    if (distribution != null && distribution!.containsKey(category)) {
      return distribution![category]!;
    }
    return categoryShare;
  }

  /// Get non-null paidBy map (defaults to creator/first category if null)
  Map<String, double> get validPaidBy {
    if (paidBy != null && paidBy!.isNotEmpty) {
      return paidBy!;
    }
    // Fallback: Primary payer from categories or 'You'
    final mainPayer = categories.isNotEmpty ? categories.first : 'You';
    return {mainPayer: amount};
  }

  /// Primary payer display name
  String get primaryPayer {
    final pMap = validPaidBy;
    if (pMap.length == 1) return pMap.keys.first;
    return '${pMap.keys.first} +${pMap.length - 1}';
  }
}
