class ExpenseModel {
  final String id;
  final String groupId;
  final double amount;
  final String description;
  final List<String> categories;
  final DateTime date;
  final String? imagePath;

  /// NEW: transaction type → 'debit' | 'credit'
  final String type;

  /// Optional custom distribution: member/category → amount.
  /// null = equal split (default, backward-compatible).
  final Map<String, double>? distribution;

  ExpenseModel({
    required this.id,
    required this.groupId,
    required this.amount,
    required this.description,
    required this.categories,
    required this.date,
    this.imagePath,

    /// Default = debit to keep old behavior unchanged
    this.type = 'debit',
    this.distribution,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'groupId': groupId,
        'amount': amount,
        'description': description,
        'categories': categories,
        'date': date.toIso8601String(),
        'imagePath': imagePath,

        /// NEW: persist transaction type
        'type': type,
        'distribution': distribution,
      };

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'],
      groupId: json['groupId'],
      amount: (json['amount'] as num).toDouble(),
      description: json['description'],
      categories: List<String>.from(json['categories']),
      date: DateTime.parse(json['date']),
      imagePath: json['imagePath'],

      /// NEW: backward-compatible fallback
      /// Old expenses won’t have `type` → treat as debit
      type: json['type'] ?? 'debit',
      distribution: json['distribution'] != null
          ? Map<String, double>.from(
              (json['distribution'] as Map).map(
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
      distribution: distribution == _sentinel
          ? this.distribution
          : distribution as Map<String, double>?,
    );
  }

  static const _sentinel = Object();

  /// Optional helper getters (useful for UI + PDF later)
  bool get isDebit => type == 'debit';
  bool get isCredit => type == 'credit';

  /// Filters out system tags so amounts are only split among real categories
  List<String> get validCategories {
    final valid = categories.where((cat) {
      final lower = cat.toLowerCase().trim();
      return lower != 'emi' && lower != 'recurring';
    }).toList();
    // If it only had system tags, bucket it to 'Uncategorized' to avoid division by zero
    return valid.isEmpty ? ['Uncategorized'] : valid;
  }

  /// The amount divided by the number of valid (non-system) categories
  double get categoryShare => amount / validCategories.length;
}
