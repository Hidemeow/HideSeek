// ~/hideseek/backend/server.js
const { Server } = require("socket.io");
const http = require("http");

const httpServer = http.createServer();
// 設定 CORS 跨域限制，允許任何前端網址連線（測試時需要，部署時要縮小權限）
const io = new Server(httpServer, {
  cors: {
    origin: "*", 
    methods: ["GET", "POST"]
  }
});

// ==========================================
// 1. 核心資料儲存 - Pure In-Memory (No Redis)
// ==========================================
// 全域房間字典: Map
// 結構見先前設計書
const rooms = new Map();

// ==========================================
// 工具函數
// ==========================================
// 產生 4 碼唯一的房間代碼
function generateRoomCode() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // 排除 I, O, 1, 0 防止混淆
  let code = "";
  for (let i = 0; i < 4; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

// 根據玩家 ID 尋找其所在房間數據
function findRoomByPlayerId(socketId) {
  // 對於高並發可以用另一個 Map 反向索引，小型測試遍歷即可
  for (const [roomId, roomData] of rooms) {
    if (roomData.players[socketId]) {
      return { roomId, roomData };
    }
  }
  return null;
}

// 統計房間記憶體存活人類數量
function countAliveHumans(roomData) {
  let count = 0;
  for (const playerId in roomData.players) {
    if (roomData.players[playerId].role === 'human' && roomData.players[playerId].isAlive) {
      count++;
    }
  }
  return count;
}

// ==========================================
// 2. WebSocket 事件處理 (Socket.io)
// ==========================================
io.on("connection", (socket) => {
  console.log(`[Connected] New socket connection: ${socket.id}`);

  // --- 大廳與房間事件 (Lobby & Room) ---

  // 1. 創建房間
  socket.on("create_room", ({ playerName }, callback) => {
    let roomId = generateRoomCode();
    // 確保房號不重複
    while (rooms.has(roomId)) {
      roomId = generateRoomCode();
    }

    const roomData = {
      roomId: roomId,
      hostId: socket.id,
      status: "waiting", // waiting | playing | ended
      createdAt: Date.now(),
      players: {
        [socket.id]: {
          id: socket.id,
          name: playerName,
          role: "human", // 預設人類，房主可更改
          isAlive: true,
          lat: 0,
          lng: 0,
          lastSeen: Date.now(),
          otpData: null,
        },
      },
    };

    rooms.set(roomId, roomData);
    socket.join(roomId);
    
    // 將房號存入 Socket 本地數據，方便斷線時快速查找
    socket.data.roomId = roomId;

    if (callback) callback({ success: true, roomId, roomData });
    console.log(`[Room Created] \({roomId} by\){playerName}`);
  });

  // 2. 加入房間
  socket.on("join_room", ({ roomId, playerName }, callback) => {
    // 轉大寫避免房號大小寫問題
    const upperRoomId = roomId?.toUpperCase();
    const roomData = rooms.get(upperRoomId);

    if (!roomData) {
      if (callback) callback({ success: false, message: "找不到該房間代碼！" });
      return;
    }

    if (roomData.status !== "waiting") {
      if (callback) callback({ success: false, message: "遊戲已經開始，無法加入！" });
      return;
    }

    // 檢查暱稱是否重複（選配）

    roomData.players[socket.id] = {
      id: socket.id,
      name: playerName,
      role: "human",
      isAlive: true,
      lat: 0,
      lng: 0,
      lastSeen: Date.now(),
      otpData: null,
    };

    socket.join(upperRoomId);
    socket.data.roomId = upperRoomId;

    if (callback) callback({ success: true, roomId: upperRoomId, roomData });
    console.log(`[Room Joined] \({upperRoomId} by\){playerName}`);

    // 通知房間內所有人：有新玩家加入，重繪大廳
    io.to(upperRoomId).emit("room_updated", roomData);
  });

  // 3. 房主更改玩家角色 (例如指定某人是鬼)
  socket.on("set_role", ({ targetSocketId, newRole }) => {
    const roomId = socket.data.roomId;
    const room = rooms.get(roomId);

    // 權限檢查: 只有房主能更改，且必須同房間
    if (room && room.hostId === socket.id && room.players[targetSocketId]) {
      if (newRole === 'human' || newRole === 'ghost') {
        room.players[targetSocketId].role = newRole;
        io.to(roomId).emit("room_updated", room);
      }
    }
  });

  // 4. 房主開始遊戲
  socket.on("start_game", () => {
    const roomId = socket.data.roomId;
    const room = rooms.get(roomId);

    if (room && room.hostId === socket.id) {
      room.status = "playing";
      // 清空所有舊 OTP
      for (const playerId in room.players) {
        room.players[playerId].otpData = null;
      }
      
      // 廣播開始，全體切換至地圖畫面
      io.to(roomId).emit("game_started", { 
        startTime: Date.now(),
        // durationMinutes 遊戲時長可選
      });
      console.log(`[Game Started] Room ${roomId} is playing.`);
    }
  });

  // --- 位置同步與遊戲邏輯 (Gameplay) ---

  // 5. 客戶端更新座標
  socket.on("update_position", ({ lat, lng }) => {
    const roomId = socket.data.roomId;
    const room = rooms.get(roomId);

    if (room && room.players[socket.id]) {
      const player = room.players[socket.id];
      // 檢查遊戲狀態
      if (room.status !== 'playing' || !player.isAlive) return;

      player.lat = lat;
      player.lng = lng;
      player.lastSeen = Date.now();

      // [核心廣播]: 將位置同步給房間內所有人
      // socket.to(roomId).emit(...) 指的是「不包含自己」的廣播
      socket.to(roomId).emit("player_moved", {
        id: socket.id,
        lat,
        lng,
        role: player.role,
        isAlive: player.isAlive,
        name: player.name
      });
    }
  });

  // 6. [人類專用] 更新動態 OTP/QR Code
  socket.on("update_otp", ({ otp }) => {
    const roomId = socket.data.roomId;
    const room = rooms.get(roomId);

    if (room && room.players[socket.id]) {
      const player = room.players[socket.id];
      
      // 只有活著的人類能更新 OTP
      if (player.role === 'human' && player.isAlive) {
        player.otpData = {
          code: otp,
          // 設定絕對過期時間: 當前 + 32 秒（含容錯）
          expireAt: Date.now() + 32000
        };
        // 伺服器安靜地更新狀態，不需廣播
      }
    }
  });

  // 7. [鬼專用] 提交抓捕 (核心驗證邏輯)
  socket.on("submit_capture", ({ targetPlayerId, otpInput }, callback) => {
    const roomId = socket.data.roomId;
    const room = rooms.get(roomId);
    
    // 基礎檢查: 遊戲進行中、鬼是存活的
    if (!room || room.status !== 'playing' || !room.players[socket.id] || room.players[socket.id].role !== 'ghost') {
      if (callback) callback({ success: false, message: "非法操作" });
      return;
    }

    const victim = room.players[targetPlayerId];

    if (!victim || victim.role !== 'human' || !victim.isAlive) {
      if (callback) callback({ success: false, message: "找不到該人類玩家或已淘汰" });
      return;
    }

    const victimOtpData = victim.otpData;

    if (!victimOtpData) {
      if (callback) callback({ success: false, message: "對方尚未產生驗證碼" });
      return;
    }

    // [核心驗證]
    // 1. 檢查時效性
    if (Date.now() > victimOtpData.expireAt) {
      if (callback) callback({ success: false, message: "驗證碼已過期，請重新確認螢幕" });
      return;
    }

    // 2. 字串比對 OTP 代碼
    if (victimOtpData.code === otpInput) {
      // 抓捕驗證成功！

      victim.isAlive = false; // 標記為淘汰
      victim.otpData = null;  // 銷毀 OTP 防重複掃描
      
      // 統計存活人數
      const aliveHumans = countAliveHumans(room);

      // 廣播淘汰事件給同房間所有人
      io.to(roomId).emit("player_eliminated", {
        victimId: victim.id,
        victimName: victim.name,
        hunterId: socket.id,
        hunterName: room.players[socket.id].name,
        timestamp: Date.now(),
        remainingHumans: aliveHumans
          });

      if (callback) callback({ success: true, message: "淘汰成功！" });
      console.log(`[Capture] In room \({roomId}, Ghost\){room.players[socket.id].name} captured Human ${victim.name}.`);

      // 遊戲結束判定: 若人類歸零
      if (aliveHumans === 0) {
        room.status = "ended";
        io.to(roomId).emit("game_ended", { winner: "ghost", timestamp: Date.now() });
        console.log(`[Game Ended] In room ${roomId}, Ghosts win.`);
      }
    } else {
      // 驗證碼錯誤
      // 對鬼實施輸入懲罰（選配，防暴力猜解）
      if (callback) callback({ success: false, message: "驗證碼錯誤！抓捕失敗" });
    }
  });

  // --- 斷線清理 ---
  socket.on("disconnect", () => {
    console.log(`[Disconnected] socket: ${socket.id}`);
    const roomId = socket.data.roomId;
    const room = rooms.get(roomId);

    if (room) {
      // 從房間中移除玩家
      delete room.players[socket.id];
      
      const remainingPlayerCount = Object.keys(room.players).length;
      
      if (remainingPlayerCount === 0) {
        // 房間沒人了，直接銷毀房間釋放記憶體
        rooms.delete(roomId);
        console.log(`[Room Destroyed] ${roomId} is empty.`);
      } else {
        if (room.hostId === socket.id) {
          // 房主離開，移交房主權限給下一位
          room.hostId = Object.keys(room.players)[0];
          console.log(`[Host Migrated] Room \({roomId} host to\){room.players[room.hostId].name}`);
        }
        
        // 通知房間內所有人重繪畫面
        io.to(roomId).emit("room_updated", room);

        // 如果遊戲進行中，檢查人類是否因斷線而全滅
        if (room.status === 'playing') {
          const aliveHumans = countAliveHumans(room);
          if (aliveHumans === 0) {
            room.status = "ended";
            io.to(roomId).emit("game_ended", { winner: "ghost", timestamp: Date.now() });
          }
        }
      }
    }
  });
});

// ==========================================
// 3. 啟動伺服器 (Port 3000)
// ==========================================
const PORT = process.env.PORT || 3000;
httpServer.listen(PORT, '0.0.0.0', () => {
  console.log(`========================================`);
  console.log(`城市鬼抓人 $0 伺服器正在執行！`);
  console.log(`埠口: ${PORT}`);
  console.log(`========================================`);
});
