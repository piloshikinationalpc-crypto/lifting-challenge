import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorageService {
  final _storage = FirebaseStorage.instance;

  Future<String> uploadVideo(File file) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final name = '${DateTime.now().millisecondsSinceEpoch}.mp4';
    final ref = _storage.ref('videos/$uid/$name');
    await ref.putFile(file, SettableMetadata(contentType: 'video/mp4'));
    return await ref.getDownloadURL();
  }

  Future<String> uploadTacticalMapImage(Uint8List bytes) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final name = '${DateTime.now().millisecondsSinceEpoch}.png';
    final ref = _storage.ref('tactical_maps/$uid/$name');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/png'));
    return await ref.getDownloadURL();
  }
}
