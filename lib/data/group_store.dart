class GroupModel {
  final String id;
  final String name;
  final String? imagePath;

  GroupModel({
    required this.id,
    required this.name,
    this.imagePath,
  });
}

class GroupStore {
  static final List<GroupModel> groups = [];
}
