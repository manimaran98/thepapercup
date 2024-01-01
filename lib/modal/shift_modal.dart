class ShiftModel {
  final String id; // Unique identifier for the shift
  final String name; // Name or description of the shift
  final bool isOpen; // Indicates whether the shift is open or closed
  final String startTime; // Start time of the shift in "hh:mm a" format
  final String endTime; // End time of the shift in "hh:mm a" format
  final String date; // Date of the shift in "DD/MM/YYYY" format
  final double drawerAmount; // Drawer amount for the shift
  final double sales; // Sales for the shift
  final String userId; // User ID associated with the shift

  ShiftModel({
    required this.id,
    required this.name,
    required this.isOpen,
    required this.startTime,
    required this.endTime,
    required this.date,
    required this.drawerAmount,
    required this.sales,
    required this.userId,
  });

  // Create a factory constructor to convert a map to a ShiftModel object
  factory ShiftModel.fromMap(Map<String, dynamic> map) {
    return ShiftModel(
      id: map['id'] as String,
      name: map['name'] as String,
      isOpen: map['isOpen'] as bool,
      startTime: map['startTime'] as String,
      endTime: map['endTime'] as String,
      date: map['date'] as String,
      drawerAmount: (map['drawerAmount'] as num).toDouble(),
      sales: (map['sales'] as num).toDouble(),
      userId: map['userId'] as String,
    );
  }

  // Convert the ShiftModel object to a map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isOpen': isOpen,
      'startTime': startTime,
      'endTime': endTime,
      'date': date,
      'drawerAmount': drawerAmount,
      'sales': sales,
      'userId': userId,
    };
  }
}
