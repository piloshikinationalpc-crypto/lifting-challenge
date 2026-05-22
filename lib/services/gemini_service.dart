import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class GeminiService {
  static const _apiKey = 'AIzaSyB2QF3El3OgPuXacf6YS3SC10wJFypw-tc';

  Future<int?> countLiftings(File videoFile) async {
    final ctrl = VideoPlayerController.file(videoFile);
    await ctrl.initialize();
    final durationMs = ctrl.value.duration.inMilliseconds;
    ctrl.dispose();

    final intervalMs = durationMs > 15000 ? (durationMs ~/ 15) : 1000;
    final parts = <Part>[];
    for (int ms = 0; ms < durationMs; ms += intervalMs) {
      final bytes = await VideoThumbnail.thumbnailData(
        video: videoFile.path,
        imageFormat: ImageFormat.JPEG,
        timeMs: ms,
        quality: 50,
      );
      if (bytes != null) parts.add(DataPart('image/jpeg', bytes));
      if (parts.length >= 15) break;
    }
    if (parts.isEmpty) throw Exception('フレーム抽出に失敗しました');

    parts.add(TextPart(
      'これらは動画から1秒ごとに抽出したフレームです。この動画でボールのリフティング（ジャグリング）は合計何回行われていますか？数字のみで答えてください。判別できない場合は0と答えてください。',
    ));

    final model = GenerativeModel(
      model: 'gemini-2.0-flash-lite',
      apiKey: _apiKey,
    );
    final response = await model.generateContent([Content.multi(parts)]);
    final text = response.text ?? '';
    return int.tryParse(text.trim().replaceAll(RegExp(r'[^0-9]'), ''));
  }
}
