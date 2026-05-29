import 'package:cloud_firestore/cloud_firestore.dart';

enum NoteType { practice, match }

class NoteTask {
  final String text;
  final bool done;
  final String? sourceNoteId;

  NoteTask({required this.text, this.done = false, this.sourceNoteId});

  NoteTask copyWith({String? text, bool? done}) =>
      NoteTask(text: text ?? this.text, done: done ?? this.done, sourceNoteId: sourceNoteId);

  Map<String, dynamic> toMap() => {
        'text': text,
        'done': done,
        if (sourceNoteId != null) 'sourceNoteId': sourceNoteId,
      };

  factory NoteTask.fromMap(Map<String, dynamic> m) => NoteTask(
        text: m['text'] as String,
        done: (m['done'] as bool?) ?? false,
        sourceNoteId: m['sourceNoteId'] as String?,
      );
}

class SoccerNote {
  final String? id;
  final String uid;
  final String groupId;
  final NoteType type;
  final DateTime date;
  final DateTime createdAt;

  final List<String> goals;
  final List<NoteTask> tasks;
  final List<String> goodPointsList;
  final List<NoteTask> improvementTasks;
  final int? rating;
  final String memo;

  // 試合ノート専用
  final String? opponent;
  final String? score;
  final List<String> positions;
  final String? goodPlays;
  final String? tactics;

  final String? aiAdvice;
  final String? tacticalMapId;

  SoccerNote({
    this.id,
    required this.uid,
    required this.groupId,
    required this.type,
    required this.date,
    required this.createdAt,
    this.goals = const [],
    this.tasks = const [],
    this.goodPointsList = const [],
    this.improvementTasks = const [],
    this.rating,
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

    // 旧 goal (String) → goals (List<String>) 後方互換
    final List<String> goals;
    if (d['goals'] != null) {
      goals = (d['goals'] as List).cast<String>();
    } else {
      final old = d['goal'] as String? ?? '';
      goals = old.isNotEmpty ? [old] : [];
    }

    // 旧 goodPoints (String) → goodPointsList (List<String>) 後方互換
    final List<String> goodPointsList;
    if (d['goodPointsList'] != null) {
      goodPointsList = (d['goodPointsList'] as List).cast<String>();
    } else {
      final old = d['goodPoints'] as String? ?? '';
      goodPointsList = old.isNotEmpty ? [old] : [];
    }

    // 旧 improvements (String) → improvementTasks (List<NoteTask>) 後方互換
    final List<NoteTask> improvementTasks;
    if (d['improvementTasks'] != null) {
      improvementTasks =
          ((d['improvementTasks'] as List).cast<Map<String, dynamic>>())
              .map(NoteTask.fromMap)
              .toList();
    } else {
      final old = d['improvements'] as String? ?? '';
      improvementTasks = old.isNotEmpty ? [NoteTask(text: old)] : [];
    }

    return SoccerNote(
      id: doc.id,
      uid: d['uid'] as String,
      groupId: d['groupId'] as String? ?? '',
      type: (d['type'] as String?) == 'match' ? NoteType.match : NoteType.practice,
      date: (d['date'] as Timestamp).toDate(),
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      goals: goals,
      tasks: ((d['tasks'] as List?)?.cast<Map<String, dynamic>>() ?? [])
          .map(NoteTask.fromMap)
          .toList(),
      goodPointsList: goodPointsList,
      improvementTasks: improvementTasks,
      rating: d['rating'] as int?,
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
        'groupId': groupId,
        'type': type == NoteType.match ? 'match' : 'practice',
        'date': Timestamp.fromDate(date),
        'createdAt': Timestamp.fromDate(createdAt),
        'goals': goals,
        'tasks': tasks.map((t) => t.toMap()).toList(),
        'goodPointsList': goodPointsList,
        'improvementTasks': improvementTasks.map((t) => t.toMap()).toList(),
        if (rating != null) 'rating': rating,
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
    List<String>? goals,
    List<NoteTask>? tasks,
    List<String>? goodPointsList,
    List<NoteTask>? improvementTasks,
    int? rating,
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
        groupId: groupId,
        type: type ?? this.type,
        date: date ?? this.date,
        createdAt: createdAt,
        goals: goals ?? this.goals,
        tasks: tasks ?? this.tasks,
        goodPointsList: goodPointsList ?? this.goodPointsList,
        improvementTasks: improvementTasks ?? this.improvementTasks,
        rating: rating ?? this.rating,
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
