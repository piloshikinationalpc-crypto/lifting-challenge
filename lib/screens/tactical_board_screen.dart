import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/tactical_map.dart';
import '../services/tactical_map_service.dart';
import '../services/storage_service.dart';

class TacticalBoardScreen extends StatefulWidget {
  final String? linkedMapId;
  final String? noteId;

  const TacticalBoardScreen({super.key, this.linkedMapId, this.noteId});

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
  bool _arrowMode = false;
  int _arrowColorIndex = 0;
  List<Offset> _currentArrow = [];
  String? _draggingId; // player id or 'ball'
  bool _loading = true;
  bool _saving = false;

  final _fieldKey = GlobalKey();
  final _repaintKey = GlobalKey();
  Size _fieldSize = Size.zero;

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
        setState(() {
          _map = loaded;
          _loading = false;
        });
        return;
      }
    }
    setState(() {
      _map = TacticalMap(
        uid: uid,
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

    if (_arrowMode) {
      setState(() => _currentArrow = [local]);
      return;
    }

    // ドラッグ対象を探す（プレイヤー → ボール）
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
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(d.globalPosition);
    final size = box.size;

    if (_arrowMode) {
      setState(() => _currentArrow.add(local));
      return;
    }

    if (_draggingId == null) return;
    final rel = Offset(
      (local.dx / size.width).clamp(0.0, 1.0),
      (local.dy / size.height).clamp(0.0, 1.0),
    );
    if (_draggingId == 'ball') {
      setState(() => _map = _map.copyWith(ballX: rel.dx, ballY: rel.dy));
    } else {
      final players = _map.players.map((p) {
        if (p.id == _draggingId) return p.copyWith(x: rel.dx, y: rel.dy);
        return p;
      }).toList();
      setState(() => _map = _map.copyWith(players: players));
    }
  }

  void _onPanEnd(DragEndDetails _) {
    if (_arrowMode && _currentArrow.length >= 2) {
      final size = _fieldSize;
      final points = _currentArrow
          .map((o) => [o.dx / size.width, o.dy / size.height])
          .toList();
      final newArrows = [..._map.arrows, ArrowPath(points: points, colorIndex: _arrowColorIndex)];
      setState(() {
        _map = _map.copyWith(arrows: newArrows);
        _currentArrow = [];
      });
    } else {
      setState(() {
        _currentArrow = [];
        _draggingId = null;
      });
    }
  }

  void _addPlayer(int team) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final existing = _map.players.where((p) => p.team == team).length;
    final label = '${existing + 1}';
    final players = [
      ..._map.players,
      PlayerPiece(id: id, team: team, x: 0.3 + team * 0.4, y: 0.5, label: label),
    ];
    setState(() => _map = _map.copyWith(players: players));
  }

  void _addBall() {
    setState(() => _map = _map.copyWith(ballX: 0.5, ballY: 0.5));
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
      final mapWithImage = imageUrl != null
          ? _map.copyWith(imageUrl: imageUrl)
          : _map;
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
          // コート切替
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
          // 矢印アンドゥ
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: '矢印を1本消す',
            onPressed: _undoArrow,
          ),
          // 全消し
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: '全部消す',
            onPressed: _clearAll,
          ),
          // 保存
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
                // 移動 / 矢印 トグル
                _ModeButton(
                  icon: Icons.open_with,
                  label: '移動',
                  selected: !_arrowMode,
                  onTap: () => setState(() => _arrowMode = false),
                ),
                const SizedBox(width: 8),
                _ModeButton(
                  icon: Icons.gesture,
                  label: '矢印',
                  selected: _arrowMode,
                  onTap: () => setState(() => _arrowMode = true),
                ),
                if (_arrowMode) ...[
                  const SizedBox(width: 12),
                  const Text('色:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(width: 6),
                  ..._arrowColors.asMap().entries.map((e) => GestureDetector(
                        onTap: () => setState(() => _arrowColorIndex = e.key),
                        child: Container(
                          width: 24,
                          height: 24,
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
            child: RepaintBoundary(
              key: _repaintKey,
              child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: Container(
                key: _fieldKey,
                child: CustomPaint(
                  painter: _FieldPainter(_map, _currentArrow, _arrowColors),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
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
                  label: '⚽ボール',
                  color: Colors.white,
                  textColor: Colors.black,
                  onTap: _addBall,
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
  final List<Offset> currentArrow;
  final List<Color> arrowColors;

  _FieldPainter(this.map, this.currentArrow, this.arrowColors);

  @override
  void paint(Canvas canvas, Size size) {
    _drawField(canvas, size);
    _drawArrows(canvas, size);
    if (currentArrow.length >= 2) _drawArrowPath(canvas, currentArrow, Colors.white70, size, isPreview: true);
    _drawPlayers(canvas, size);
    if (map.ballX != null && map.ballY != null) {
      _drawBall(canvas, size, map.ballX!, map.ballY!);
    }
  }

  void _drawField(Canvas canvas, Size size) {
    final grass = Paint()..color = const Color(0xFF2E7D32);
    canvas.drawRect(Offset.zero & size, grass);

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

    // 外枠
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), line);
    // センターライン
    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), line);
    // センターサークル
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.12, line);
    canvas.drawCircle(Offset(w / 2, h / 2), 2, Paint()..color = Colors.white);

    // 上ゴールエリア
    final penW = w * 0.6;
    final penH = h * 0.18;
    canvas.drawRect(Rect.fromLTWH((w - penW) / 2, 0, penW, penH), line);
    final goalW = w * 0.3;
    final goalH = h * 0.08;
    canvas.drawRect(Rect.fromLTWH((w - goalW) / 2, 0, goalW, goalH), line);

    // 下ゴールエリア
    canvas.drawRect(Rect.fromLTWH((w - penW) / 2, h - penH, penW, penH), line);
    canvas.drawRect(Rect.fromLTWH((w - goalW) / 2, h - goalH, goalW, goalH), line);
  }

  void _drawHalfCourt(Canvas canvas, Size size, Paint line) {
    final w = size.width;
    final h = size.height;

    // 外枠
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), line);
    // ハーフライン（下）
    canvas.drawLine(Offset(0, h), Offset(w, h), line);
    // センターサークル（上半分のみ）
    final path = Path()
      ..addArc(
        Rect.fromCircle(center: Offset(w / 2, h), radius: w * 0.12),
        pi,
        pi,
      );
    canvas.drawPath(path, line);
    canvas.drawCircle(Offset(w / 2, h), 2, Paint()..color = Colors.white);

    // ゴールエリア
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
      _drawArrowPath(canvas, offsets, color, size);
    }
  }

  void _drawArrowPath(Canvas canvas, List<Offset> points, Color color, Size size,
      {bool isPreview = false}) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color.withValues(alpha: isPreview ? 0.6 : 0.9)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);

    // 矢印の先端
    final last = points.last;
    final prev = points[points.length > 5 ? points.length - 5 : 0];
    final angle = atan2(last.dy - prev.dy, last.dx - prev.dx);
    const aLen = 10.0;
    const aAngle = 0.5;
    final p1 = Offset(
      last.dx - aLen * cos(angle - aAngle),
      last.dy - aLen * sin(angle - aAngle),
    );
    final p2 = Offset(
      last.dx - aLen * cos(angle + aAngle),
      last.dy - aLen * sin(angle + aAngle),
    );
    final arrowPaint = Paint()
      ..color = color.withValues(alpha: isPreview ? 0.6 : 0.9)
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

      final fill = Paint()..color = color;
      canvas.drawCircle(pos, 18, fill);

      final border = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(pos, 18, border);

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

  void _drawBall(Canvas canvas, Size size, double rx, double ry) {
    final pos = Offset(rx * size.width, ry * size.height);
    final fill = Paint()..color = Colors.white;
    canvas.drawCircle(pos, 12, fill);
    final border = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(pos, 12, border);

    final tp = TextPainter(
      text: const TextSpan(text: '⚽', style: TextStyle(fontSize: 14)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_FieldPainter old) => true;
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.green : Colors.grey.shade700,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
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
        child: Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
