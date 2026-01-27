class ExpenseModel {
  final String id;
  final String groupId;
  final double amount;
  final String description;
  final List<String> categories;
  final DateTime date;
  final String? imagePath;

  ExpenseModel({
    required this.id,
    required this.groupId,
    required this.amount,
    required this.description,
    required this.categories,
    required this.date,
    this.imagePath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'groupId': groupId,
        'amount': amount,
        'description': description,
        'categories': categories,
        'date': date.toIso8601String(),
        'imagePath': imagePath,
      };

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'],
      groupId: json['groupId'],
      amount: json['amount'],
      description: json['description'],
      categories: List<String>.from(json['categories']),
      date: DateTime.parse(json['date']),
      imagePath: json['imagePath'],
    );
  }
}
