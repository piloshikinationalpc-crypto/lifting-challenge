import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/group.dart';
import '../models/lifting_record.dart';
import '../services/auth_service.dart';
import '../services/record_service.dart';
import 'record_screen.dart';
import 'ranking_screen.dart';
import 'game_screen.dart';
import 'profile_screen.dart';
import 'note_list_screen.dart';
import 'tactical_board_screen.dart';
import 'album_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final groupId = GroupScope.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          const NoteListScreen(),
          const SizedBox.shrink(), // 戦術ボードは直接push
          const AlbumScreen(),
          _LiftingTab(groupId: groupId),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          if (i == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TacticalBoardScreen(groupId: groupId),
              ),
            );
            return;
          }
          setState(() => _tab = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'ノート'),
          NavigationDestination(icon: Icon(Icons.dashboard), label: '戦術ボード'),
          NavigationDestination(icon: Icon(Icons.photo_library), label: 'アルバム'),
          NavigationDestination(icon: Icon(Icons.sports_soccer), label: 'リフティング'),
        ],
      ),
    );
  }
}

// ───────── リフティングタブ ─────────

class _LiftingTab extends StatelessWidget {
  final String groupId;
  const _LiftingTab({required this.groupId});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final service = RecordService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('キックアップ'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.sports_soccer),
            tooltip: 'ゲーム',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => GameScreen(groupId: groupId)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.leaderboard),
            tooltip: 'ランキング',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RankingScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'プロフィール',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: StreamBuilder<List<LiftingRecord>>(
        stream: service.myRecords(groupId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data ?? [];
          final best = records.isEmpty
              ? 0
              : records.map((r) => r.count).reduce((a, b) => a > b ? a : b);

          return Column(
            children: [
              _BestCard(best: best, name: user.displayName ?? '名無し'),
              Expanded(
                child: records.isEmpty
                    ? const Center(
                        child: Text(
                          'まだ記録がありません\n下のボタンから追加しよう！',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: records.length,
                        itemBuilder: (_, i) => _RecordTile(record: records[i]),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'lifting_fab',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RecordScreen(groupId: groupId)),
        ),
        icon: const Icon(Icons.add),
        label: const Text('記録する'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _BestCard extends StatelessWidget {
  final int best;
  final String name;
  const _BestCard({required this.best, required this.name});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.sports_soccer, size: 40),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 14)),
                const Text('自己ベスト', style: TextStyle(fontSize: 12)),
              ],
            ),
            const Spacer(),
            Text('$best 回',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final LiftingRecord record;
  const _RecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy/MM/dd HH:mm');
    return ListTile(
      leading: CircleAvatar(child: Text('${record.count}'[0])),
      title: Text('${record.count} 回'),
      subtitle: Text(fmt.format(record.createdAt)),
    );
  }
}
