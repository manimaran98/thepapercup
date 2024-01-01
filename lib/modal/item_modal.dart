class ItemModel {
  String? id;
  String? name;
  double? price;
  int? quantity;

  ItemModel({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 0,
  });

  // Add a method to convert your item to a map if you're using Firestore or similar.
  factory ItemModel.fromMap(map) {
    return ItemModel(
      id: map['id'],
      name: map['name'],
      price: map['price'],
      quantity: map['quantity'],
    );
  }

  //Sending Data to the Server
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }
}
