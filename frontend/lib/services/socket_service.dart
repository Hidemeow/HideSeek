import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? socket;
  String? currentRoomId;
  String? myPlayerId;
  bool isHost = false;

  // 初始化連線 (本地開發填入伺服器 IP 或 http://localhost:3000)
  void init(String serverUrl) {
    socket = IO.io(serverUrl, IO.OptionBuilder()
      .setTransports(['websocket']) // 強制走純 WebSocket
      .disableAutoConnect()
      .build());

    socket!.connect();

    socket!.onConnect((_) {
      myPlayerId = socket!.id;
      print("[Socket] 連線成功! ID: $myPlayerId");
    });

    socket!.onDisconnect((_) {
      print("[Socket] 連線斷開");
    });
  }

  void createRoom(String playerName, Function(Map<String, dynamic>) onDone) {
    socket?.emitWithAck('create_room', {'playerName': playerName}, ack: (response) {
      if (response != null && response['success'] == true) {
        currentRoomId = response['roomId'];
        isHost = true;
        onDone(response);
      }
    });
  }

  void joinRoom(String roomId, String playerName, Function(Map<String, dynamic>) onDone) {
    socket?.emitWithAck('join_room', {
      'roomId': roomId.toUpperCase(),
      'playerName': playerName,
    }, ack: (response) {
      if (response != null && response['success'] == true) {
        currentRoomId = response['roomId'];
        isHost = false;
        onDone(response);
      } else {
        onDone(response ?? {'success': false, 'message': '伺服器無回應'});
      }
    });
  }

  void setRole(String targetSocketId, String newRole) {
    socket?.emit('set_role', {
      'targetSocketId': targetSocketId,
      'newRole': newRole,
    });
  }

  void startGame() {
    socket?.emit('start_game');
  }
  // 在 SocketService class 內新增以下方法

  void updateOtp(String otp) {
    socket?.emit('update_otp', {'otp': otp});
  }

  void submitCapture(String targetPlayerId, String otpInput, Function(Map<String, dynamic>) onDone) {
    socket?.emitWithAck('submit_capture', {
      'targetPlayerId': targetPlayerId,
      'otpInput': otpInput,
    }, ack: (response) {
      if (response != null) {
        onDone(Map<String, dynamic>.from(response));
      } else {
        onDone({'success': false, 'message': '伺服器無回應'});
      }
    });
  }
  void updatePosition(double lat, double lng) {
    socket?.emit('update_position', {'lat': lat, 'lng': lng});
  }
  
}
