import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../models/soccer_note.dart';

class GeminiService {
  static const _apiKey = 'AIzaSyB2QF3El3OgPuXacf6YS3SC10wJFypw-tc';

  Future<String> getSoccerNoteAdvice(SoccerNote note) async {
    final sb = StringBuffer();
    sb.writeln('以下は小学5年生のサッカー選手のノートです。内容を読んで、励ましと具体的なアドバイスを200文字以内の日本語で返してください。');
    sb.writeln('');
    if (note.type == NoteType.match) {
      sb.writeln('【試合ノート】');
      if (note.opponent?.isNotEmpty == true) sb.writeln('対戦相手: ${note.opponent}');
      if (note.score?.isNotEmpty == true) sb.writeln('スコア: ${note.score}');
      if (note.positions.isNotEmpty) sb.writeln('ポジション: ${note.positions.join('・')}');
    } else {
      sb.writeln('【練習ノート】');
    }
    if (note.goal.isNotEmpty) sb.writeln('目標: ${note.goal}');
    final done = note.tasks.where((t) => t.done).map((t) => t.text).join('、');
    final pending = note.tasks.where((t) => !t.done).map((t) => t.text).join('、');
    if (done.isNotEmpty) sb.writeln('達成した課題: $done');
    if (pending.isNotEmpty) sb.writeln('未達成の課題: $pending');
    if (note.goodPoints.isNotEmpty) sb.writeln('よかった点: ${note.goodPoints}');
    if (note.improvements.isNotEmpty) sb.writeln('改善点: ${note.improvements}');
    if (note.goodPlays?.isNotEmpty == true) sb.writeln('よかったプレー: ${note.goodPlays}');
    if (note.tactics?.isNotEmpty == true) sb.writeln('戦術メモ: ${note.tactics}');
    if (note.memo.isNotEmpty) sb.writeln('メモ: ${note.memo}');

    final model = GenerativeModel(model: 'gemini-2.0-flash-lite', apiKey: _apiKey);
    final response = await model.generateContent([Content.text(sb.toString())]);
    return response.text?.trim() ?? 'アドバイスを取得できませんでした。';
  }

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
