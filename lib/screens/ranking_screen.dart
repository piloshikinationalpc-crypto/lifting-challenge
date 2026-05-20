import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/lifting_record.dart';
import '../services/record_service.dart';
import '../services/follow_service.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  bool _followingOnly = false;

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final followService = FollowService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ランキング'),
        actions: [
          Row(
            children: [
              const Text('フォロー中', style: TextStyle(fontSize: 13)),
              Switch(
                value: _followingOnly,
                onChanged: (v) => setState(() => _followingOnly = v),
              ),
            ],
          ),
        ],
      ),
      body: _followingOnly
          ? _FollowingRanking(myUid: myUid, followService: followService)
          : _GlobalRanking(myUid: myUid, followService: followService),
    );
  }
}

class _GlobalRanking extends StatelessWidget {
  final String myUid;
  final FollowService followService;
  const _GlobalRanking({required this.myUid, required this.followService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LiftingRecord>>(
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
          itemBuilder: (_, i) => _RankTile(
            record: records[i],
            rank: i + 1,
            myUid: myUid,
            followService: followService,
          ),
        );
      },
    );
  }
}

class _FollowingRanking extends StatelessWidget {
  final String myUid;
  final FollowService followService;
  const _FollowingRanking({required this.myUid, required this.followService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: followService.followingUids(myUid),
      builder: (context, snap) {
        final uids = [...(snap.data ?? []), myUid];
        return StreamBuilder<List<LiftingRecord>>(
          stream: RecordService().ranking(),
          builder: (context, recSnap) {
            if (recSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final records = (recSnap.data ?? [])
                .where((r) => uids.contains(r.uid))
                .toList();
            if (records.isEmpty) {
              return const Center(
                  child: Text('フォロー中のユーザーの記録がありません'));
            }
            return ListView.builder(
              itemCount: records.length,
              itemBuilder: (_, i) => _RankTile(
                record: records[i],
                rank: i + 1,
                myUid: myUid,
                followService: followService,
              ),
            );
          },
        );
      },
    );
  }
}

class _RankTile extends StatelessWidget {
  final LiftingRecord record;
  final int rank;
  final String myUid;
  final FollowService followService;
  const _RankTile(
      {required this.record,
      required this.rank,
      required this.myUid,
      required this.followService});

  @override
  Widget build(BuildContext context) {
    final isMe = record.uid == myUid;
    return ListTile(
      leading: _RankBadge(rank: rank),
      title: Text(
        record.displayName,
        style:
            isMe ? const TextStyle(fontWeight: FontWeight.bold) : null,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${record.count} 回',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isMe ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          if (!isMe) ...[
            const SizedBox(width: 8),
            StreamBuilder<bool>(
              stream: followService.isFollowing(myUid, record.uid),
              builder: (context, snap) {
                final following = snap.data ?? false;
                return GestureDetector(
                  onTap: () {
                    if (following) {
                      followService.unfollow(myUid, record.uid);
                    } else {
                      followService.follow(myUid, record.uid);
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: following
                          ? Colors.grey.shade300
                          : Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      following ? 'フォロー中' : 'フォロー',
                      style: TextStyle(
                        fontSize: 12,
                        color: following ? Colors.black54 : Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
      tileColor: isMe
          ? Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.3)
          : null,
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
