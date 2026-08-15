import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 容量オーバーなど、利用者にそのまま見せてよいメッセージを持つ例外。
class StorageLimitException implements Exception {
  final String message;
  StorageLimitException(this.message);
  @override
  String toString() => message;
}

class StorageService {
  final _storage = FirebaseStorage.instance;

  /// 動画の上限。storage.rules 側の上限と必ず揃えること。
  /// 揃っていないと、延々アップロードした末にルールで拒否されて
  /// 原因の分からない失敗になる。
  static const int maxVideoBytes = 500 * 1024 * 1024;

  /// この大きさを超えたら、アップロード前に一言注意する目安。
  static const int warnVideoBytes = 150 * 1024 * 1024;

  static String formatMb(int bytes) => (bytes / 1024 / 1024).toStringAsFixed(0);

  Future<String> uploadVideo(File file) async {
    final size = await file.length();
    if (size > maxVideoBytes) {
      throw StorageLimitException(
        '動画が大きすぎます（${formatMb(size)}MB）。'
        '${formatMb(maxVideoBytes)}MB以内に収めてください。',
      );
    }
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final name = '${DateTime.now().millisecondsSinceEpoch}.mp4';
    final ref = _storage.ref('videos/$uid/$name');
    await ref.putFile(file, SettableMetadata(contentType: 'video/mp4'));
    return await ref.getDownloadURL();
  }

  /// アップロードしたあとで記録の保存に失敗したときの後始末。
  /// 消さずに放置すると、どの記録からも参照されない動画がStorageに残り続ける。
  Future<void> deleteByUrl(String url) async {
    await _storage.refFromURL(url).delete();
  }

  Future<String> uploadTacticalMapImage(Uint8List bytes) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final name = '${DateTime.now().millisecondsSinceEpoch}.png';
    final ref = _storage.ref('tactical_maps/$uid/$name');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/png'));
    return await ref.getDownloadURL();
  }
}
