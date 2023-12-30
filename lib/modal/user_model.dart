class UserModel {
  String? uid;
  String? email;
  String? firstName;
  String? mobile;
  String? birthDate;
  String? gender;
  String? role;

  UserModel({
    this.uid,
    this.email,
    this.firstName,
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
      firstName: map['firstName'],
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
      'firstName': firstName,
      'mobile': mobile,
      'birthDate': birthDate,
      'gender': gender,
      'role': role,
    };
  }
}
