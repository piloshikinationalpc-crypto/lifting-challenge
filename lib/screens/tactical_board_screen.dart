import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/tactical_map.dart';
import '../services/tactical_map_service.dart';
import '../services/storage_service.dart';

enum _DrawMode { move, arrow, zigzag, dotted }

// ───────── パスユーティリティ（トップレベル） ─────────

List<Offset> _resamplePath(List<Offset> points, double spacing) {
  if (points.length < 2) return points;
  final result = [points.first];
  double accumulated = 0;
  for (int i = 1; i < points.length; i++) {
    final seg = points[i] - points[i - 1];
    final segLen = seg.distance;
    if (segLen < 0.001) continue;
    double t = 0;
    while (accumulated + (segLen - t) >= spacing) {
      t += spacing - accumulated;
      accumulated = 0;
      result.add(points[i - 1] + seg * (t / segLen));
    }
    accumulated += segLen - t;
  }
  return result;
}

List<Offset> _toZigzag(List<Offset> raw) {
  final pts = _resamplePath(raw, 10.0);
  if (pts.length < 3) return pts;
  const amplitude = 7.0;
  final result = <Offset>[];
  for (int i = 0; i < pts.length; i++) {
    if (i == 0 || i == pts.length - 1) {
      result.add(pts[i]);
      continue;
    }
    final prev = pts[i - 1];
    final next = pts[i + 1];
    final dx = next.dx - prev.dx;
    final dy = next.dy - prev.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 0.001) { result.add(pts[i]); continue; }
    final perpX = -dy / len;
    final perpY = dx / len;
    final sign = i.isOdd ? 1.0 : -1.0;
    result.add(Offset(pts[i].dx + perpX * amplitude * sign,
                      pts[i].dy + perpY * amplitude * sign));
  }
  return result;
}

Path _dashPath(Path source, {double dashLen = 9.0, double gapLen = 6.0}) {
  final result = Path();
  for (final metric in source.computeMetrics()) {
    double distance = 0;
    bool draw = true;
    while (distance < metric.length) {
      final len = draw ? dashLen : gapLen;
      if (draw) {
        result.addPath(
          metric.extractPath(distance, (distance + len).clamp(0, metric.length)),
          Offset.zero,
        );
      }
      distance += len;
      draw = !draw;
    }
  }
  return result;
}

// ───────── 画面 ─────────

class TacticalBoardScreen extends StatefulWidget {
  final String groupId;
  final String? linkedMapId;
  final String? noteId;

  const TacticalBoardScreen({
    super.key,
    required this.groupId,
    this.linkedMapId,
    this.noteId,
  });

  @override
  State<TacticalBoardScreen> createState() => _TacticalBoardScreenState();
}

class _TacticalBoardScreenState extends State<TacticalBoardScreen> {
  static const _arrowColors = [
    Colors.white,
    Colors.yellow,
    Colors.red,
    Colors.cyan,
  ];

  late TacticalMap _map;
  _DrawMode _drawMode = _DrawMode.move;
  int _arrowColorIndex = 0;
  List<Offset> _currentPath = [];
  String? _draggingId;
  bool _overTrash = false;
  bool _loading = true;
  bool _saving = false;

  final _fieldKey = GlobalKey();
  final _repaintKey = GlobalKey();
  Size _fieldSize = Size.zero;

