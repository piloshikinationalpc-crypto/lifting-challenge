import 'package:cloud_firestore/cloud_firestore.dart';

enum CourtType { full, half }

class PlayerPiece {
  final String id;
  final int team; // 0=自チーム, 1=相手チーム
  final double x; // フィールド幅に対する相対値 0.0-1.0
  final double y; // フィールド高さに対する相対値 0.0-1.0
  final String label;

  PlayerPiece({
    required this.id,
    required this.team,
    required this.x,
    required this.y,
    required this.label,
  });

  PlayerPiece copyWith({double? x, double? y}) =>
      PlayerPiece(id: id, team: team, x: x ?? this.x, y: y ?? this.y, label: label);

  Map<String, dynamic> toMap() => {'id': id, 'team': team, 'x': x, 'y': y, 'label': label};

  factory PlayerPiece.fromMap(Map<String, dynamic> m) => PlayerPiece(
        id: m['id'] as String,
        team: m['team'] as int,
        x: (m['x'] as num).toDouble(),
        y: (m['y'] as num).toDouble(),
        label: m['label'] as String,
      );
}

class ArrowPath {
  final List<List<double>> points; // [[x, y], ...]  相対値
  final int colorIndex;

  ArrowPath({required this.points, this.colorIndex = 0});

  Map<String, dynamic> toMap() => {'points': points, 'colorIndex': colorIndex};

  factory ArrowPath.fromMap(Map<String, dynamic> m) => ArrowPath(
        points: (m['points'] as List)
            .map((p) => (p as List).map((v) => (v as num).toDouble()).toList())
            .toList(),
        colorIndex: m['colorIndex'] as int? ?? 0,
      );
}

class TacticalMap {
  final String? id;
  final String uid;
  final CourtType courtType;
  final List<PlayerPiece> players;
  final double? ballX;
  final double? ballY;
  final List<ArrowPath> arrows;
  final DateTime createdAt;
  final String? noteId;
  final String? title;
  final String? imageUrl;

  TacticalMap({
    this.id,
    required this.uid,
    this.courtType = CourtType.full,
    this.players = const [],
    this.ballX,
    this.ballY,
    this.arrows = const [],
    required this.createdAt,
    this.noteId,
    this.title,
    this.imageUrl,
  });

  factory TacticalMap.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TacticalMap(
      id: doc.id,
      uid: d['uid'] as String,
      courtType: (d['courtType'] as String?) == 'half' ? CourtType.half : CourtType.full,
      players: ((d['players'] as List?)?.cast<Map<String, dynamic>>() ?? [])
          .map(PlayerPiece.fromMap)
          .toList(),
      ballX: (d['ballX'] as num?)?.toDouble(),
      ballY: (d['ballY'] as num?)?.toDouble(),
      arrows: ((d['arrows'] as List?)?.cast<Map<String, dynamic>>() ?? [])
          .map(ArrowPath.fromMap)
          .toList(),
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      noteId: d['noteId'] as String?,
      title: d['title'] as String?,
      imageUrl: d['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'courtType': courtType == CourtType.half ? 'half' : 'full',
        'players': players.map((p) => p.toMap()).toList(),
        if (ballX != null) 'ballX': ballX,
        if (ballY != null) 'ballY': ballY,
        'arrows': arrows.map((a) => a.toMap()).toList(),
        'createdAt': Timestamp.fromDate(createdAt),
        if (noteId != null) 'noteId': noteId,
        if (title != null) 'title': title,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };

  TacticalMap copyWith({
    CourtType? courtType,
    List<PlayerPiece>? players,
    double? ballX,
    double? ballY,
    List<ArrowPath>? arrows,
    String? noteId,
    String? title,
    String? imageUrl,
  }) =>
      TacticalMap(
        id: id,
        uid: uid,
        courtType: courtType ?? this.courtType,
        players: players ?? this.players,
        ballX: ballX ?? this.ballX,
        ballY: ballY ?? this.ballY,
        arrows: arrows ?? this.arrows,
        createdAt: createdAt,
        noteId: noteId ?? this.noteId,
        title: title ?? this.title,
        imageUrl: imageUrl ?? this.imageUrl,
      );
}
