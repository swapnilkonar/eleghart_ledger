import 'dart:convert';

class SplitwiseGroupModel {
  final String id;
  final String name;
  final List<String> members;
  final DateTime createdAt;
  final String? imagePath;

  SplitwiseGroupModel({
    required this.id,
    required this.name,
    required this.members,
    required this.createdAt,
    this.imagePath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'members': members,
        'createdAt': createdAt.toIso8601String(),
        'imagePath': imagePath,
      };

  factory SplitwiseGroupModel.fromJson(Map<String, dynamic> json) {
    return SplitwiseGroupModel(
      id: json['id'],
      name: json['name'],
      members: json['members'] != null
          ? List<String>.from(json['members'])
          : const ['You'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      imagePath: json['imagePath'],
    );
  }

  SplitwiseGroupModel copyWith({
    String? name,
    List<String>? members,
    String? imagePath,
  }) {
    return SplitwiseGroupModel(
      id: id,
      name: name ?? this.name,
      members: members ?? this.members,
      createdAt: createdAt,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}

class SplitwiseExpenseModel {
  final String id;
  final String splitwiseGroupId;
  final String title;
  final double amount;
  final DateTime date;
  final String splitType; // 'equal', 'exact', 'percentage', 'shares'
  final Map<String, double> paidBy; // member -> amount paid
  final Map<String, double> distribution; // member -> amount owed

  SplitwiseExpenseModel({
    required this.id,
    required this.splitwiseGroupId,
    required this.title,
    required this.amount,
    required this.date,
    this.splitType = 'equal',
    required this.paidBy,
    required this.distribution,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'splitwiseGroupId': splitwiseGroupId,
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
        'splitType': splitType,
        'paidBy': paidBy,
        'distribution': distribution,
      };

  factory SplitwiseExpenseModel.fromJson(Map<String, dynamic> json) {
    return SplitwiseExpenseModel(
      id: json['id'],
      splitwiseGroupId: json['splitwiseGroupId'],
      title: json['title'],
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date']),
      splitType: json['splitType'] ?? 'equal',
      paidBy: json['paidBy'] != null
          ? Map<String, double>.from((json['paidBy'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())))
          : {'You': (json['amount'] as num).toDouble()},
      distribution: json['distribution'] != null
          ? Map<String, double>.from((json['distribution'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())))
          : {},
    );
  }

  /// Helper: Primary payer name
  String get primaryPayer {
    if (paidBy.isEmpty) return 'You';
    if (paidBy.length == 1) return paidBy.keys.first;
    return '${paidBy.keys.first} +${paidBy.length - 1}';
  }
}
