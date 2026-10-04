import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/socket_service.dart';

class HumanView extends StatefulWidget {
  final String myPlayerId;
  final String myName;

  const HumanView({
    super.key,
    required this.myPlayerId,
    required this.myName,
  });

  @override
  State<HumanView> createState() => _HumanViewState();
}

class _HumanViewState extends State<HumanView> {
  final SocketService _socketService = SocketService();
  String _currentOtp = "----";
  String _qrPayload = "";
  int _secondsLeft = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _generateAndSyncNewOtp();
    _startCountdown();
  }

  void _generateAndSyncNewOtp() {
    // 產生 4 位數驗證碼 (1000 - 9999)
    final newCode = (Random().nextInt(9000) + 1000).toString();

    // 格式化為 JSON 字串給 QR Code
    final payload = jsonEncode({
      "id": widget.myPlayerId,
      "name": widget.myName,
      "otp": newCode,
      "t": DateTime.now().millisecondsSinceEpoch,
    });

    setState(() {
      _currentOtp = newCode;
      _qrPayload = payload;
      _secondsLeft = 30;
    });

    // 透過 WebSocket 同步最新 OTP 給伺服器
    _socketService.updateOtp(newCode);
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
      } else {
        _generateAndSyncNewOtp();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield, color: Colors.greenAccent, size: 20),
                SizedBox(width: 8),
                Text("身分：人類 (存活中)", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text(
                    "被捕時出示此畫面給鬼掃描",
                    style: TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  if (_qrPayload.isNotEmpty)
                    QrImageView(
                      data: _qrPayload,
                      version: QrVersions.auto,
                      size: 220.0,
                      backgroundColor: Colors.white,
                    ),
                  const SizedBox(height: 16),
                  Text(
                    _currentOtp,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _secondsLeft / 30.0,
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "驗證碼倒數: $_secondsLeft 秒",
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}