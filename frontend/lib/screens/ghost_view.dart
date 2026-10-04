import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/socket_service.dart';

class GhostView extends StatefulWidget {
  const GhostView({super.key});

  @override
  State<GhostView> createState() => _GhostViewState();
}

class _GhostViewState extends State<GhostView> {
  final SocketService _socketService = SocketService();
  bool _isProcessing = false;

  void _onScanSuccess(String targetId, String otpCode) {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    _socketService.submitCapture(targetId, otpCode, (res) {
      setState(() => _isProcessing = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF222222),
            title: Text(res['success'] == true ? "抓捕成功！" : "抓捕失敗",
                style: TextStyle(color: res['success'] == true ? Colors.greenAccent : Colors.redAccent)),
            content: Text(res['message'] ?? "", style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("確定", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    });
  }

  void _openCameraScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScanScreen(
          onCaptured: (targetId, otp) {
            _onScanSuccess(targetId, otp);
          },
        ),
      ),
    );
  }

  void _openManualInputDialog() {
    final targetIdController = TextEditingController();
    final otpController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Text("手動輸入抓捕碼", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: targetIdController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "玩家 ID (例如 socket id)",
                labelStyle: TextStyle(color: Colors.white60),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 4),
              decoration: const InputDecoration(
                labelText: "4 位數驗證碼",
                labelStyle: TextStyle(color: Colors.white60),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消", style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              final tid = targetIdController.text.trim();
              final otp = otpController.text.trim();
              if (tid.isNotEmpty && otp.isNotEmpty) {
                Navigator.pop(context);
                _onScanSuccess(tid, otp);
              }
            },
            child: const Text("提交抓捕", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.whatshot, color: Colors.redAccent, size: 20),
                  SizedBox(width: 8),
                  Text("身分：鬼 (追捕中)", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 48),
            GestureDetector(
              onTap: _openCameraScanner,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.4),
                      blurRadius: 24,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner, size: 64, color: Colors.white),
                    SizedBox(height: 8),
                    Text("啟動相機掃描", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            TextButton.icon(
              onPressed: _openManualInputDialog,
              icon: const Icon(Icons.keyboard, color: Colors.white60),
              label: const Text("反光掃不到？點此手動輸入 4 碼", style: TextStyle(color: Colors.white60)),
            ),
          ],
        ),
      ),
    );
  }
}

// 獨立的相機掃描視窗
class CameraScanScreen extends StatefulWidget {
  final Function(String targetId, String otp) onCaptured;
  const CameraScanScreen({super.key, required this.onCaptured});

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _scanned = false;

  void _handleBarcode(BarcodeCapture capture) {
    if (_scanned) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null) {
        try {
          final data = jsonDecode(raw);
          final id = data['id'];
          final otp = data['otp'];

          if (id != null && otp != null) {
            _scanned = true;
            Navigator.pop(context);
            widget.onCaptured(id.toString(), otp.toString());
            break;
          }
        } catch (_) {
          // 非 JSON QR code，忽略
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("掃描人類 QR Code", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
          ),
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.redAccent, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ],
      ),
    );
  }
}