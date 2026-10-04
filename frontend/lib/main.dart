import 'package:flutter/material.dart';
import 'services/socket_service.dart';
import 'screens/lobby_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化後端連線
  // 本地測試填入本機埠口，部署後再替換成外網網址 (如 https://xxx.onrender.com)
  SocketService().init("http://localhost:3000");

  runApp(const MaterialApp(
    title: 'HideSeek',
    debugShowCheckedModeBanner: false,
    home: LobbyScreen(),
  ));
}