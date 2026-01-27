class GroupModel {
  final String id;
  final String name;
  final String? imagePath;
  final List<String> categories;

  GroupModel({
    required this.id,
    required this.name,
    this.imagePath,
    required this.categories,
  });

  // ✅ ADD THIS METHOD
  GroupModel copyWith({
    String? name,
    String? imagePath,
    List<String>? categories,
  }) {
    return GroupModel(
      id: id, // id never changes
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      categories: categories ?? this.categories,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'imagePath': imagePath,
        'categories': categories,
      };

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'],
      name: json['name'],
      imagePath: json['imagePath'],
      categories:
          (json['categories'] as List<dynamic>).cast<String>(),
    );
  }
}
