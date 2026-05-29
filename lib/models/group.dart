import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

class Group {
  final String id;
  final String name;
  final String inviteCode;
  final List<String> members;

  const Group({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.members,
  });

  factory Group.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Group(
      id: doc.id,
      name: d['name'] as String? ?? '',
      inviteCode: d['inviteCode'] as String? ?? '',
      members: ((d['members'] as List?)?.cast<String>()) ?? [],
    );
  }
}

class GroupScope extends InheritedWidget {
  final String groupId;

  const GroupScope({super.key, required this.groupId, required super.child});

  static String of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GroupScope>()!.groupId;

  @override
  bool updateShouldNotify(GroupScope old) => groupId != old.groupId;
}
