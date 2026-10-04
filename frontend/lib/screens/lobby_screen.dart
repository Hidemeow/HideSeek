import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import 'room_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _nameController = TextEditingController();
  final _roomController = TextEditingController();
  final _socketService = SocketService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 自動解析網址列的 room 參數
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = Uri.base;
      if (uri.queryParameters.containsKey('room')) {
        final code = uri.queryParameters['room'];
        if (code != null && code.isNotEmpty) {
          _roomController.text = code.toUpperCase();
        }
      }
    });
  }

  void _handleCreate() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showToast("請輸入暱稱");
      return;
    }
    setState(() => _isLoading = true);
    _socketService.createRoom(name, (res) {
      setState(() => _isLoading = false);
      if (res['success'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RoomScreen(roomData: res['roomData'])),
        );
      }
    });
  }

  void _handleJoin() {
    final name = _nameController.text.trim();
    final code = _roomController.text.trim().toUpperCase();
    if (name.isEmpty || code.isEmpty) {
      _showToast("請填寫完整暱稱與 4 位數代碼");
      return;
    }
    setState(() => _isLoading = true);
    _socketService.joinRoom(code, name, (res) {
      setState(() => _isLoading = false);
      if (res['success'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RoomScreen(roomData: res['roomData'])),
        );
      } else {
        _showToast(res['message'] ?? "加入失敗");
      }
    });
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              children: [
                const Icon(Icons.radar, size: 72, color: Colors.redAccent),
                const SizedBox(height: 12),
                const Text(
                  "HideSeek",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "你的暱稱",
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _handleCreate,
                  child: const Text("創建新房間", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
                const SizedBox(height: 24),
                const Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white24)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text("或加入房間", style: TextStyle(color: Colors.white38)),
                    ),
                    Expanded(child: Divider(color: Colors.white24)),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _roomController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: Colors.white, letterSpacing: 4, fontSize: 18),
                  decoration: InputDecoration(
                    labelText: "4 位數代碼",
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _handleJoin,
                  child: const Text("加入遊戲", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
