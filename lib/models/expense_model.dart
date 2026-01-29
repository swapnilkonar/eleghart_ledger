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
    );
  }

  /// Optional helper getters (useful for UI + PDF later)
  bool get isDebit => type == 'debit';
  bool get isCredit => type == 'credit';
}
