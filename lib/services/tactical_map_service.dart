import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tactical_map.dart';

class TacticalMapService {
  final _col = FirebaseFirestore.instance.collection('tactical_maps');

  Future<String> saveMap(TacticalMap map) async {
    if (map.id == null) {
      final doc = await _col.add(map.toMap());
      return doc.id;
    } else {
      await _col.doc(map.id).update(map.toMap());
      return map.id!;
    }
  }

  Future<void> deleteMap(String id) async {
    await _col.doc(id).delete();
  }

  Stream<List<TacticalMap>> myMaps(String groupId) {
    return _col.where('groupId', isEqualTo: groupId).snapshots().map((s) {
      final list = s.docs.map(TacticalMap.fromDoc).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<TacticalMap?> getMap(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return TacticalMap.fromDoc(doc);
  }
}
