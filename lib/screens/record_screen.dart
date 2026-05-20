import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../models/lifting_record.dart';
import '../services/record_service.dart';
import '../services/storage_service.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final _countController = TextEditingController();
  File? _videoFile;
  VideoPlayerController? _videoController;
  bool _saving = false;

  @override
  void dispose() {
    _countController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 3),
    );
    if (picked == null) return;
    final file = File(picked.path);
    final ctrl = VideoPlayerController.file(file);
    await ctrl.initialize();
    setState(() {
      _videoFile = file;
      _videoController?.dispose();
      _videoController = ctrl;
    });
  }

  Future<void> _save() async {
    final count = int.tryParse(_countController.text);
    if (count == null || count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('回数を正しく入力してください')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      String? videoUrl;
      if (_videoFile != null) {
        videoUrl = await StorageService().uploadVideo(_videoFile!);
      }
      await RecordService().addRecord(LiftingRecord(
        uid: user.uid,
        displayName: user.displayName ?? '名無し',
        count: count,
        createdAt: DateTime.now(),
        videoUrl: videoUrl,
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('記録を追加')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('リフティング回数', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _countController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                suffixText: '回',
                hintText: '例: 50',
              ),
            ),
            const SizedBox(height: 24),
            const Text('動画（任意）', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            if (_videoController != null && _videoController!.value.isInitialized)
              _VideoPreview(controller: _videoController!)
            else
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('動画未選択', style: TextStyle(color: Colors.grey)),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickVideo(ImageSource.camera),
                    icon: const Icon(Icons.videocam),
                    label: const Text('録画'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickVideo(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('ギャラリー'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  final VideoPlayerController controller;
  const _VideoPreview({required this.controller});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          widget.controller.value.isPlaying
              ? widget.controller.pause()
              : widget.controller.play();
        });
      },
      child: AspectRatio(
        aspectRatio: widget.controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(widget.controller),
            if (!widget.controller.value.isPlaying)
              const Icon(Icons.play_circle_fill,
                  size: 48, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
