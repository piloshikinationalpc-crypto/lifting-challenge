import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group.dart';

class GroupService {
  final _db = FirebaseFirestore.instance;

  Future<String> createGroup(String uid, String groupName) async {
    final code = _generateCode();
    final doc = await _db.collection('groups').add({
      'name': groupName,
      'inviteCode': code,
      'members': [uid],
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('users').doc(uid).set(
      {'groupId': doc.id},
      SetOptions(merge: true),
    );
    return doc.id;
  }

  Future<void> joinGroup(String uid, String inviteCode) async {
    final snap = await _db
        .collection('groups')
        .where('inviteCode', isEqualTo: inviteCode.toUpperCase().trim())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) throw Exception('招待コードが見つかりません');
    final groupId = snap.docs.first.id;
    await _db.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayUnion([uid]),
    });
    await _db.collection('users').doc(uid).set(
      {'groupId': groupId},
      SetOptions(merge: true),
    );
  }

  Future<String?> getGroupId(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['groupId'] as String?;
  }

  Stream<Group> groupStream(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .snapshots()
        .map(Group.fromDoc);
  }

  // groupIdが空のデータを現在のgroupIdに更新する（初回マイグレーション用）
  Future<void> migrateOldData(String uid, String groupId) async {
    final batch = _db.batch();
    for (final col in ['soccer_notes', 'tactical_maps', 'records']) {
      final snap = await _db
          .collection(col)
          .where('uid', isEqualTo: uid)
          .where('groupId', isEqualTo: '')
          .get();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'groupId': groupId});
      }
    }
    await batch.commit();
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
