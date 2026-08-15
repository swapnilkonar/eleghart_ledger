class GroupModel {
  final String id;
  final String name;
  final String? imagePath;
  final List<String> categories;
  final List<String> members;

  GroupModel({
    required this.id,
    required this.name,
    this.imagePath,
    required this.categories,
    List<String>? members,
  }) : members = members ?? const ['You'];

  GroupModel copyWith({
    String? name,
    String? imagePath,
    List<String>? categories,
    List<String>? members,
  }) {
    return GroupModel(
      id: id,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      categories: categories ?? this.categories,
      members: members ?? this.members,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'imagePath': imagePath,
        'categories': categories,
        'members': members,
      };

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'],
      name: json['name'],
      imagePath: json['imagePath'],
      categories: json['categories'] != null
          ? (json['categories'] as List<dynamic>).cast<String>()
          : const [],
      members: json['members'] != null
          ? (json['members'] as List<dynamic>).cast<String>()
          : const ['You'],
    );
  }
}
