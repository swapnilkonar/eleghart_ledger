enum UdhaarTransactionType { collection, payment }

class LedgerTransactionModel {
  final String id;
  final String personId;
  final UdhaarTransactionType type;
  final double amount;
  final String description;
  final String? category;
  final String? attachmentPath;
  final String? notes;
  final DateTime transactionDate;
  final DateTime createdAt;

  const LedgerTransactionModel({
    required this.id,
    required this.personId,
    required this.type,
    required this.amount,
    required this.description,
    this.category,
    this.attachmentPath,
    this.notes,
    required this.transactionDate,
    required this.createdAt,
  });

  bool get isCollection => type == UdhaarTransactionType.collection;
  bool get isPayment => type == UdhaarTransactionType.payment;

  Map<String, dynamic> toJson() => {
        'id': id,
        'personId': personId,
        'type': type.name,
        'amount': amount,
        'description': description,
        'category': category,
        'attachmentPath': attachmentPath,
        'notes': notes,
        'transactionDate': transactionDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory LedgerTransactionModel.fromJson(Map<String, dynamic> json) =>
      LedgerTransactionModel(
        id: json['id'] as String,
        personId: json['personId'] as String,
        type: UdhaarTransactionType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => UdhaarTransactionType.collection,
        ),
        amount: (json['amount'] as num).toDouble(),
        description: json['description'] as String? ?? '',
        category: json['category'] as String?,
        attachmentPath: json['attachmentPath'] as String?,
        notes: json['notes'] as String?,
        transactionDate: DateTime.parse(json['transactionDate'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
