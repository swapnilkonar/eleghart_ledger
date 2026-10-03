
class SplitwiseGroupModel {
  final String id;
  final String name;
  final List<String> members; // Display names
  final List<String> memberUids; // Firebase UIDs
  final List<String> memberEmails; // Member Google Emails (for instant bootstrap auto-matching)
  final String inviteCode; // Unique 6-character group join code (e.g. GOA-8492)
  final String currency; // Default Base Currency (INR, USD, EUR, etc.)
  final String createdBy;
  final DateTime createdAt;
  final String? imagePath;

  SplitwiseGroupModel({
    required this.id,
    required this.name,
    required this.members,
    this.memberUids = const [],
    this.memberEmails = const [],
    this.inviteCode = '',
    this.currency = 'INR',
    this.createdBy = '',
    DateTime? createdAt,
    this.imagePath,
  }) : createdAt = createdAt ?? DateTime.now();

  String get effectiveInviteCode {
    if (inviteCode.isNotEmpty) return inviteCode;
    final prefix = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final cleanPrefix = prefix.isEmpty
        ? 'SPL'
        : (prefix.length >= 3 ? prefix.substring(0, 3) : prefix.padRight(3, 'X'));
    final codeNum = (1000 + (id.hashCode % 8999).abs());
    return '$cleanPrefix-$codeNum';
  }

  String get currencySymbol {
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'AED':
        return 'AED ';
      case 'THB':
        return '฿';
      case 'JPY':
        return '¥';
      case 'CAD':
        return 'CA\$';
      case 'AUD':
        return 'A\$';
      case 'SGD':
        return 'S\$';
      case 'INR':
      default:
        return '₹';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'members': members,
        'memberUids': memberUids,
        'memberEmails': memberEmails,
        'inviteCode': inviteCode,
        'currency': currency,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'imagePath': imagePath,
      };

  factory SplitwiseGroupModel.fromJson(Map<String, dynamic> json) {
    return SplitwiseGroupModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      members: json['members'] != null
          ? List<String>.from(json['members'])
          : const ['You'],
      memberUids: json['memberUids'] != null
          ? List<String>.from(json['memberUids'])
          : const [],
      memberEmails: json['memberEmails'] != null
          ? List<String>.from(json['memberEmails'])
          : const [],
      inviteCode: json['inviteCode'] ?? '',
      currency: json['currency'] ?? 'INR',
      createdBy: json['createdBy'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      imagePath: json['imagePath'],
    );
  }

