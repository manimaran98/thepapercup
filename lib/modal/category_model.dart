class CategoryModel {
  final String id;
  final String name;
  final bool isDeleted;

  CategoryModel({
    required this.id,
    required this.name,
    this.isDeleted = false,
  });

  // Factory constructor for creating a new CategoryModel object from a map
  factory CategoryModel.fromMap(Map<String, dynamic> map, String id) {
    return CategoryModel(
      id: id,
      name: map['name'] as String,
      isDeleted: map['isDeleted'] ?? false,
    );
  }

  // Method for converting a CategoryModel object to a map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isDeleted': isDeleted,
    };
  }
}
