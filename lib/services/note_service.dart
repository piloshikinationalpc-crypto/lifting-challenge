import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/soccer_note.dart';

class NoteService {
  final _col = FirebaseFirestore.instance.collection('soccer_notes');

  Future<String> addNote(SoccerNote note) async {
    final doc = await _col.add(note.toMap());
    return doc.id;
  }

  Future<void> updateNote(SoccerNote note) async {
    await _col.doc(note.id).update(note.toMap());
  }

  Future<void> deleteNote(String id) async {
    await _col.doc(id).delete();
  }

  Stream<List<SoccerNote>> myNotes(String uid) {
    return _col.where('uid', isEqualTo: uid).snapshots().map((s) {
      final list = s.docs.map(SoccerNote.fromDoc).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }
}
