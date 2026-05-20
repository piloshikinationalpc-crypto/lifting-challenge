import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/lifting_record.dart';
import '../services/record_service.dart';

class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('ランキング')),
      body: StreamBuilder<List<LiftingRecord>>(
        stream: RecordService().ranking(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data ?? [];
          if (records.isEmpty) {
            return const Center(child: Text('まだ記録がありません'));
          }
          return ListView.builder(
            itemCount: records.length,
            itemBuilder: (_, i) {
              final r = records[i];
              final isMe = r.uid == myUid;
              return ListTile(
                leading: _RankBadge(rank: i + 1),
                title: Text(
                  r.displayName,
                  style: isMe
                      ? const TextStyle(fontWeight: FontWeight.bold)
                      : null,
                ),
                trailing: Text(
                  '${r.count} 回',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isMe
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
                tileColor: isMe
                    ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final medals = {1: '🥇', 2: '🥈', 3: '🥉'};
    if (medals.containsKey(rank)) {
      return Text(medals[rank]!, style: const TextStyle(fontSize: 24));
    }
    return CircleAvatar(
      radius: 16,
      child: Text('$rank', style: const TextStyle(fontSize: 12)),
    );
  }
}
