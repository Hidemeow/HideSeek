import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/socket_service.dart';

class GameMapView extends StatefulWidget {
  final Map initialRoomData;
  const GameMapView({super.key, required this.initialRoomData});

  @override
  State createState() => _GameMapViewState();
}

class _GameMapViewState extends State {
  final SocketService _socketService = SocketService();
  final MapController _mapController = MapController();

  final Map _playerLocations = {};

  LatLng _myLocation = const LatLng(24.8138, 120.9674);
  StreamSubscription? _positionStream;

  @override
  void initState() {
    super.initState();
    _initPlayersFromRoomData();
    _initLocationTracking();
    _listenToNetworkPositions();
  }

  void _initPlayersFromRoomData() {
    // 使用強制動態轉型讀取 initialRoomData
    final dynamic parentWidget = widget;
    final dynamic initialData = parentWidget.initialRoomData;
    final dynamic players = initialData != null ? initialData['players'] : null;

    if (players != null && players is Map) {
      players.forEach((key, val) {
        if (val != null && val is Map) {
          _playerLocations[key.toString()] = {
            'name': val['name'] ?? 'Player',
            'role': val['role'] ?? 'human',
            'isAlive': val['isAlive'] ?? true,
            'lat': ((val['lat'] ?? 0.0) as num).toDouble(),
            'lng': ((val['lng'] ?? 0.0) as num).toDouble(),
          };
        }
      });
    }
  }

  Future _initLocationTracking() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    try {
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _myLocation = LatLng(pos.latitude, pos.longitude);
      });
      _mapController.move(_myLocation, 16.0);
      _socketService.updatePosition(pos.latitude, pos.longitude);
    } catch (_) {}

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: settings).listen((pos) {
      if (!mounted) return;
      final newLatLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _myLocation = newLatLng;
      });
      _socketService.updatePosition(pos.latitude, pos.longitude);
    });
  }

  void _listenToNetworkPositions() {
    _socketService.socket?.on('player_moved', (data) {
      if (!mounted) return;
      final String id = data['id'];
      final double lat = (data['lat'] as num).toDouble();
      final double lng = (data['lng'] as num).toDouble();

      setState(() {
        if (_playerLocations.containsKey(id)) {
          _playerLocations[id]['lat'] = lat;
          _playerLocations[id]['lng'] = lng;
          _playerLocations[id]['role'] = data['role'];
          _playerLocations[id]['isAlive'] = data['isAlive'] ?? true;
          _playerLocations[id]['name'] = data['name'] ?? _playerLocations[id]['name'];
        } else {
          _playerLocations[id] = {
            'name': data['name'] ?? 'Player',
            'role': data['role'] ?? 'human',
            'isAlive': data['isAlive'] ?? true,
            'lat': lat,
            'lng': lng,
          };
        }
      });
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = _socketService.socket?.id ?? '';
    // 明確建構 Marker 列表
    final markers = _playerLocations.entries.map((entry) {
      final id = entry.key;
      final p = entry.value;
      final double lat = (p['lat'] as num?)?.toDouble() ?? 0.0;
      final double lng = (p['lng'] as num?)?.toDouble() ?? 0.0;
      final bool isAlive = p['isAlive'] ?? true;
      final isGhost = p['role'] == 'ghost';

      if ((lat == 0.0 && lng == 0.0) || !isAlive) {
        return Marker(
          point: const LatLng(0, 0),
          width: 0,
          height: 0,
          child: const SizedBox.shrink(),
        );
      }

      final bool isMe = (id == myId);

      return Marker(
        point: LatLng(lat, lng),
        width: 80,
        height: 60,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isGhost ? Colors.redAccent : Colors.blueAccent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "\({p['name']}\){isMe ? ' (你)' : ''}",
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              isGhost ? Icons.whatshot : Icons.shield,
              color: isGhost ? Colors.redAccent : Colors.cyanAccent,
              size: 28,
            ),
          ],
        ),
      );
    }).toList();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _myLocation,
        initialZoom: 16.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.hideseek',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }
}