import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/soccer_note.dart';
import '../services/note_service.dart';
import '../services/gemini_service.dart';
import 'tactical_board_screen.dart';

class NoteEditScreen extends StatefulWidget {
  final SoccerNote? note;
  final NoteType type;

  const NoteEditScreen({super.key, this.note, required this.type});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late NoteType _type;
  late DateTime _date;
  late TextEditingController _goalCtrl;
  late TextEditingController _goodPointsCtrl;
  late TextEditingController _improvementsCtrl;
  late TextEditingController _memoCtrl;
  // 試合専用
  late TextEditingController _opponentCtrl;
  late TextEditingController _scoreHomeCtrl;
  late TextEditingController _scoreAwayCtrl;
  late List<String> _positions;

  static const _positionOptions = ['GK', 'CB', 'SB', 'MF', 'OH', 'FW', 'その他'];
  late TextEditingController _goodPlaysCtrl;
  late TextEditingController _tacticsCtrl;

  late List<NoteTask> _tasks;
  String? _aiAdvice;
  String? _tacticalMapId;
  bool _saving = false;
  bool _loadingAi = false;

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    _type = widget.type;
    _date = n?.date ?? DateTime.now();
    _goalCtrl = TextEditingController(text: n?.goal ?? '');
    _goodPointsCtrl = TextEditingController(text: n?.goodPoints ?? '');
    _improvementsCtrl = TextEditingController(text: n?.improvements ?? '');
    _memoCtrl = TextEditingController(text: n?.memo ?? '');
    _opponentCtrl = TextEditingController(text: n?.opponent ?? '');
    final scoreParts = (n?.score ?? '').split('-');
    _scoreHomeCtrl = TextEditingController(text: scoreParts.length == 2 ? scoreParts[0] : '');
    _scoreAwayCtrl = TextEditingController(text: scoreParts.length == 2 ? scoreParts[1] : '');
    _positions = List.from(n?.positions ?? []);
    _goodPlaysCtrl = TextEditingController(text: n?.goodPlays ?? '');
    _tacticsCtrl = TextEditingController(text: n?.tactics ?? '');
    _tasks = List.from(n?.tasks ?? []);
    _aiAdvice = n?.aiAdvice;
    _tacticalMapId = n?.tacticalMapId;
  }

  @override
  void dispose() {
    _goalCtrl.dispose();
    _goodPointsCtrl.dispose();
    _improvementsCtrl.dispose();
    _memoCtrl.dispose();
    _opponentCtrl.dispose();
    _scoreHomeCtrl.dispose();
    _scoreAwayCtrl.dispose();
    _goodPlaysCtrl.dispose();
    _tacticsCtrl.dispose();
    super.dispose();
  }

  SoccerNote _buildNote({String? id}) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return SoccerNote(
      id: id ?? widget.note?.id,
      uid: uid,
      type: _type,
      date: _date,
      createdAt: widget.note?.createdAt ?? DateTime.now(),
      goal: _goalCtrl.text.trim(),
      tasks: _tasks,
      goodPoints: _goodPointsCtrl.text.trim(),
      improvements: _improvementsCtrl.text.trim(),
      memo: _memoCtrl.text.trim(),
      opponent: _opponentCtrl.text.trim().isEmpty ? null : _opponentCtrl.text.trim(),
      score: (_scoreHomeCtrl.text.isEmpty && _scoreAwayCtrl.text.isEmpty)
          ? null
          : '${_scoreHomeCtrl.text.isEmpty ? '0' : _scoreHomeCtrl.text}-${_scoreAwayCtrl.text.isEmpty ? '0' : _scoreAwayCtrl.text}',
      positions: _positions,
      goodPlays: _goodPlaysCtrl.text.trim().isEmpty ? null : _goodPlaysCtrl.text.trim(),
      tactics: _tacticsCtrl.text.trim().isEmpty ? null : _tacticsCtrl.text.trim(),
      aiAdvice: _aiAdvice,
      tacticalMapId: _tacticalMapId,
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final service = NoteService();
      final note = _buildNote();
      if (note.id == null) {
        await service.addNote(note);
      } else {
        await service.updateNote(note);
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存しました！')));
        Navigator.pop(context);
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

  Future<void> _getAiAdvice() async {
    setState(() => _loadingAi = true);
    try {
      final note = _buildNote();
      final advice = await GeminiService().getSoccerNoteAdvice(note);
      setState(() => _aiAdvice = advice);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('AI取得失敗: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingAi = false);
    }
  }

  Future<void> _delete() async {
    final id = widget.note?.id;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除しますか？'),
        content: const Text('このノートを削除します。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('削除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    await NoteService().deleteNote(id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _addTask() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('課題を追加'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例: ドリブルを練習する'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() => _tasks.add(NoteTask(text: ctrl.text.trim())));
              }
              Navigator.pop(context);
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.note == null;
    final isMatch = _type == NoteType.match;
    final fmt = DateFormat('yyyy年MM月dd日 (E)', 'ja');

    return Scaffold(
      appBar: AppBar(
        title: Text(isMatch ? '試合ノート' : '練習ノート'),
        backgroundColor: isMatch ? Colors.orange : Colors.green,
        foregroundColor: Colors.white,
        actions: [
          if (!isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 日付
            _SectionCard(
              child: InkWell(
                onTap: _pickDate,
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(fmt.format(_date),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    const Icon(Icons.edit, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),

            // 試合専用フィールド
            if (isMatch) ...[
              _SectionTitle('試合情報'),
              _SectionCard(
                child: Column(
                  children: [
                    _Field(controller: _opponentCtrl, label: '対戦相手', hint: '例: ○○FC'),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          const Text('スコア', style: TextStyle(fontSize: 14, color: Colors.grey)),
                          const Spacer(),
                          _ScoreBox(controller: _scoreHomeCtrl, label: '自チーム'),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('−', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          ),
                          _ScoreBox(controller: _scoreAwayCtrl, label: '相手'),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ポジション',
                              style: TextStyle(fontSize: 14, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _positionOptions.map((p) {
                              final selected = _positions.contains(p);
                              return FilterChip(
                                label: Text(p),
                                selected: selected,
                                onSelected: (_) => setState(() {
                                  if (selected) {
                                    _positions.remove(p);
                                  } else {
                                    _positions.add(p);
                                  }
                                }),
                                selectedColor: Colors.orange.shade100,
                                checkmarkColor: Colors.orange.shade800,
                                labelStyle: TextStyle(
                                  color: selected ? Colors.orange.shade800 : null,
                                  fontWeight: selected ? FontWeight.bold : null,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 目標
            _SectionTitle(isMatch ? '試合の目標' : '今日の目標'),
            _SectionCard(
              child: _Field(
                controller: _goalCtrl,
                label: '',
                hint: isMatch ? '例: ドリブルで1人抜く' : '例: パスの精度を上げる',
                maxLines: 2,
              ),
            ),

            // 課題リスト
            _SectionTitle('課題リスト'),
            _SectionCard(
              child: Column(
                children: [
                  ..._tasks.asMap().entries.map((e) {
                    final i = e.key;
                    final task = e.value;
                    return _TaskRow(
                      task: task,
                      onChanged: (done) {
                        setState(() {
                          _tasks[i] = task.copyWith(done: done);
                        });
                      },
                      onDelete: () => setState(() => _tasks.removeAt(i)),
                    );
                  }),
                  TextButton.icon(
                    onPressed: _addTask,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('課題を追加'),
                  ),
                ],
              ),
            ),

            // よかった点
            _SectionTitle(isMatch ? 'よかったプレー' : 'よかった点'),
            _SectionCard(
              child: _Field(
                controller: isMatch ? _goodPlaysCtrl : _goodPointsCtrl,
                label: '',
                hint: '例: 相手を抜けた',
                maxLines: 3,
              ),
            ),

            // 改善点 / 戦術メモ
            if (isMatch) ...[
              _SectionTitle('戦術メモ'),
              _SectionCard(
                child: _Field(
                  controller: _tacticsCtrl,
                  label: '',
                  hint: '例: サイドを使った攻め',
                  maxLines: 3,
                ),
              ),
            ] else ...[
              _SectionTitle('次回への改善点'),
              _SectionCard(
                child: _Field(
                  controller: _improvementsCtrl,
                  label: '',
                  hint: '例: もっとポジショニングを意識する',
                  maxLines: 3,
                ),
              ),
            ],

            // 自由メモ
            _SectionTitle('自由メモ'),
            _SectionCard(
              child: _Field(
                controller: _memoCtrl,
                label: '',
                hint: '何でも書こう！',
                maxLines: 4,
              ),
            ),

            // 戦術マップリンク
            _SectionTitle('戦術マップ'),
            _SectionCard(
              child: InkWell(
                onTap: () async {
                  final mapId = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TacticalBoardScreen(
                        linkedMapId: _tacticalMapId,
                        noteId: widget.note?.id,
                      ),
                    ),
                  );
                  if (mapId != null) setState(() => _tacticalMapId = mapId);
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.sports_soccer,
                      color: _tacticalMapId != null ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _tacticalMapId != null ? '戦術マップあり（タップで編集）' : '戦術マップを作る',
                      style: TextStyle(
                        color: _tacticalMapId != null ? Colors.green : Colors.grey,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),

            // AIアドバイス
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loadingAi ? null : _getAiAdvice,
              icon: _loadingAi
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, color: Colors.deepPurple),
              label: Text(
                _loadingAi ? 'AIがアドバイス中...' : 'AIにアドバイスをもらう',
                style: const TextStyle(color: Colors.deepPurple),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.deepPurple),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),

            if (_aiAdvice != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.deepPurple.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🤖 ', style: TextStyle(fontSize: 20)),
                    Expanded(
                      child: Text(_aiAdvice!,
                          style: const TextStyle(fontSize: 14, height: 1.5)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: isMatch ? Colors.orange : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('保存する', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Text(text,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
              letterSpacing: 0.5)),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label.isEmpty ? null : label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _ScoreBox({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 56,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.orange, width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  final NoteTask task;
  final ValueChanged<bool> onChanged;
  final VoidCallback onDelete;

  const _TaskRow({
    required this.task,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: task.done,
          onChanged: (v) => onChanged(v ?? false),
          activeColor: Colors.green,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        Expanded(
          child: Text(
            task.text,
            style: TextStyle(
              decoration: task.done ? TextDecoration.lineThrough : null,
              color: task.done ? Colors.grey : null,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 18, color: Colors.grey),
          onPressed: onDelete,
        ),
      ],
    );
  }
}
