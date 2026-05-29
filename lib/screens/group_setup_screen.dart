import 'package:flutter/material.dart';
import '../services/group_service.dart';

class GroupSetupScreen extends StatefulWidget {
  final String uid;
  final ValueChanged<String> onGroupJoined;

  const GroupSetupScreen({
    super.key,
    required this.uid,
    required this.onGroupJoined,
  });

  @override
  State<GroupSetupScreen> createState() => _GroupSetupScreenState();
}

class _GroupSetupScreenState extends State<GroupSetupScreen> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'グループ名を入力してください');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final id = await GroupService().createGroup(widget.uid, name);
      widget.onGroupJoined(id);
    } catch (e) {
      if (mounted) setState(() { _error = 'エラー: $e'; _loading = false; });
    }
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = '招待コードを入力してください');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await GroupService().joinGroup(widget.uid, code);
      final gid = await GroupService().getGroupId(widget.uid);
      if (gid != null) widget.onGroupJoined(gid);
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.sports_soccer, size: 72, color: Colors.green),
              const SizedBox(height: 16),
              const Text('キックアップ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('グループを作成または参加してください',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 48),

              // グループ作成
              const Text('グループを作る',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'グループ名',
                  hintText: '例: ○○クラブ',
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loading ? null : _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('作成する', style: TextStyle(fontSize: 16)),
              ),

              const SizedBox(height: 32),
              const Row(children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('または', style: TextStyle(color: Colors.grey)),
                ),
                Expanded(child: Divider()),
              ]),
              const SizedBox(height: 32),

              // グループ参加
              const Text('招待コードで参加する',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '招待コード（6文字）',
                  hintText: '例: AB3XYZ',
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loading ? null : _join,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('参加する', style: TextStyle(fontSize: 16)),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red)),
              ],
              if (_loading) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
