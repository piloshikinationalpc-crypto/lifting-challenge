import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lifting_record.dart';

class RecordService {
  final _col = FirebaseFirestore.instance.collection('records');

  Future<void> addRecord(LiftingRecord record) async {
    await _col.add(record.toMap());
  }

  Stream<List<LiftingRecord>> myRecords(String uid) {
    return _col
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((s) {
          final list = s.docs.map(LiftingRecord.fromDoc).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<List<LiftingRecord>> ranking() {
    return _col
        .orderBy('count', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map(LiftingRecord.fromDoc).toList());
  }

  Future<int> myBest(String uid) async {
    final snap = await _col.where('uid', isEqualTo: uid).get();
    if (snap.docs.isEmpty) return 0;
    return snap.docs.map((d) => d['count'] as int).reduce((a, b) => a > b ? a : b);
  }
}
