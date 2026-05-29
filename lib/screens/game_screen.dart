import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/lifting_record.dart';
import '../services/record_service.dart';

enum GameState { ready, playing, miss }

class GameScreen extends StatefulWidget {
  final String groupId;
  const GameScreen({super.key, required this.groupId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  GameState _state = GameState.ready;
  int _count = 0;
  int _bestThisSession = 0;

  // ボールのY位置 (0.0=頂点, 1.0=地面)
  double _ballY = 0.5;
  // ボールのY速度（正=落下）
  double _ballVelocity = 0.0;
  static const double _gravity = 0.004;
  // タップ可能な最小Y（ここより低くなったらタップ受付）
  static const double _tapZone = 0.50;

  Timer? _gameTimer;
  // ミスのタイムアウト: ボールが地面(Y>=1.0)に達したら終了
  late AnimationController _ballAnim;

  @override
  void initState() {
    super.initState();
    _ballAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_update);
  }

  void _startGame() {
    setState(() {
      _state = GameState.playing;
      _count = 0;
      _ballY = 0.5;
      _ballVelocity = 0.0;
    });
    _kick();
    _ballAnim.repeat();
  }

  void _kick() {
    // 上向きに弾く（キックの強さ）
    // ランダムジャンプ: 最小 -0.038、最大 -0.114（3倍）
    final minKick = 0.038;
    final maxKick = 0.114;
    _ballVelocity = -(minKick + Random().nextDouble() * (maxKick - minKick));
  }

  void _update() {
    if (_state != GameState.playing) return;
    setState(() {
      _ballVelocity += _gravity;
      _ballY += _ballVelocity;

      if (_ballY >= 1.0) {
        // 地面に落ちた→ミス
        _ballY = 1.0;
        _endGame();
      }
    });
  }

  void _onTap() {
    if (_state == GameState.ready) {
      _startGame();
      return;
    }
    if (_state != GameState.playing) return;

    if (_ballY >= _tapZone) {
      // タップ成功：ボールを蹴り上げる
      setState(() {
        _count++;
        if (_count > _bestThisSession) _bestThisSession = _count;
      });
      _kick();
    }
    // タップゾーン外は無視
  }

  void _endGame() {
    _ballAnim.stop();
    setState(() => _state = GameState.miss);

    if (_count > 0) {
      _saveRecord();
    }
  }

  Future<void> _saveRecord() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await RecordService().addRecord(LiftingRecord(
      uid: user.uid,
      groupId: widget.groupId,
      displayName: user.displayName ?? '名無し',
      count: _count,
      createdAt: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _ballAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final ballSize = 60.0;
    final areaHeight = size.height * 0.55;
    final ballTop = (_ballY * areaHeight) - ballSize / 2;

    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: const Text('リフティングゲーム'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: GestureDetector(
        onTapDown: (_) => _onTap(),
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            // スコア表示
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              color: Colors.green,
              child: Column(
                children: [
                  Text(
                    '$_count',
                    style: const TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'ベスト: $_bestThisSession',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            // ゲームフィールド
            Expanded(
              child: Stack(
                children: [
                  // 背景
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.blue.shade100, Colors.green.shade200],
                      ),
                    ),
                  ),

                  // ボール
                  if (_state == GameState.playing)
                    Positioned(
                      left: size.width / 2 - ballSize / 2,
                      top: ballTop.clamp(0.0, areaHeight - ballSize),
                      child: _BallWidget(size: ballSize),
                    ),

                  // タップゾーン表示
                  if (_state == GameState.playing)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: areaHeight * (1 - _tapZone),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.yellow.withValues(alpha: 0.15),
                          border: Border(
                            top: BorderSide(
                                color: Colors.yellow.shade700, width: 2),
                          ),
                        ),
                        child: const Center(
                          child: Text('ここでタップ！',
                              style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),

                  // オーバーレイ
                  if (_state != GameState.playing)
                    _Overlay(
                      state: _state,
                      count: _count,
                      best: _bestThisSession,
                      onStart: _startGame,
                    ),
                ],
              ),
            ),

            // 操作説明
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.green.shade800,
              child: const Text(
                'ボールが黄色いゾーンに入ったらタップ！',
                style: TextStyle(color: Colors.white, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BallWidget extends StatelessWidget {
  final double size;
  const _BallWidget({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: const Center(
        child: Text('⚽', style: TextStyle(fontSize: 32)),
      ),
    );
  }
}

class _Overlay extends StatelessWidget {
  final GameState state;
  final int count;
  final int best;
  final VoidCallback onStart;

  const _Overlay({
    required this.state,
    required this.count,
    required this.best,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final isMiss = state == GameState.miss;
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isMiss ? '落とした！' : 'リフティングゲーム',
              style: TextStyle(
                fontSize: isMiss ? 36 : 28,
                fontWeight: FontWeight.bold,
                color: isMiss ? Colors.red.shade300 : Colors.white,
              ),
            ),
            if (isMiss) ...[
              const SizedBox(height: 8),
              Text(
                '$count 回',
                style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              Text(
                count > 0 ? '記録に保存しました！' : '',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow),
              label: Text(isMiss ? 'もう一回' : 'スタート'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            if (!isMiss) ...[
              const SizedBox(height: 12),
              const Text(
                'タップしてボールを蹴り続けよう！',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
