import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:thepapercup/services/auth_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

class ImageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final AuthService _authService = AuthService();

  Future<String?> pickAndUploadImage() async {
    // Check if user is authenticated
    if (!_authService.isAuthenticated()) {
      print('User is not authenticated');
      Fluttertoast.showToast(
        msg: 'Please login to upload images',
        backgroundColor: Colors.red,
      );
      return null;
    }

    try {
      // Request permission
      if (Platform.isAndroid) {
        PermissionStatus status;
        if (await Permission.storage.isGranted) {
          status = await Permission.storage.request();
        } else if (await Permission.photos.isGranted) {
          status = await Permission.photos.request();
        } else {
          status = await Permission.mediaLibrary.request();
        }

        if (status.isDenied) {
          print('Storage permission denied');
          Fluttertoast.showToast(
            msg: 'Storage permission is required to pick images',
            backgroundColor: Colors.red,
          );
          return null;
        }
      }

      // Pick image
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) {
        print('No image selected');
        return null;
      }

      // Get the application documents directory
      final appDocDir = await getApplicationDocumentsDirectory();
      final fileName =
          'img_${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';
      final filePath = '${appDocDir.path}/$fileName';

      // Copy the picked image to the app's documents directory
      final File file = File(image.path);
      await file.copy(filePath);
      final File localFile = File(filePath);

      // Validate file size (max 5MB)
      final sizeInBytes = await localFile.length();
      final sizeInMB = sizeInBytes / (1024 * 1024);

      if (sizeInMB > 5) {
        print('File too large: ${sizeInMB.toStringAsFixed(2)}MB');
        Fluttertoast.showToast(
          msg: 'Image size must be less than 5MB',
          backgroundColor: Colors.red,
        );
        return null;
      }

      // Show loading toast
      Fluttertoast.showToast(
        msg: 'Uploading image...',
        backgroundColor: Colors.blue,
      );

      // Create file reference
      final storageRef = _storage.ref();
      final imageRef = storageRef.child('inventory_images').child(fileName);

      // Create the file metadata
      final metadata = SettableMetadata(
        contentType: 'image/${path.extension(image.path).replaceAll('.', '')}',
        customMetadata: {
          'uploadedBy': _authService.currentUser?.email ?? 'unknown',
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      try {
        // Print debug information
        print('Starting upload to path: ${imageRef.fullPath}');
        print('File size: ${sizeInMB.toStringAsFixed(2)}MB');
        print('Storage bucket: ${_storage.app.options.storageBucket}');
        print('Firebase app name: ${_storage.app.name}');
        print('Firebase project ID: ${_storage.app.options.projectId}');
        print('Current user: ${_authService.currentUser?.email}');
        print('Current user ID: ${_authService.currentUser?.uid}');
        print('File path: ${localFile.path}');
        print('File exists: ${await localFile.exists()}');

        // Upload file and metadata
        final uploadTask = imageRef.putFile(localFile, metadata);

        // Listen for state changes, errors, and completion of the upload
        uploadTask.snapshotEvents.listen(
          (TaskSnapshot taskSnapshot) {
            switch (taskSnapshot.state) {
              case TaskState.running:
                final progress = 100.0 *
                    (taskSnapshot.bytesTransferred / taskSnapshot.totalBytes);
                print("Upload is ${progress.toStringAsFixed(2)}% complete.");
                print("Bytes transferred: ${taskSnapshot.bytesTransferred}");
                print("Total bytes: ${taskSnapshot.totalBytes}");
                break;
              case TaskState.paused:
                print("Upload is paused.");
                break;
              case TaskState.canceled:
                print("Upload was canceled");
                break;
              case TaskState.error:
                print("Upload encountered an error state");
                break;
              case TaskState.success:
                print("Upload completed successfully");
                break;
            }
          },
          onError: (error) {
            print('Error during upload: $error');
          },
        );

        // Wait for upload to complete
        final TaskSnapshot snapshot = await uploadTask;

        if (snapshot.state == TaskState.success) {
          // Get download URL
          final downloadUrl = await snapshot.ref.getDownloadURL();
          print('Download URL: $downloadUrl');

          // Show success toast
          Fluttertoast.showToast(
            msg: 'Image uploaded successfully',
            backgroundColor: Colors.green,
          );

          // Clean up local file
          await localFile.delete();

          return downloadUrl;
        } else {
          throw FirebaseException(
            plugin: 'storage',
            code: 'storage/upload-failed',
            message: 'Upload failed with state: ${snapshot.state}',
          );
        }
      } on FirebaseException catch (e) {
        print('Firebase Storage Error: ${e.code} - ${e.message}');
        print('Full error details: ${e.toString()}');
        print('Error stack trace: ${e.stackTrace}');

        String errorMessage = 'Firebase Error: ';
        switch (e.code) {
          case 'storage/unauthorized':
            errorMessage += 'User is not authorized to upload';
            break;
          case 'storage/canceled':
            errorMessage += 'Upload was canceled';
            break;
          case 'storage/retry-limit-exceeded':
            errorMessage += 'Upload failed too many times';
            break;
          case '-13000':
            errorMessage +=
                'Play Store integrity error. Please update your Play Store app.';
            break;
          case 'storage/app-check-token-expired':
            errorMessage += 'App Check token expired. Please try again.';
            break;
          case 'storage/app-check-token-invalid':
            errorMessage += 'Invalid App Check token. Please try again.';
            break;
          case 'storage/app-check-token-missing':
            errorMessage += 'App Check token missing. Please try again.';
            break;
          case 'storage/app-check-token-error':
            errorMessage += 'App Check token error. Please try again.';
            break;
          default:
            errorMessage += e.message ?? 'Unknown error occurred';
        }

        Fluttertoast.showToast(
          msg: errorMessage,
          backgroundColor: Colors.red,
        );
        return null;
      }
    } catch (e) {
      print('Error uploading image: $e');
      print('Error stack trace: ${StackTrace.current}');
      Fluttertoast.showToast(
        msg: 'Error uploading image: ${e.toString()}',
        backgroundColor: Colors.red,
      );
      return null;
    }
  }

  Future<void> deleteImage(String imageUrl) async {
    // Check if user is authenticated
    if (!_authService.isAuthenticated()) {
      Fluttertoast.showToast(
        msg: 'Please login to delete images',
        backgroundColor: Colors.red,
      );
      return;
    }

    try {
      Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      Fluttertoast.showToast(
        msg: 'Image deleted successfully',
        backgroundColor: Colors.green,
      );
    } on FirebaseException catch (e) {
      print('Firebase Storage Error while deleting: ${e.code} - ${e.message}');
      String errorMessage = 'Error deleting image: ';

      switch (e.code) {
        case 'storage/unauthorized':
          errorMessage += 'User is not authorized to delete';
          break;
        case 'storage/app-check-token-expired':
          errorMessage += 'App Check token expired. Please try again.';
          break;
        case 'storage/app-check-token-invalid':
          errorMessage += 'Invalid App Check token. Please try again.';
          break;
        case 'storage/app-check-token-missing':
          errorMessage += 'App Check token missing. Please try again.';
          break;
        case 'storage/app-check-token-error':
          errorMessage += 'App Check token error. Please try again.';
          break;
        default:
          errorMessage += e.message ?? 'Unknown error occurred';
      }

      Fluttertoast.showToast(
        msg: errorMessage,
        backgroundColor: Colors.red,
      );
    } catch (e) {
      print('Error deleting image: $e');
      Fluttertoast.showToast(
        msg: 'Error deleting image: ${e.toString()}',
        backgroundColor: Colors.red,
      );
    }
  }
}
