import 'package:cloud_firestore/cloud_firestore.dart';

enum NoteType { practice, match }

class NoteTask {
  final String text;
  final bool done;

  NoteTask({required this.text, this.done = false});

  NoteTask copyWith({String? text, bool? done}) =>
      NoteTask(text: text ?? this.text, done: done ?? this.done);

  Map<String, dynamic> toMap() => {'text': text, 'done': done};

  factory NoteTask.fromMap(Map<String, dynamic> m) =>
      NoteTask(text: m['text'] as String, done: (m['done'] as bool?) ?? false);
}

class SoccerNote {
  final String? id;
  final String uid;
  final NoteType type;
  final DateTime date;
  final DateTime createdAt;

  // 共通フィールド
  final String goal;
  final List<NoteTask> tasks;
  final String goodPoints;
  final String improvements;
  final String memo;

  // 試合ノート専用
  final String? opponent;
  final String? score;
  final List<String> positions;
  final String? goodPlays;
  final String? tactics;

  // AI
  final String? aiAdvice;

  // 戦術マップ連携
  final String? tacticalMapId;

  SoccerNote({
    this.id,
    required this.uid,
    required this.type,
    required this.date,
    required this.createdAt,
    this.goal = '',
    this.tasks = const [],
    this.goodPoints = '',
    this.improvements = '',
    this.memo = '',
    this.opponent,
    this.score,
    this.positions = const [],
    this.goodPlays,
    this.tactics,
    this.aiAdvice,
    this.tacticalMapId,
  });

  factory SoccerNote.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SoccerNote(
      id: doc.id,
      uid: d['uid'] as String,
      type: (d['type'] as String?) == 'match' ? NoteType.match : NoteType.practice,
      date: (d['date'] as Timestamp).toDate(),
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      goal: d['goal'] as String? ?? '',
      tasks: ((d['tasks'] as List?)?.cast<Map<String, dynamic>>() ?? [])
          .map(NoteTask.fromMap)
          .toList(),
      goodPoints: d['goodPoints'] as String? ?? '',
      improvements: d['improvements'] as String? ?? '',
      memo: d['memo'] as String? ?? '',
      opponent: d['opponent'] as String?,
      score: d['score'] as String?,
      positions: ((d['positions'] as List?)?.cast<String>()) ??
          (d['position'] != null ? [d['position'] as String] : []),
      goodPlays: d['goodPlays'] as String?,
      tactics: d['tactics'] as String?,
      aiAdvice: d['aiAdvice'] as String?,
      tacticalMapId: d['tacticalMapId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'type': type == NoteType.match ? 'match' : 'practice',
        'date': Timestamp.fromDate(date),
        'createdAt': Timestamp.fromDate(createdAt),
        'goal': goal,
        'tasks': tasks.map((t) => t.toMap()).toList(),
        'goodPoints': goodPoints,
        'improvements': improvements,
        'memo': memo,
        if (opponent != null) 'opponent': opponent,
        if (score != null) 'score': score,
        if (positions.isNotEmpty) 'positions': positions,
        if (goodPlays != null) 'goodPlays': goodPlays,
        if (tactics != null) 'tactics': tactics,
        if (aiAdvice != null) 'aiAdvice': aiAdvice,
        if (tacticalMapId != null) 'tacticalMapId': tacticalMapId,
      };

  SoccerNote copyWith({
    String? id,
    NoteType? type,
    DateTime? date,
    String? goal,
    List<NoteTask>? tasks,
    String? goodPoints,
    String? improvements,
    String? memo,
    String? opponent,
    String? score,
    List<String>? positions,
    String? goodPlays,
    String? tactics,
    String? aiAdvice,
    String? tacticalMapId,
  }) =>
      SoccerNote(
        id: id ?? this.id,
        uid: uid,
        type: type ?? this.type,
        date: date ?? this.date,
        createdAt: createdAt,
        goal: goal ?? this.goal,
        tasks: tasks ?? this.tasks,
        goodPoints: goodPoints ?? this.goodPoints,
        improvements: improvements ?? this.improvements,
        memo: memo ?? this.memo,
        opponent: opponent ?? this.opponent,
        score: score ?? this.score,
        positions: positions ?? this.positions,
        goodPlays: goodPlays ?? this.goodPlays,
        tactics: tactics ?? this.tactics,
        aiAdvice: aiAdvice ?? this.aiAdvice,
        tacticalMapId: tacticalMapId ?? this.tacticalMapId,
      );
}
