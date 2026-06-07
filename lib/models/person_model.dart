class PersonModel {
  final String id;
  final String name;
  final String? photoPath;
  final String? phone;
  final String? address;
  final String? group;
  final String? notes;
  final DateTime createdAt;

  const PersonModel({
    required this.id,
    required this.name,
    this.photoPath,
    this.phone,
    this.address,
    this.group,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'photoPath': photoPath,
        'phone': phone,
        'address': address,
        'group': group,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PersonModel.fromJson(Map<String, dynamic> json) => PersonModel(
        id: json['id'] as String,
        name: json['name'] as String,
        photoPath: json['photoPath'] as String?,
        phone: json['phone'] as String?,
        address: json['address'] as String?,
        group: json['group'] as String?,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  PersonModel copyWith({
    String? id,
    String? name,
    Object? photoPath = _sentinel,
    Object? phone = _sentinel,
    Object? address = _sentinel,
    Object? group = _sentinel,
    Object? notes = _sentinel,
    DateTime? createdAt,
  }) =>
      PersonModel(
        id: id ?? this.id,
        name: name ?? this.name,
        photoPath: photoPath == _sentinel ? this.photoPath : photoPath as String?,
        phone: phone == _sentinel ? this.phone : phone as String?,
        address: address == _sentinel ? this.address : address as String?,
        group: group == _sentinel ? this.group : group as String?,
        notes: notes == _sentinel ? this.notes : notes as String?,
        createdAt: createdAt ?? this.createdAt,
      );
}

const _sentinel = Object();