  Rect get _trashRect {
    if (_fieldSize == Size.zero) return Rect.zero;
    return Rect.fromLTWH(
      _fieldSize.width - 56 - 16,
      _fieldSize.height - 56 - 16,
      56, 56,
    );
  }

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  Future<void> _initMap() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    if (widget.linkedMapId != null) {
      final loaded = await TacticalMapService().getMap(widget.linkedMapId!);
      if (loaded != null) {
        setState(() { _map = loaded; _loading = false; });
        return;
      }
    }
    setState(() {
      _map = TacticalMap(
        uid: uid,
        groupId: widget.groupId,
        createdAt: DateTime.now(),
        noteId: widget.noteId,
        ballX: 0.5,
        ballY: 0.5,
      );
      _loading = false;
    });
  }

  void _onPanStart(DragStartDetails d) {
    final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(d.globalPosition);
    final size = box.size;
    _fieldSize = size;

    if (_drawMode != _DrawMode.move) {
      setState(() => _currentPath = [local]);
      return;
    }

    const hitR = 24.0;
    for (final p in _map.players) {
      final pos = Offset(p.x * size.width, p.y * size.height);
      if ((local - pos).distance < hitR) {
        setState(() => _draggingId = p.id);
        return;
      }
    }
    if (_map.ballX != null && _map.ballY != null) {
      final bPos = Offset(_map.ballX! * size.width, _map.ballY! * size.height);
      if ((local - bPos).distance < hitR) {
        setState(() => _draggingId = 'ball');
        return;
      }
    }
    for (int i = 0; i < _map.ghostBalls.length; i++) {
      final g = _map.ghostBalls[i];
      final gPos = Offset(g[0] * size.width, g[1] * size.height);
      if ((local - gPos).distance < hitR) {
        setState(() => _draggingId = 'ghost_$i');
        return;
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(d.globalPosition);
    final size = box.size;

    if (_drawMode != _DrawMode.move) {
      setState(() => _currentPath.add(local));
      return;
    }

    if (_draggingId == null) return;

    final overTrash = _trashRect.contains(local);
    final rel = Offset(
      (local.dx / size.width).clamp(0.0, 1.0),
      (local.dy / size.height).clamp(0.0, 1.0),
    );

    setState(() {
      _overTrash = overTrash;
      if (!overTrash) {
        if (_draggingId == 'ball') {
          _map = _map.copyWith(ballX: rel.dx, ballY: rel.dy);
        } else if (_draggingId!.startsWith('ghost_')) {
          final idx = int.parse(_draggingId!.split('_')[1]);
          final ghosts = [..._map.ghostBalls];
          if (idx < ghosts.length) ghosts[idx] = [rel.dx, rel.dy];
          _map = _map.copyWith(ghostBalls: ghosts);
        } else {
          final players = _map.players.map((p) {
            if (p.id == _draggingId) return p.copyWith(x: rel.dx, y: rel.dy);
            return p;
          }).toList();
          _map = _map.copyWith(players: players);
        }
      }
    });
  }

  void _onPanEnd(DragEndDetails _) {
    if (_drawMode != _DrawMode.move) {
      if (_currentPath.length >= 2) {
        final size = _fieldSize;
        final pts = _currentPath
            .map((o) => [o.dx / size.width, o.dy / size.height])
            .toList();
        final style = _drawMode == _DrawMode.zigzag
            ? ArrowPathStyle.zigzag
            : _drawMode == _DrawMode.dotted
                ? ArrowPathStyle.dotted
                : ArrowPathStyle.arrow;
        final newArrows = [
          ..._map.arrows,
          ArrowPath(points: pts, colorIndex: _arrowColorIndex, style: style),
        ];
        setState(() {
          _map = _map.copyWith(arrows: newArrows);
          _currentPath = [];
        });
      } else {
        setState(() => _currentPath = []);
      }
      return;
    }

    if (_overTrash && _draggingId != null) {
      _deletePiece(_draggingId!);
    }
    setState(() {
      _draggingId = null;
      _overTrash = false;
      _currentPath = [];
    });
  }

  void _deletePiece(String id) {
    if (id == 'ball') {
      _map = _map.removeBall();
    } else if (id.startsWith('ghost_')) {
      final idx = int.parse(id.split('_')[1]);
      final ghosts = [..._map.ghostBalls]..removeAt(idx);
      _map = _map.copyWith(ghostBalls: ghosts);
    } else {
      final players = _map.players.where((p) => p.id != id).toList();
      _map = _map.copyWith(players: players);
    }
  }

  void _addPlayer(int team) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final existing = _map.players.where((p) => p.team == team).length;
    final players = [
      ..._map.players,
      PlayerPiece(id: id, team: team, x: 0.3 + team * 0.4, y: 0.5, label: '${existing + 1}'),
    ];
    setState(() => _map = _map.copyWith(players: players));
  }

  void _onAddBall() {
    if (_map.ballX == null) {
      setState(() => _map = _map.copyWith(ballX: 0.5, ballY: 0.5));
    } else {
      final ghosts = [..._map.ghostBalls, [0.5, 0.3]];
      setState(() => _map = _map.copyWith(ghostBalls: ghosts));
    }
  }

  void _undoArrow() {
    if (_map.arrows.isEmpty) return;
    final arrows = [..._map.arrows]..removeLast();
    setState(() => _map = _map.copyWith(arrows: arrows));
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('全部消しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          TextButton(
            onPressed: () {
              final uid = FirebaseAuth.instance.currentUser!.uid;
              setState(() => _map = TacticalMap(
                    id: _map.id,
                    uid: uid,
                    groupId: _map.groupId,
                    courtType: _map.courtType,
                    createdAt: _map.createdAt,
                    noteId: _map.noteId,
                    ballX: 0.5,
                    ballY: 0.5,
                  ));
              Navigator.pop(context);
            },
            child: const Text('消す', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<String?> _captureFieldImage() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      return await StorageService()
          .uploadTacticalMapImage(byteData.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final imageUrl = await _captureFieldImage();
      final mapWithImage = imageUrl != null ? _map.copyWith(imageUrl: imageUrl) : _map;
      final id = await TacticalMapService().saveMap(mapWithImage);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存しました！')));
        Navigator.pop(context, id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失敗: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        title: const Text('戦術ボード'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _map = _map.copyWith(
                  courtType: _map.courtType == CourtType.full
                      ? CourtType.half
                      : CourtType.full,
                )),
            child: Text(
              _map.courtType == CourtType.full ? '全面' : 'ハーフ',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: '矢印を1本消す',
            onPressed: _undoArrow,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: '全部消す',
            onPressed: _clearAll,
          ),
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.save),
                  tooltip: '保存',
                  onPressed: _save,
                ),
        ],
      ),
      body: Column(
        children: [
          // モード切替バー
          Container(
            color: Colors.grey.shade800,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _ModeButton(
                  icon: Icons.open_with,
                  label: '移動',
                  selected: _drawMode == _DrawMode.move,
                  onTap: () => setState(() => _drawMode = _DrawMode.move),
                ),
                const SizedBox(width: 8),
                _ModeButton(
                  icon: Icons.gesture,
                  label: '矢印',
                  selected: _drawMode == _DrawMode.arrow,
                  onTap: () => setState(() => _drawMode = _DrawMode.arrow),
                ),
                const SizedBox(width: 8),
                _ModeButton(
                  icon: Icons.timeline,
                  label: 'ジグザグ',
                  selected: _drawMode == _DrawMode.zigzag,
                  onTap: () => setState(() => _drawMode = _DrawMode.zigzag),
                ),
                const SizedBox(width: 8),
                _ModeButton(
                  icon: Icons.more_horiz,
                  label: '点線',
                  selected: _drawMode == _DrawMode.dotted,
                  onTap: () => setState(() => _drawMode = _DrawMode.dotted),
                ),
                if (_drawMode != _DrawMode.move) ...[
                  const SizedBox(width: 12),
                  ..._arrowColors.asMap().entries.map((e) => GestureDetector(
                        onTap: () => setState(() => _arrowColorIndex = e.key),
                        child: Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: e.value,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _arrowColorIndex == e.key
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      )),
                ],
              ],
            ),
          ),

          // フィールド
          Expanded(
            child: Stack(
              children: [
                RepaintBoundary(
                  key: _repaintKey,
                  child: GestureDetector(
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    child: Container(
                      key: _fieldKey,
                      child: CustomPaint(
                        painter: _FieldPainter(
                          _map,
                          _currentPath,
                          _arrowColors,
                          _drawMode,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
                if (_draggingId != null)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: _TrashZone(isOver: _overTrash),
                  ),
              ],
            ),
          ),

          // 下部ツールバー
          Container(
            color: Colors.grey.shade800,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _AddButton(
                  label: '＋自チーム',
                  color: Colors.red.shade400,
                  onTap: () => _addPlayer(0),
                ),
                _AddButton(
                  label: '＋相手チーム',
                  color: Colors.blue.shade400,
                  onTap: () => _addPlayer(1),
                ),
                _AddButton(
                  label: _map.ballX == null ? '⚽ ボール' : '⚽ ゴースト',
                  color: Colors.white,
                  textColor: Colors.black,
                  onTap: _onAddBall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────── フィールド描画 ─────────

class _FieldPainter extends CustomPainter {
  final TacticalMap map;
  final List<Offset> currentPath;
  final List<Color> arrowColors;
  final _DrawMode drawMode;

  _FieldPainter(this.map, this.currentPath, this.arrowColors, this.drawMode);

  @override
  void paint(Canvas canvas, Size size) {
    _drawField(canvas, size);
    _drawArrows(canvas, size);
    if (currentPath.length >= 2) {
      _drawStyledPath(canvas, currentPath, Colors.white70, size,
          drawMode == _DrawMode.arrow
              ? ArrowPathStyle.arrow
              : drawMode == _DrawMode.zigzag
                  ? ArrowPathStyle.zigzag
                  : ArrowPathStyle.dotted,
          isPreview: true);
    }
    _drawPlayers(canvas, size);
    for (final g in map.ghostBalls) {
      _drawBall(canvas, size, g[0], g[1], ghost: true);
    }
    if (map.ballX != null && map.ballY != null) {
      _drawBall(canvas, size, map.ballX!, map.ballY!);
    }
  }

  void _drawField(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF2E7D32));
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    if (map.courtType == CourtType.full) {
      _drawFullCourt(canvas, size, line);
    } else {
      _drawHalfCourt(canvas, size, line);
    }
  }

  void _drawFullCourt(Canvas canvas, Size size, Paint line) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), line);
    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), line);
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.12, line);
    canvas.drawCircle(Offset(w / 2, h / 2), 2, Paint()..color = Colors.white);
    final penW = w * 0.6;
    final penH = h * 0.18;
    canvas.drawRect(Rect.fromLTWH((w - penW) / 2, 0, penW, penH), line);
    final goalW = w * 0.3;
    final goalH = h * 0.08;
    canvas.drawRect(Rect.fromLTWH((w - goalW) / 2, 0, goalW, goalH), line);
    canvas.drawRect(Rect.fromLTWH((w - penW) / 2, h - penH, penW, penH), line);
    canvas.drawRect(Rect.fromLTWH((w - goalW) / 2, h - goalH, goalW, goalH), line);
  }

  void _drawHalfCourt(Canvas canvas, Size size, Paint line) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), line);
    canvas.drawLine(Offset(0, h), Offset(w, h), line);
    final path = Path()
      ..addArc(Rect.fromCircle(center: Offset(w / 2, h), radius: w * 0.12), pi, pi);
    canvas.drawPath(path, line);
    canvas.drawCircle(Offset(w / 2, h), 2, Paint()..color = Colors.white);
    final penW = w * 0.6;
    final penH = h * 0.22;
    canvas.drawRect(Rect.fromLTWH((w - penW) / 2, 0, penW, penH), line);
    final goalW = w * 0.3;
    final goalH = h * 0.1;
    canvas.drawRect(Rect.fromLTWH((w - goalW) / 2, 0, goalW, goalH), line);
  }

  void _drawArrows(Canvas canvas, Size size) {
    for (final arrow in map.arrows) {
      if (arrow.points.length < 2) continue;
      final color = arrowColors[arrow.colorIndex % arrowColors.length];
      final offsets = arrow.points
          .map((p) => Offset(p[0] * size.width, p[1] * size.height))
          .toList();
      _drawStyledPath(canvas, offsets, color, size, arrow.style);
    }
  }

  void _drawStyledPath(
    Canvas canvas,
    List<Offset> points,
    Color color,
    Size size,
    ArrowPathStyle style, {
    bool isPreview = false,
  }) {
    if (points.length < 2) return;
    final alpha = isPreview ? 0.6 : 0.9;
    final paint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final List<Offset> drawPoints;
    if (style == ArrowPathStyle.zigzag) {
      drawPoints = _toZigzag(points);
    } else {
      drawPoints = points;
    }

    final path = Path()..moveTo(drawPoints.first.dx, drawPoints.first.dy);
    for (int i = 1; i < drawPoints.length; i++) {
      path.lineTo(drawPoints[i].dx, drawPoints[i].dy);
    }

    if (style == ArrowPathStyle.dotted) {
      canvas.drawPath(_dashPath(path), paint);
    } else {
      canvas.drawPath(path, paint);
    }

    // 矢印の先端（zigzagは元のpointsで方向を計算）
    final last = points.last;
    final prev = points[points.length > 5 ? points.length - 5 : 0];
    final angle = atan2(last.dy - prev.dy, last.dx - prev.dx);
    const aLen = 10.0;
    const aAngle = 0.5;
    final p1 = Offset(last.dx - aLen * cos(angle - aAngle), last.dy - aLen * sin(angle - aAngle));
    final p2 = Offset(last.dx - aLen * cos(angle + aAngle), last.dy - aLen * sin(angle + aAngle));
    final arrowPaint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(last, p1, arrowPaint);
    canvas.drawLine(last, p2, arrowPaint);
  }

  void _drawPlayers(Canvas canvas, Size size) {
    for (final p in map.players) {
      final pos = Offset(p.x * size.width, p.y * size.height);
      final color = p.team == 0 ? Colors.red.shade400 : Colors.blue.shade400;
      canvas.drawCircle(pos, 18, Paint()..color = color);
      canvas.drawCircle(pos, 18,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      final tp = TextPainter(
        text: TextSpan(
          text: p.label,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _drawBall(Canvas canvas, Size size, double rx, double ry, {bool ghost = false}) {
    final pos = Offset(rx * size.width, ry * size.height);
    final alpha = ghost ? 0.35 : 1.0;
    canvas.drawCircle(pos, 12, Paint()..color = Colors.white.withValues(alpha: alpha));
    canvas.drawCircle(pos, 12,
        Paint()
          ..color = Colors.black54.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    final tp = TextPainter(
      text: TextSpan(
        text: '⚽',
        style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: alpha)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_FieldPainter old) => true;
}

// ───────── ゴミ箱オーバーレイ ─────────

class _TrashZone extends StatelessWidget {
  final bool isOver;
  const _TrashZone({required this.isOver});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: isOver ? Colors.red : Colors.grey.shade700.withValues(alpha: 0.85),
        shape: BoxShape.circle,
        border: Border.all(
          color: isOver ? Colors.red.shade200 : Colors.grey.shade500,
          width: 2,
        ),
      ),
      child: Icon(
        Icons.delete,
        color: isOver ? Colors.white : Colors.grey.shade300,
        size: 26,
      ),
    );
  }
}

// ───────── 補助ウィジェット ─────────

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.green : Colors.grey.shade700,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 3),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _AddButton({
    required this.label,
    required this.color,
    this.textColor = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(color: textColor == Colors.white ? color : textColor,
              fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
