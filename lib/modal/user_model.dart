class UserModel {
  String? uid;
  String? email;
  String? fullName;
  String? mobile;
  String? birthDate;
  String? gender;
  String? role;

  UserModel({
    this.uid,
    this.email,
    this.fullName,
    this.mobile,
    this.birthDate,
    this.gender,
    this.role,
  });

//Receive Data from Server

  factory UserModel.fromMap(map) {
    return UserModel(
      uid: map['user_id'],
      email: map['email'],
      fullName: map['fullName'],
      mobile: map['mobile'],
      birthDate: map['birthDate'],
      gender: map['gender'],
      role: map['role'],
    );
  }

  //Sending Data to the Server
  Map<String, dynamic> toMap() {
    return {
      'user_id': uid,
      'email': email,
      'fullName': fullName,
      'mobile': mobile,
      'birthDate': birthDate,
      'gender': gender,
      'role': role,
    };
  }
}
