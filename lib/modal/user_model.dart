class UserModel {
  final String? uid;
  final String? email;
  final String? fullName;
  final String? mobile;
  final String? birthDate;
  final String? gender;
  final String? role;
  final String? profileImageUrl;
  final bool isDeleted;

  UserModel({
    this.uid,
    this.email,
    this.fullName,
    this.mobile,
    this.birthDate,
    this.gender,
    this.role,
    this.profileImageUrl,
    this.isDeleted = false,
  });

//Receive Data from Server

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'],
      email: map['email'],
      fullName: map['fullName'],
      mobile: map['mobile'],
      birthDate: map['birthDate'],
      gender: map['gender'],
      role: map['role'],
      profileImageUrl: map['profileImageUrl'],
      isDeleted: map['isDeleted'] ?? false,
    );
  }

  //Sending Data to the Server
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'mobile': mobile,
      'birthDate': birthDate,
      'gender': gender,
      'role': role,
      'profileImageUrl': profileImageUrl,
      'isDeleted': isDeleted,
    };
  }
}
