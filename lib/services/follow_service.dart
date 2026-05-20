import 'package:cloud_firestore/cloud_firestore.dart';

class FollowService {
  final _db = FirebaseFirestore.instance;

  Future<void> follow(String myUid, String targetUid) async {
    await _db
        .collection('users')
        .doc(myUid)
        .collection('following')
        .doc(targetUid)
        .set({'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> unfollow(String myUid, String targetUid) async {
    await _db
        .collection('users')
        .doc(myUid)
        .collection('following')
        .doc(targetUid)
        .delete();
  }

  Stream<bool> isFollowing(String myUid, String targetUid) {
    return _db
        .collection('users')
        .doc(myUid)
        .collection('following')
        .doc(targetUid)
        .snapshots()
        .map((s) => s.exists);
  }

  Stream<List<String>> followingUids(String myUid) {
    return _db
        .collection('users')
        .doc(myUid)
        .collection('following')
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toList());
  }
}
