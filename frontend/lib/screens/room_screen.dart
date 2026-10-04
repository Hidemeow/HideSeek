import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/socket_service.dart';
import 'game_screen.dart';

class RoomScreen extends StatefulWidget {
  final Map<String, dynamic> roomData;
  const RoomScreen({super.key, required this.roomData});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final _socketService = SocketService();
  late Map<String, dynamic> _currentRoom;

  @override
  void initState() {
    super.initState();
    _currentRoom = widget.roomData;
    // 進入房間即鎖定螢幕防休眠
    WakelockPlus.enable();

    // 監聽房間更新事件
    _socketService.socket?.on('room_updated', (data) {
      if (mounted) setState(() => _currentRoom = Map<String, dynamic>.from(data));
    });

    // 監聽遊戲開始事件
    _socketService.socket?.on('game_started', (data) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GameScreen(initialRoomData: _currentRoom),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final roomId = _currentRoom['roomId'] ?? '';
    final isHost = _socketService.socket?.id == _currentRoom['hostId'];
    final Map players = _currentRoom['players'] ?? {};

    return Scaffold(
      backgroundColor: const Color(0xFF181818),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text("房間代碼: $roomId", style: const TextStyle(letterSpacing: 2)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              "等待玩家進入 (${players.length} 人)",
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: players.values.map<Widget>((p) {
                  final isMe = p['id'] == _socketService.socket?.id;
                  final role = p['role'] ?? 'human';
                  final isGhost = role == 'ghost';

                  return Card(
                    color: Colors.white10,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: Icon(
                        isGhost ? Icons.pest_control_rodent : Icons.person,
                        color: isGhost ? Colors.redAccent : Colors.lightGreenAccent,
                      ),
                      title: Text(
                        "${p['name']} ${isMe ? '(你)' : ''}",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        isGhost ? "角色: 鬼" : "角色: 人類",
                        style: TextStyle(color: isGhost ? Colors.redAccent : Colors.greenAccent),
                      ),
                      trailing: isHost
                          ? DropdownButton<String>(
                              value: role,
                              dropdownColor: const Color(0xFF2A2A2A),
                              style: const TextStyle(color: Colors.white),
                              items: const [
                                DropdownMenuItem(value: 'human', child: Text("人類")),
                                DropdownMenuItem(value: 'ghost', child: Text("鬼")),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  _socketService.setRole(p['id'], val);
                                }
                              },
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
            if (isHost)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () => _socketService.startGame(),
                child: const Text("開始遊戲", style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
          ],
        ),
      ),
    );
  }
}
