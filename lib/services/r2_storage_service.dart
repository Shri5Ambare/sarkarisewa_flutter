import 'dart:io';
import 'package:cloudflare_r2/cloudflare_r2.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';

class R2StorageService {
  static final String _accountId = dotenv.get('R2_ACCOUNT_ID');
  static final String _accessKeyId = dotenv.get('R2_ACCESS_KEY_ID');
  static final String _secretAccessKey = dotenv.get('R2_SECRET_ACCESS_KEY');
  static final String _bucketName = dotenv.get('R2_BUCKET_NAME');
  static final String _publicUrl = dotenv.get('R2_PUBLIC_URL');

  static bool _initialized = false;

  static void _init() {
    if (_initialized) return;
    CloudFlareR2.init(
      accountId: _accountId,
      accessKeyId: _accessKeyId,
      secretAccessKey: _secretAccessKey,
    );
    _initialized = true;
  }

  /// Uploads a file to Cloudflare R2 and returns its public URL.
  static Future<String?> uploadFile(PlatformFile file, {String folder = 'courses'}) async {
    try {
      _init();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final path = '$folder/$fileName';

      Uint8List? bytes = file.bytes;
      if (bytes == null && !kIsWeb && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes == null) {
        debugPrint('R2 Upload Error: No bytes to upload');
        return null;
      }

      final contentType = lookupMimeType(file.name) ?? 'application/octet-stream';

      await CloudFlareR2.putObject(
        bucket: _bucketName,
        objectName: path,
        objectBytes: bytes,
        contentType: contentType,
      );

      return '$_publicUrl/$path';
    } catch (e) {
      debugPrint('R2 Upload Exception: $e');
      return null;
    }
  }

  /// Deletes an object from R2.
  static Future<bool> deleteFile(String objectKey) async {
    try {
      _init();
      // Assume deleteObject exists and takes similar parameters based on getObject/putObject
      await CloudFlareR2.deleteObject(
        bucket: _bucketName,
        objectName: objectKey,
      );
      return true;
    } catch (e) {
      debugPrint('R2 Delete Exception: $e');
      return false;
    }
  }
}
