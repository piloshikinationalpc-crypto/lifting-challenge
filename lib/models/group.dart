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

/// グループを切り替えたことをアプリ全体へ知らせる通知役。
///
/// GroupScope は起動時に一度だけ組み立てられるため、プロフィール画面から
/// 招待コードで別グループに参加しても、記録・ノート・戦術ボードは
/// 古いグループIDを掴んだままだった（アプリを再起動するまで直らず、
/// その間の保存はすべて前のグループへ書き込まれていた）。
/// 参加処理のあとにこの値を新しいグループIDへ更新すると GroupScope が張り替わる。
final ValueNotifier<String?> groupIdChanged = ValueNotifier<String?>(null);

class GroupScope extends InheritedWidget {
  final String groupId;

  const GroupScope({super.key, required this.groupId, required super.child});

  static String of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GroupScope>()!.groupId;

  @override
  bool updateShouldNotify(GroupScope old) => groupId != old.groupId;
}
