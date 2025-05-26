class ItemModel {
  final String id;
  final String name;
  final double price;
  final double cost;
  final int quantity;
  final String category;
  final String? imageUrl;

  ItemModel({
    required this.id,
    required this.name,
    required this.price,
    required this.cost,
    required this.quantity,
    required this.category,
    this.imageUrl,
  });

  factory ItemModel.fromMap(Map<String, dynamic> map, String docId) {
    return ItemModel(
      id: docId,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      cost: (map['cost'] as num).toDouble(),
      quantity: map['quantity'] as int,
      category: map['category'] as String,
      imageUrl: map['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'cost': cost,
      'quantity': quantity,
      'category': category,
      'imageUrl': imageUrl,
    };
  }
}
