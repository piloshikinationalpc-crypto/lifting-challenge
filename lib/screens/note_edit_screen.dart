import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/soccer_note.dart';
import '../services/note_service.dart';
import 'tactical_board_screen.dart';

class NoteEditScreen extends StatefulWidget {
  final SoccerNote? note;
  final NoteType type;
  final String groupId;
  final List<NoteTask> initialTasks;

  const NoteEditScreen({
    super.key,
    this.note,
    required this.type,
    required this.groupId,
    this.initialTasks = const [],
  });

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late NoteType _type;
  late DateTime _date;
  late List<String> _goals;
  late List<NoteTask> _tasks;
  late List<String> _goodPointsList;
  late List<NoteTask> _improvementTasks;
  late int _rating;
  late TextEditingController _memoCtrl;

  // 試合専用
  late TextEditingController _opponentCtrl;
  late TextEditingController _scoreHomeCtrl;
  late TextEditingController _scoreAwayCtrl;
  late List<String> _positions;
  late TextEditingController _goodPlaysCtrl;
  late TextEditingController _tacticsCtrl;

  String? _tacticalMapId;
  bool _saving = false;

  static const _positionOptions = ['GK', 'CB', 'SB', 'MF', 'OH', 'FW', 'その他'];

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    _type = widget.type;
    _date = n?.date ?? DateTime.now();
    _goals = List.from(n?.goals ?? []);
    _tasks = List.from(n?.tasks.isNotEmpty == true ? n!.tasks : widget.initialTasks);
    _goodPointsList = List.from(n?.goodPointsList ?? []);
    _improvementTasks = List.from(n?.improvementTasks ?? []);
    _rating = n?.rating ?? 70;
    _memoCtrl = TextEditingController(text: n?.memo ?? '');
    _opponentCtrl = TextEditingController(text: n?.opponent ?? '');
    final scoreParts = (n?.score ?? '').split('-');
    _scoreHomeCtrl = TextEditingController(text: scoreParts.length == 2 ? scoreParts[0] : '');
    _scoreAwayCtrl = TextEditingController(text: scoreParts.length == 2 ? scoreParts[1] : '');
    _positions = List.from(n?.positions ?? []);
    _goodPlaysCtrl = TextEditingController(text: n?.goodPlays ?? '');
    _tacticsCtrl = TextEditingController(text: n?.tactics ?? '');
    _tacticalMapId = n?.tacticalMapId;
  }

  @override
  void dispose() {
    _memoCtrl.dispose();
    _opponentCtrl.dispose();
    _scoreHomeCtrl.dispose();
    _scoreAwayCtrl.dispose();
    _goodPlaysCtrl.dispose();
    _tacticsCtrl.dispose();
    super.dispose();
  }

  SoccerNote _buildNote() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return SoccerNote(
      id: widget.note?.id,
      uid: uid,
      groupId: widget.groupId,
      type: _type,
      date: _date,
      createdAt: widget.note?.createdAt ?? DateTime.now(),
      goals: _goals,
      tasks: _tasks,
      goodPointsList: _goodPointsList,
      improvementTasks: _improvementTasks,
      rating: _rating,
      memo: _memoCtrl.text.trim(),
      opponent: _opponentCtrl.text.trim().isEmpty ? null : _opponentCtrl.text.trim(),
      score: (_scoreHomeCtrl.text.isEmpty && _scoreAwayCtrl.text.isEmpty)
          ? null
          : '${_scoreHomeCtrl.text.isEmpty ? '0' : _scoreHomeCtrl.text}-${_scoreAwayCtrl.text.isEmpty ? '0' : _scoreAwayCtrl.text}',
      positions: _positions,
      goodPlays: _goodPlaysCtrl.text.trim().isEmpty ? null : _goodPlaysCtrl.text.trim(),
      tactics: _tacticsCtrl.text.trim().isEmpty ? null : _tacticsCtrl.text.trim(),
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
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await NoteService().deleteNote(id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('削除失敗: $e')));
      }
    }
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

  void _showRatingPicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        int tempRating = _rating;
        return SizedBox(
          height: 280,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('キャンセル'),
                    ),
                    const Text('今日の点数', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        setState(() => _rating = tempRating);
                        Navigator.pop(context);
                      },
                      child: const Text('決定'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  scrollController:
                      FixedExtentScrollController(initialItem: tempRating),
                  itemExtent: 40,
                  onSelectedItemChanged: (v) => tempRating = v,
                  children: List.generate(
                    101,
                    (i) => Center(child: Text('$i 点', style: const TextStyle(fontSize: 20))),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _addListItem(List<String> list, String hint, VoidCallback onAdded) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                list.add(ctrl.text.trim());
                onAdded();
              }
              Navigator.pop(context);
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  void _addTask(List<NoteTask> list) {
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
                setState(() => list.add(NoteTask(text: ctrl.text.trim())));
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
                    Icon(Icons.calendar_today, size: 20,
                        color: isMatch ? Colors.orange : Colors.green),
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
                                  selected ? _positions.remove(p) : _positions.add(p);
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

            // 今日の点数（練習のみ）
            if (!isMatch) ...[
              _SectionTitle('今日の点数'),
              _SectionCard(
                child: InkWell(
                  onTap: _showRatingPicker,
                  child: Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber.shade600, size: 22),
                      const SizedBox(width: 8),
                      Text('$_rating 点',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      const Icon(Icons.edit, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],

            // 目標
            _SectionTitle(isMatch ? '試合の目標' : '今日の目標'),
            _SectionCard(
              child: Column(
                children: [
                  ..._goals.asMap().entries.map((e) => _StringRow(
                        text: e.value,
                        color: isMatch ? Colors.orange : Colors.green,
                        onDelete: () => setState(() => _goals.removeAt(e.key)),
                      )),
                  TextButton.icon(
                    onPressed: () => _addListItem(
                      _goals,
                      isMatch ? '例: ドリブルで1人抜く' : '例: パスの精度を上げる',
                      () => setState(() {}),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('目標を追加'),
                  ),
                ],
              ),
            ),

            // 課題リスト
            _SectionTitle('課題リスト'),
            _SectionCard(
              child: Column(
                children: [
                  ..._tasks.asMap().entries.map((e) {
                    final task = e.value;
                    return _TaskRow(
                      task: task,
                      color: isMatch ? Colors.orange : Colors.green,
                      onChanged: (done) =>
                          setState(() => _tasks[e.key] = task.copyWith(done: done)),
                      onDelete: () => setState(() => _tasks.removeAt(e.key)),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () => _addTask(_tasks),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('課題を追加'),
                  ),
                ],
              ),
            ),

            // よかった点
            _SectionTitle(isMatch ? 'よかったプレー' : 'よかった点'),
            _SectionCard(
              child: Column(
                children: [
                  ..._goodPointsList.asMap().entries.map((e) => _StringRow(
                        text: e.value,
                        color: Colors.amber.shade700,
                        onDelete: () => setState(() => _goodPointsList.removeAt(e.key)),
                      )),
                  TextButton.icon(
                    onPressed: () => _addListItem(
                      _goodPointsList,
                      '例: 相手を抜けた',
                      () => setState(() {}),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('よかった点を追加'),
                  ),
                ],
              ),
            ),

            // 改善点 or 戦術メモ
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
                child: Column(
                  children: [
                    ..._improvementTasks.asMap().entries.map((e) {
                      final task = e.value;
                      return _TaskRow(
                        task: task,
                        color: Colors.orange,
                        onChanged: (done) => setState(
                            () => _improvementTasks[e.key] = task.copyWith(done: done)),
                        onDelete: () => setState(() => _improvementTasks.removeAt(e.key)),
                      );
                    }),
                    TextButton.icon(
                      onPressed: () => _addTask(_improvementTasks),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('改善点を追加'),
                    ),
                  ],
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

            // 戦術マップ
            _SectionTitle('戦術マップ'),
            _SectionCard(
              child: InkWell(
                onTap: () async {
                  final mapId = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TacticalBoardScreen(
                        groupId: widget.groupId,
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

// ───────── 補助ウィジェット ─────────

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

  const _Field({required this.controller, required this.label, required this.hint, this.maxLines = 1});

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
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
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

class _StringRow extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback onDelete;

  const _StringRow({required this.text, required this.color, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        IconButton(
          icon: const Icon(Icons.close, size: 18, color: Colors.grey),
          onPressed: onDelete,
        ),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  final NoteTask task;
  final Color color;
  final ValueChanged<bool> onChanged;
  final VoidCallback onDelete;

  const _TaskRow({
    required this.task,
    required this.color,
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
          activeColor: color,
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
