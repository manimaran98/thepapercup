import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';

class ImageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  Future<String?> pickAndUploadImage() async {
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

      // Validate file size (max 5MB)
      final file = File(image.path);
      final sizeInBytes = await file.length();
      final sizeInMB = sizeInBytes / (1024 * 1024);

      if (sizeInMB > 5) {
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

      // Create file reference with a more unique name
      String fileName =
          'img_${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';
      Reference ref = _storage.ref().child('inventory_images').child(fileName);

      try {
        // Upload file with retry logic
        final UploadTask uploadTask = ref.putFile(file);

        // Monitor upload progress
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress =
              (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          print('Upload progress: ${progress.toStringAsFixed(2)}%');
        });

        // Wait for upload to complete with retry
        int retryCount = 0;
        const maxRetries = 3;

        while (retryCount < maxRetries) {
          try {
            await uploadTask;
            break;
          } on FirebaseException catch (e) {
            if (e.code == 'storage/retry-limit-exceeded' ||
                e.code == 'storage/unauthorized' ||
                e.message?.contains('terminated the upload session') == true) {
              retryCount++;
              if (retryCount < maxRetries) {
                print(
                    'Retrying upload attempt ${retryCount + 1} of $maxRetries');
                await Future.delayed(const Duration(seconds: 2));
                continue;
              }
            }
            rethrow;
          }
        }

        if (retryCount == maxRetries) {
          throw FirebaseException(
              plugin: 'storage',
              code: 'storage/retry-limit-exceeded',
              message: 'Upload failed after $maxRetries attempts');
        }

        // Get download URL
        String downloadUrl = await ref.getDownloadURL();

        // Show success toast
        Fluttertoast.showToast(
          msg: 'Image uploaded successfully',
          backgroundColor: Colors.green,
        );

        return downloadUrl;
      } on FirebaseException catch (e) {
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
          default:
            errorMessage += e.message ?? 'Unknown error occurred';
        }
        print('Firebase Storage Error: ${e.code} - ${e.message}');
        Fluttertoast.showToast(
          msg: errorMessage,
          backgroundColor: Colors.red,
        );
        return null;
      }
    } catch (e) {
      print('Error uploading image: $e');
      Fluttertoast.showToast(
        msg: 'Error uploading image: ${e.toString()}',
        backgroundColor: Colors.red,
      );
      return null;
    }
  }

  Future<void> deleteImage(String imageUrl) async {
    try {
      Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } on FirebaseException catch (e) {
      print('Firebase Storage Error while deleting: ${e.code} - ${e.message}');
      Fluttertoast.showToast(
        msg: 'Error deleting image: ${e.message}',
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
