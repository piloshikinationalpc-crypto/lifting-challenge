import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../models/tactical_map.dart';
import '../models/lifting_record.dart';
import '../services/tactical_map_service.dart';
import '../services/record_service.dart';
import 'tactical_board_screen.dart';

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アルバム'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: '戦術ボード'),
            Tab(icon: Icon(Icons.videocam), text: 'リフティング動画'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _TacticalMapAlbum(),
          _VideoAlbum(),
        ],
      ),
    );
  }
}

// ───────── 戦術ボード一覧 ─────────

class _TacticalMapAlbum extends StatelessWidget {
  const _TacticalMapAlbum();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<List<TacticalMap>>(
      stream: TacticalMapService().myMaps(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final maps = snapshot.data ?? [];
        if (maps.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.dashboard_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('保存した戦術ボードがないよ！',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
              ],
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: maps.length,
          itemBuilder: (context, i) => _MapTile(map: maps[i]),
        );
      },
    );
  }
}

class _MapTile extends StatelessWidget {
  final TacticalMap map;
  const _MapTile({required this.map});

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除しますか？'),
        content: const Text('この戦術ボードを削除します。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('削除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true && map.id != null) {
      await TacticalMapService().deleteMap(map.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MM/dd HH:mm');
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TacticalBoardScreen(linkedMapId: map.id),
        ),
      ),
      onLongPress: () => _confirmDelete(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            map.imageUrl != null
                ? Image.network(map.imageUrl!, fit: BoxFit.cover,
                    errorBuilder: (context, e, st) => _PlaceholderField(map: map))
                : _PlaceholderField(map: map),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Text(fmt.format(map.createdAt),
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(
                  map.courtType == CourtType.full ? '全面' : 'ハーフ',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderField extends StatelessWidget {
  final TacticalMap map;
  const _PlaceholderField({required this.map});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2E7D32),
      child: CustomPaint(painter: _MiniFieldPainter(map.courtType)),
    );
  }
}

class _MiniFieldPainter extends CustomPainter {
  final CourtType courtType;
  const _MiniFieldPainter(this.courtType);

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), line);
    if (courtType == CourtType.full) {
      canvas.drawLine(
          Offset(0, size.height / 2), Offset(size.width, size.height / 2), line);
      canvas.drawCircle(
          Offset(size.width / 2, size.height / 2), size.width * 0.15, line);
    }
  }

  @override
  bool shouldRepaint(_MiniFieldPainter old) => false;
}

// ───────── リフティング動画一覧 ─────────

class _VideoAlbum extends StatelessWidget {
  const _VideoAlbum();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<List<LiftingRecord>>(
      stream: RecordService().myRecords(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final records =
            (snapshot.data ?? []).where((r) => r.videoUrl != null).toList();
        if (records.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam_off, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('動画付きの記録がないよ！',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                const SizedBox(height: 8),
                Text('記録画面で動画を追加しよう',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
              ],
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: records.length,
          itemBuilder: (context, i) => _VideoTile(record: records[i]),
        );
      },
    );
  }
}

class _VideoTile extends StatefulWidget {
  final LiftingRecord record;
  const _VideoTile({required this.record});

  @override
  State<_VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends State<_VideoTile> {
  late final Future<Uint8List?> _thumbFuture = _loadThumb();

  Future<Uint8List?> _loadThumb() async {
    try {
      return await VideoThumbnail.thumbnailData(
        video: widget.record.videoUrl!,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 300,
        quality: 60,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除しますか？'),
        content: const Text('この動画記録を削除します。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('削除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true && widget.record.id != null) {
      await RecordService().deleteRecord(widget.record.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MM/dd HH:mm');
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _VideoPlayerScreen(
            url: widget.record.videoUrl!,
            count: widget.record.count,
          ),
        ),
      ),
      onLongPress: () => _confirmDelete(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<Uint8List?>(
              future: _thumbFuture,
              builder: (context, snap) {
                if (snap.hasData && snap.data != null) {
                  return Image.memory(snap.data!, fit: BoxFit.cover);
                }
                return Container(color: Colors.grey.shade900);
              },
            ),
            const Center(
              child: Icon(Icons.play_circle_fill, size: 48, color: Colors.white70),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${widget.record.count} 回',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    Text(fmt.format(widget.record.createdAt),
                        style:
                            const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────── 動画プレイヤー画面 ─────────

class _VideoPlayerScreen extends StatefulWidget {
  final String url;
  final int count;

  const _VideoPlayerScreen({required this.url, required this.count});

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _ctrl.play();
        }
      }).catchError((_) {
        if (mounted) setState(() => _hasError = true);
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${widget.count} 回'),
      ),
      body: Center(
        child: _hasError
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: Colors.white54, size: 48),
                  SizedBox(height: 12),
                  Text('動画を読み込めませんでした',
                      style: TextStyle(color: Colors.white54)),
                ],
              )
            : !_initialized
                ? const CircularProgressIndicator(color: Colors.white)
                : GestureDetector(
                    onTap: () {
                      setState(() {
                        _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
                      });
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: _ctrl.value.aspectRatio,
                          child: VideoPlayer(_ctrl),
                        ),
                        if (!_ctrl.value.isPlaying)
                          const Icon(Icons.play_circle_fill,
                              size: 64, color: Colors.white70),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: VideoProgressIndicator(
                            _ctrl,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: Colors.green,
                              bufferedColor: Colors.white30,
                              backgroundColor: Colors.white10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