  SplitwiseGroupModel copyWith({
    String? name,
    List<String>? members,
    List<String>? memberUids,
    List<String>? memberEmails,
    String? inviteCode,
    String? currency,
    String? createdBy,
    String? imagePath,
  }) {
    return SplitwiseGroupModel(
      id: id,
      name: name ?? this.name,
      members: members ?? this.members,
      memberUids: memberUids ?? this.memberUids,
      memberEmails: memberEmails ?? this.memberEmails,
      inviteCode: inviteCode ?? this.inviteCode,
      currency: currency ?? this.currency,
      createdBy: createdBy ?? this.createdBy,
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
  final String currency; // Expense currency code (e.g. INR, USD)
  final double exchangeRate; // Exchange rate to group currency
  final DateTime date;
  final String splitType; // 'equal', 'exact', 'percentage', 'shares', 'itemized'
  final Map<String, double> paidBy; // member name/uid -> amount paid in expense currency
  final Map<String, double> distribution; // member name/uid -> amount owed in expense currency
  final List<String> excludedMembers; // Members excluded from split
  final String createdBy;
  final DateTime? updatedAt;

  SplitwiseExpenseModel({
    required this.id,
    required this.splitwiseGroupId,
    required this.title,
    required this.amount,
    this.currency = 'INR',
    this.exchangeRate = 1.0,
    required this.date,
    this.splitType = 'equal',
    required this.paidBy,
    required this.distribution,
    this.excludedMembers = const [],
    this.createdBy = '',
    this.updatedAt,
  });

  /// Amount converted to base group currency
  double get convertedAmount => amount * exchangeRate;

  String get currencySymbol {
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'AED':
        return 'AED ';
      case 'THB':
        return '฿';
      case 'JPY':
        return '¥';
      case 'CAD':
        return 'CA\$';
      case 'AUD':
        return 'A\$';
      case 'SGD':
        return 'S\$';
      case 'INR':
      default:
        return '₹';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'splitwiseGroupId': splitwiseGroupId,
        'title': title,
        'amount': amount,
        'currency': currency,
        'exchangeRate': exchangeRate,
        'date': date.toIso8601String(),
        'splitType': splitType,
        'paidBy': paidBy,
        'distribution': distribution,
        'excludedMembers': excludedMembers,
        'createdBy': createdBy,
        'updatedAt': (updatedAt ?? date).toIso8601String(),
      };

  factory SplitwiseExpenseModel.fromJson(Map<String, dynamic> json) {
    return SplitwiseExpenseModel(
      id: json['id'] ?? '',
      splitwiseGroupId: json['splitwiseGroupId'] ?? '',
      title: json['title'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'INR',
      exchangeRate: (json['exchangeRate'] as num?)?.toDouble() ?? 1.0,
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      splitType: json['splitType'] ?? 'equal',
      paidBy: json['paidBy'] != null
          ? Map<String, double>.from((json['paidBy'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())))
          : {'You': (json['amount'] as num?)?.toDouble() ?? 0.0},
      distribution: json['distribution'] != null
          ? Map<String, double>.from((json['distribution'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())))
          : {},
      excludedMembers: json['excludedMembers'] != null
          ? List<String>.from(json['excludedMembers'])
          : const [],
      createdBy: json['createdBy'] ?? '',
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  /// Helper: Primary payer name summary
  String get primaryPayer {
    if (paidBy.isEmpty) return 'You';
    if (paidBy.length == 1) return paidBy.keys.first;
    return '${paidBy.keys.first} +${paidBy.length - 1} others';
  }
}

/// Settlement / Payment Model between group members
class SplitwiseSettlementModel {
  final String id;
  final String groupId;
  final String payerName;
  final String receiverName;
  final String payerUid;
  final String receiverUid;
  final double amount;
  final DateTime createdAt;
  final String createdBy;

  SplitwiseSettlementModel({
    required this.id,
    required this.groupId,
    required this.payerName,
    required this.receiverName,
    this.payerUid = '',
    this.receiverUid = '',
    required this.amount,
    required this.createdAt,
    this.createdBy = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'groupId': groupId,
        'payerName': payerName,
        'receiverName': receiverName,
        'payerUid': payerUid,
        'receiverUid': receiverUid,
        'amount': amount,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
      };

  factory SplitwiseSettlementModel.fromJson(Map<String, dynamic> json) {
    return SplitwiseSettlementModel(
      id: json['id'] ?? '',
      groupId: json['groupId'] ?? '',
      payerName: json['payerName'] ?? '',
      receiverName: json['receiverName'] ?? '',
      payerUid: json['payerUid'] ?? '',
      receiverUid: json['receiverUid'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      createdBy: json['createdBy'] ?? '',
    );
  }
}

/// In-App Group Activity Stream Model
class SplitwiseActivityModel {
  final String id;
  final String groupId;
  final String type; // EXPENSE_CREATED, EXPENSE_UPDATED, EXPENSE_DELETED, PAYMENT_CREATED, PAYMENT_UPDATED, PAYMENT_DELETED, MEMBER_JOINED
  final String actorId;
  final String actorName;
  final String title;
  final String body;
  final String? expenseId;
  final double? amount;
  final double? previousAmount;
  final DateTime createdAt;

  SplitwiseActivityModel({
    required this.id,
    required this.groupId,
    required this.type,
    required this.actorId,
    required this.actorName,
    required this.title,
    required this.body,
    this.expenseId,
    this.amount,
    this.previousAmount,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'groupId': groupId,
        'type': type,
        'actorId': actorId,
        'actorName': actorName,
        'title': title,
        'body': body,
        'expenseId': expenseId,
        'amount': amount,
        'previousAmount': previousAmount,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SplitwiseActivityModel.fromJson(Map<String, dynamic> json) {
    return SplitwiseActivityModel(
      id: json['id'] ?? '',
      groupId: json['groupId'] ?? '',
      type: json['type'] ?? '',
      actorId: json['actorId'] ?? '',
      actorName: json['actorName'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      expenseId: json['expenseId'],
      amount: (json['amount'] as num?)?.toDouble(),
      previousAmount: (json['previousAmount'] as num?)?.toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}
