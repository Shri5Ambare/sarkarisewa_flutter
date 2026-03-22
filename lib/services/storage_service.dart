import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final _storage = FirebaseStorage.instance;

  /// Uploads a file to Firebase Storage.
  Future<String?> uploadFile({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(contentType: contentType);
      
      final uploadTask = ref.putData(bytes, metadata);
      final snapshot = await uploadTask;
      
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Firebase Storage Upload Error: $e');
      return null;
    }
  }
}
