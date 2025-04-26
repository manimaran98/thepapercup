class ItemModel {
  String? id;
  String? name;
  double? price;
  int? quantity;
  String? category;

  ItemModel({
    this.id,
    this.name,
    this.price,
    this.quantity,
    this.category,
  });

  // Add a method to convert your item to a map if you're using Firestore or similar.
  factory ItemModel.fromMap(Map<String, dynamic> map) {
    return ItemModel(
      id: map['id'],
      name: map['name'],
      price: map['price']?.toDouble(),
      quantity: map['quantity'],
      category: map['category'],
    );
  }

  //Sending Data to the Server
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
      'category': category,
    };
  }
}
