import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import '../widgets/game_map_view.dart';
import 'human_view.dart';
import 'ghost_view.dart';

class GameScreen extends StatefulWidget {
  final Map initialRoomData;
  const GameScreen({super.key, required this.initialRoomData});

  @override
  State createState() => _GameScreenState();
}

class _GameScreenState extends State {
  final SocketService _socketService = SocketService();
  late Map _roomData;
  bool _isAlive = true;

  @override
  void initState() {
    super.initState();
    // 使用強制動態轉型，保證 100% 能讀取到 initialRoomData，免除編譯器泛型誤判
    final dynamic parentWidget = widget;
    _roomData = Map.from(parentWidget.initialRoomData ?? {});

    _socketService.socket?.on('player_eliminated', (data) {
      if (!mounted) return;
      final victimId = data['victimId'];
      final victimName = data['victimName'];
      final hunterName = data['hunterName'];
      final remaining = data['remainingHumans'];

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text("🚨 \(victimName 已被\)hunterName 抓獲！(人類剩餘: $remaining 人)"),
        ),
      );

      if (victimId == _socketService.socket?.id) {
        setState(() => _isAlive = false);
      }
    });

    _socketService.socket?.on('game_ended', (data) {
      if (!mounted) return;
      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF222222),
          title: const Text("🏁 遊戲結束", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(
            data['winner'] == 'ghost' ? "鬼獲勝！所有人類已被全數殲滅！" : "時間到！人類獲勝！",
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: const Text("返回大廳", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final myId = _socketService.socket?.id ?? '';
    final myData = _roomData['players']?[myId] ?? {};
    final String myRole = myData['role'] ?? 'human';
    final String myName = myData['name'] ?? 'Player';

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("hideseek", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        automaticallyImplyLeading: false,
      ),
      body: !_isAlive
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dangerous, size: 80, color: Colors.white38),
                  SizedBox(height: 16),
                  Text("你已被淘汰", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text("請在原地休息或作為幽靈旁觀遊戲進行", style: TextStyle(color: Colors.white38)),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  flex: 3,
                  child: GameMapView(initialRoomData: _roomData),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF181818),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, -3)),
                      ],
                    ),
                    child: myRole == 'ghost'
                        ? const GhostView()
                        : HumanView(myPlayerId: myId, myName: myName),
                  ),
                ),
              ],
            ),
    );
  }
}