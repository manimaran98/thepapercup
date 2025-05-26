import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:thepapercup/modal/user_model.dart';
import 'package:thepapercup/services/image_service.dart';
import 'package:intl/intl.dart';
import 'package:thepapercup/modal/category_model.dart';
import 'package:thepapercup/services/category_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final _imageService = ImageService();
  UserModel? userData;
  bool isLoading = true;
  bool lowStockNotification = true;
  bool shiftNotification = true;
  TimeOfDay openShiftTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay closeShiftTime = const TimeOfDay(hour: 22, minute: 0);
  String? profileImageUrl;
  List<UserModel> users = [];

  @override
  void initState() {
    super.initState();
    loadUserData();
    loadNotificationSettings();
  }

  Future<void> loadUserData() async {
    try {
      if (user != null) {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();

        if (doc.exists) {
          setState(() {
            userData = UserModel.fromMap(doc.data() as Map<String, dynamic>);
            profileImageUrl = userData?.profileImageUrl;
            isLoading = false;
          });

          // Load users if the current user is an admin
          if (userData?.role == 'Admin') {
            await loadUsers();
          }
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      Fluttertoast.showToast(msg: 'Error loading user data');
    }
  }

  Future<void> uploadProfileImage() async {
    try {
      final imageUrl = await _imageService.pickAndUploadImage();
      if (imageUrl != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .update({'profileImageUrl': imageUrl});

        setState(() {
          profileImageUrl = imageUrl;
        });
        Fluttertoast.showToast(msg: 'Profile image updated successfully');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error uploading profile image');
    }
  }

  Future<void> createNewUser() async {
    final formKey = GlobalKey<FormState>();
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();
    final TextEditingController mobileController = TextEditingController();
    final TextEditingController birthDateController = TextEditingController();
    final TextEditingController genderController = TextEditingController();
    DateTime? selectedDate;
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create New User'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter full name';
                      }
                      if (value.length < 3) {
                        return 'Name must be at least 3 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: confirmPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm password';
                      }
                      if (value != passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: mobileController,
                    decoration: const InputDecoration(
                      labelText: 'Mobile',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter mobile number';
                      }
                      if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                        return 'Please enter a valid 10-digit mobile number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: birthDateController,
                    decoration: const InputDecoration(
                      labelText: 'Birth Date',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        selectedDate = picked;
                        birthDateController.text =
                            DateFormat('dd/MM/yyyy').format(picked);
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select birth date';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: genderController,
                    decoration: const InputDecoration(
                      labelText: 'Gender',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter gender';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (isLoading)
              const CircularProgressIndicator()
            else
              TextButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    setState(() => isLoading = true);
                    try {
                      // Create user in Firebase Auth
                      final userCredential = await FirebaseAuth.instance
                          .createUserWithEmailAndPassword(
                        email: emailController.text.trim(),
                        password: passwordController.text,
                      );

                      // Create user document in Firestore
                      final newUser = UserModel(
                        uid: userCredential.user!.uid,
                        email: emailController.text.trim(),
                        fullName: nameController.text,
                        mobile: mobileController.text,
                        birthDate: birthDateController.text,
                        gender: genderController.text,
                        role: 'User',
                      );

                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(userCredential.user!.uid)
                          .set(newUser.toMap());

                      if (mounted) {
                        Navigator.pop(context);
                        Fluttertoast.showToast(
                            msg: 'User created successfully');
                      }
                    } catch (e) {
                      String errorMessage = 'Error creating user';
                      if (e is FirebaseAuthException) {
                        switch (e.code) {
                          case 'weak-password':
                            errorMessage = 'The password provided is too weak.';
                            break;
                          case 'email-already-in-use':
                            errorMessage =
                                'An account already exists for that email.';
                            break;
                          case 'invalid-email':
                            errorMessage = 'The email address is invalid.';
                            break;
                          default:
                            errorMessage = 'Error: ${e.message}';
                        }
                      }
                      Fluttertoast.showToast(msg: errorMessage);
                    } finally {
                      if (mounted) {
                        setState(() => isLoading = false);
                      }
                    }
                  }
                },
                child: const Text('Create'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> loadNotificationSettings() async {
    try {
      if (user != null) {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('userSettings')
            .doc(user!.uid)
            .get();

        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          setState(() {
            lowStockNotification = data['lowStockNotification'] ?? true;
            shiftNotification = data['shiftNotification'] ?? true;
            if (data['openShiftTime'] != null) {
              List<String> timeParts = data['openShiftTime'].split(':');
              openShiftTime = TimeOfDay(
                hour: int.parse(timeParts[0]),
                minute: int.parse(timeParts[1]),
              );
            }
            if (data['closeShiftTime'] != null) {
              List<String> timeParts = data['closeShiftTime'].split(':');
              closeShiftTime = TimeOfDay(
                hour: int.parse(timeParts[0]),
                minute: int.parse(timeParts[1]),
              );
            }
          });
        }
      }
    } catch (e) {
      print('Error loading notification settings: $e');
    }
  }

  Future<void> saveNotificationSettings() async {
    try {
      await FirebaseFirestore.instance
          .collection('userSettings')
          .doc(user!.uid)
          .set({
        'lowStockNotification': lowStockNotification,
        'shiftNotification': shiftNotification,
        'openShiftTime': '${openShiftTime.hour}:${openShiftTime.minute}',
        'closeShiftTime': '${closeShiftTime.hour}:${closeShiftTime.minute}',
      });
      Fluttertoast.showToast(msg: 'Settings saved successfully');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error saving settings');
    }
  }

  Future<void> showNotificationSettings() async {
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Notification Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Low Stock Alerts'),
                  subtitle:
                      const Text('Get notified when items are running low'),
                  value: lowStockNotification,
                  onChanged: (value) {
                    setState(() {
                      lowStockNotification = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Shift Reminders'),
                  subtitle:
                      const Text('Get notified about shift start/end times'),
                  value: shiftNotification,
                  onChanged: (value) {
                    setState(() {
                      shiftNotification = value;
                    });
                  },
                ),
                const Divider(),
                ListTile(
                  title: const Text('Open Shift Time'),
                  subtitle: Text(
                    '${openShiftTime.hour.toString().padLeft(2, '0')}:${openShiftTime.minute.toString().padLeft(2, '0')}',
                  ),
                  onTap: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: openShiftTime,
                    );
                    if (picked != null) {
                      setState(() {
                        openShiftTime = picked;
                      });
                    }
                  },
                ),
                ListTile(
                  title: const Text('Close Shift Time'),
                  subtitle: Text(
                    '${closeShiftTime.hour.toString().padLeft(2, '0')}:${closeShiftTime.minute.toString().padLeft(2, '0')}',
                  ),
                  onTap: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: closeShiftTime,
                    );
                    if (picked != null) {
                      setState(() {
                        closeShiftTime = picked;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                this.setState(() {
                  saveNotificationSettings();
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> updateUserProfile() async {
    final TextEditingController nameController =
        TextEditingController(text: userData?.fullName);
    final TextEditingController mobileController =
        TextEditingController(text: userData?.mobile);
    final TextEditingController birthDateController =
        TextEditingController(text: userData?.birthDate);
    final TextEditingController genderController =
        TextEditingController(text: userData?.gender);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              TextField(
                controller: mobileController,
                decoration: const InputDecoration(labelText: 'Mobile'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: birthDateController,
                decoration: const InputDecoration(labelText: 'Birth Date'),
              ),
              TextField(
                controller: genderController,
                decoration: const InputDecoration(labelText: 'Gender'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .update({
                  'fullName': nameController.text,
                  'mobile': mobileController.text,
                  'birthDate': birthDateController.text,
                  'gender': genderController.text,
                });

                await loadUserData();
                if (mounted) {
                  Navigator.pop(context);
                  Fluttertoast.showToast(msg: 'Profile updated successfully');
                }
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error updating profile');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> changePassword() async {
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                decoration:
                    const InputDecoration(labelText: 'Current Password'),
                obscureText: true,
              ),
              TextField(
                controller: newPasswordController,
                decoration: const InputDecoration(labelText: 'New Password'),
                obscureText: true,
              ),
              TextField(
                controller: confirmPasswordController,
                decoration:
                    const InputDecoration(labelText: 'Confirm New Password'),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (newPasswordController.text !=
                  confirmPasswordController.text) {
                Fluttertoast.showToast(msg: 'New passwords do not match');
                return;
              }

              try {
                // Reauthenticate user
                AuthCredential credential = EmailAuthProvider.credential(
                  email: user!.email!,
                  password: currentPasswordController.text,
                );
                await user!.reauthenticateWithCredential(credential);

                // Change password
                await user!.updatePassword(newPasswordController.text);

                if (mounted) {
                  Navigator.pop(context);
                  Fluttertoast.showToast(msg: 'Password changed successfully');
                }
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error changing password');
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  Future<void> loadUsers() async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('isDeleted', isEqualTo: false)
          .orderBy('fullName')
          .get();

      setState(() {
        users = snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      print('Error loading users: $e');
      Fluttertoast.showToast(msg: 'Error loading users');
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      // Soft delete by updating isDeleted field
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });

      // Reload users list
      await loadUsers();

      Fluttertoast.showToast(msg: 'User deleted successfully');
    } catch (e) {
      print('Error deleting user: $e');
      Fluttertoast.showToast(msg: 'Error deleting user: $e');
    }
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'role': newRole});

      await loadUsers();
      Fluttertoast.showToast(msg: 'User role updated successfully');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error updating user role: $e');
    }
  }

  Future<void> showUserManagementDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Management'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                title: Text(user.fullName ?? ''),
                subtitle: Text('${user.email} (${user.role})'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<String>(
                      onSelected: (String value) async {
                        if (value == 'delete') {
                          // Don't allow deleting self
                          if (user.uid == this.user?.uid) {
                            Fluttertoast.showToast(
                                msg: 'Cannot delete your own account');
                            return;
                          }

                          final bool? confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Confirm Delete'),
                              content: Text(
                                  'Are you sure you want to delete ${user.fullName}? This action can be undone later.'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await deleteUser(user.uid!);
                            if (mounted) {
                              Navigator.pop(context);
                              showUserManagementDialog();
                            }
                          }
                        } else if (value == 'role') {
                          // Don't allow changing own role
                          if (user.uid == this.user?.uid) {
                            Fluttertoast.showToast(
                                msg: 'Cannot change your own role');
                            return;
                          }

                          final String? newRole = await showDialog<String>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Change Role'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    title: const Text('Admin'),
                                    onTap: () =>
                                        Navigator.pop(context, 'Admin'),
                                  ),
                                  ListTile(
                                    title: const Text('User'),
                                    onTap: () => Navigator.pop(context, 'User'),
                                  ),
                                ],
                              ),
                            ),
                          );

                          if (newRole != null) {
                            await updateUserRole(user.uid!, newRole);
                            if (mounted) {
                              Navigator.pop(context);
                              showUserManagementDialog();
                            }
                          }
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem(
                          value: 'role',
                          child: Text('Change Role'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, List<Widget> tiles) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tiles.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) => tiles[index],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: onTap,
    );
  }

  Widget _buildUserManagementCard(BuildContext context) {
    // Placeholder for User Management UI
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User Management',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildSettingsTile('Manage Users', Icons.group, () {
              // TODO: Navigate to User Management Screen
            }),
            _buildSettingsTile('Manage Categories', Icons.category, () {
              _showManageCategoriesDialog();
            }),
          ],
        ),
      ),
    );
  }

  void _showManageCategoriesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Categories'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<List<CategoryModel>>(
            stream: CategoryService().getCategories(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final categories = snapshot.data ?? [];
              return ListView.builder(
                shrinkWrap: true,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return ListTile(
                    title: Text(category.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showEditCategoryDialog(category),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _confirmDeleteCategory(category),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () => _showAddCategoryDialog(),
            child: const Text('Add Category'),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Category Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final newCategory =
                    CategoryModel(id: '', name: controller.text);
                await CategoryService().addCategory(newCategory);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(CategoryModel category) {
    final controller = TextEditingController(text: category.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Category Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final updatedCategory =
                    CategoryModel(id: category.id, name: controller.text);
                await CategoryService().updateCategory(updatedCategory);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(CategoryModel category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
            'Are you sure you want to delete category "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await CategoryService().deleteCategory(category.id);
                Navigator.pop(context);
                Fluttertoast.showToast(
                    msg: 'Category deleted successfully (soft delete)');
              } catch (e) {
                Navigator.pop(context);
                Fluttertoast.showToast(
                    msg: e.toString(), backgroundColor: Colors.red);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        actions: [
          if (userData?.role == 'Admin')
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: createNewUser,
              tooltip: 'Create New User',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: profileImageUrl != null
                            ? NetworkImage(profileImageUrl!)
                            : null,
                        child: profileImageUrl == null
                            ? const Icon(Icons.person, size: 50)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          backgroundColor: Colors.blue,
                          radius: 18,
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, size: 18),
                            color: Colors.white,
                            onPressed: uploadProfileImage,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userData?.fullName ?? 'User',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    userData?.email ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Role: ${userData?.role ?? 'User'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Settings Section
          _buildSettingsCard(context, [
            _buildSettingsTile('Edit Profile', Icons.edit, updateUserProfile),
            _buildSettingsTile('Change Password', Icons.lock, changePassword),
            _buildSettingsTile('Notifications & Shift Settings',
                Icons.notifications, showNotificationSettings),
            if (userData?.role == 'Admin') ...[
              _buildUserManagementCard(context),
            ],
          ]),
          const SizedBox(height: 16),
          // Logout Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
            ),
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error signing out');
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
