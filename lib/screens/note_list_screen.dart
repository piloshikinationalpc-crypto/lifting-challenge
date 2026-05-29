import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/group.dart';
import '../models/soccer_note.dart';
import '../services/note_service.dart';
import 'note_edit_screen.dart';

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key});

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  List<SoccerNote> _notes = [];

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final groupId = GroupScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('サッカーノート'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: '目標一覧',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _SummaryScreen(
                  title: '目標一覧',
                  notes: _notes,
                  type: _SummaryType.goals,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.thumb_up_outlined),
            tooltip: 'よかった点一覧',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _SummaryScreen(
                  title: 'よかった点一覧',
                  notes: _notes,
                  type: _SummaryType.goodPoints,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.checklist),
            tooltip: '課題一覧',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _SummaryScreen(
                  title: '課題一覧',
                  notes: _notes,
                  type: _SummaryType.improvements,
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<SoccerNote>>(
        stream: NoteService().myNotes(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData) _notes = snapshot.data!;
          final notes = _notes;

          if (notes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.book_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('ノートがまだないよ！',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('右下の＋から追加しよう',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: notes.length,
            separatorBuilder: (_, i) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _NoteCard(note: notes[i], groupId: groupId),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'note_fab',
        onPressed: () => _showTypeSelector(context, groupId),
        icon: const Icon(Icons.add),
        label: const Text('ノートを書く'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showTypeSelector(BuildContext context, String groupId) {
    final practiceNotes = _notes
        .where((n) => n.type == NoteType.practice)
        .toList();
    final carryOver = practiceNotes.isNotEmpty
        ? practiceNotes.first.improvementTasks
            .where((t) => !t.done)
            .toList()
        : <NoteTask>[];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('どのノートを書く？',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              _TypeButton(
                icon: Icons.sports_soccer,
                label: carryOver.isNotEmpty
                    ? '練習ノート（前回の改善点${carryOver.length}件）'
                    : '練習ノート',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NoteEditScreen(
                        type: NoteType.practice,
                        groupId: groupId,
                        initialTasks: carryOver,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _TypeButton(
                icon: Icons.emoji_events,
                label: '試合ノート',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NoteEditScreen(
                        type: NoteType.match,
                        groupId: groupId,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────── まとめ画面 ─────────

enum _SummaryType { goals, goodPoints, improvements }

class _SummaryScreen extends StatelessWidget {
  final String title;
  final List<SoccerNote> notes;
  final _SummaryType type;

  const _SummaryScreen({
    required this.title,
    required this.notes,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy/MM/dd (E)', 'ja');
    final sorted = [...notes]..sort((a, b) => b.date.compareTo(a.date));

    final items = <({DateTime date, NoteType noteType, String text, bool? done})>[];
    for (final note in sorted) {
      switch (type) {
        case _SummaryType.goals:
          for (final g in note.goals) {
            items.add((date: note.date, noteType: note.type, text: g, done: null));
          }
        case _SummaryType.goodPoints:
          for (final g in note.goodPointsList) {
            items.add((date: note.date, noteType: note.type, text: g, done: null));
          }
        case _SummaryType.improvements:
          for (final t in note.improvementTasks) {
            items.add((date: note.date, noteType: note.type, text: t.text, done: t.done));
          }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: items.isEmpty
          ? Center(
              child: Text('まだ記録がないよ',
                  style: TextStyle(color: Colors.grey.shade500)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, i) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final item = items[i];
                final isMatch = item.noteType == NoteType.match;
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isMatch ? Colors.orange : Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isMatch ? '試合' : '練習',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    item.text,
                    style: TextStyle(
                      decoration: item.done == true ? TextDecoration.lineThrough : null,
                      color: item.done == true ? Colors.grey : null,
                    ),
                  ),
                  subtitle: Text(fmt.format(item.date),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  trailing: item.done != null
                      ? Icon(
                          item.done! ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: item.done! ? Colors.green : Colors.grey,
                          size: 20,
                        )
                      : null,
                );
              },
            ),
    );
  }
}

// ───────── 補助ウィジェット ─────────

class _TypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontSize: 15)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final SoccerNote note;
  final String groupId;
  const _NoteCard({required this.note, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy/MM/dd (E)', 'ja');
    final isMatch = note.type == NoteType.match;
    final doneCount = note.tasks.where((t) => t.done).length;
    final totalCount = note.tasks.length;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NoteEditScreen(
              note: note,
              type: note.type,
              groupId: groupId,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isMatch ? Colors.orange.shade100 : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isMatch ? Icons.emoji_events : Icons.sports_soccer,
                  color: isMatch ? Colors.orange : Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isMatch ? Colors.orange : Colors.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isMatch ? '試合' : '練習',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(fmt.format(note.date),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        if (note.rating != null && !isMatch) ...[
                          const Spacer(),
                          Icon(Icons.star, size: 14, color: Colors.amber.shade600),
                          Text(' ${note.rating}点',
                              style: TextStyle(fontSize: 12, color: Colors.amber.shade700)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isMatch
                          ? 'vs ${note.opponent?.isNotEmpty == true ? note.opponent! : '相手未記入'}'
                          : note.goals.isNotEmpty
                              ? note.goals.first
                              : '目標未記入',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (totalCount > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: doneCount / totalCount,
                                backgroundColor: Colors.grey.shade200,
                                color: Colors.green,
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('$doneCount/$totalCount',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
