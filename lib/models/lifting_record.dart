import 'package:cloud_firestore/cloud_firestore.dart';

class LiftingRecord {
  final String? id;
  final String uid;
  final String groupId;
  final String displayName;
  final int count;
  final DateTime createdAt;
  final String? videoUrl;

  LiftingRecord({
    this.id,
    required this.uid,
    required this.groupId,
    required this.displayName,
    required this.count,
    required this.createdAt,
    this.videoUrl,
  });

  factory LiftingRecord.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LiftingRecord(
      id: doc.id,
      uid: d['uid'] as String,
      groupId: d['groupId'] as String? ?? '',
      displayName: d['displayName'] as String? ?? '名無し',
      count: d['count'] as int,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      videoUrl: d['videoUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'groupId': groupId,
        'displayName': displayName,
        'count': count,
        'createdAt': Timestamp.fromDate(createdAt),
        if (videoUrl != null) 'videoUrl': videoUrl,
      };
}
