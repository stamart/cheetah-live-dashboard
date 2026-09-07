import 'dart:async';
import 'dart:io';

import 'gt7_packet_decoder.dart';
import 'gt7_telemetry.dart';

/// Sends the GT7 heartbeat and decodes incoming telemetry over UDP. GT7 stops
/// sending packets if the heartbeat lapses, so it's resent periodically, not
/// just once. The PS5 replies to whatever local port this socket is bound
/// to (not to a fixed port on the phone), so telemetry is read from the same
/// socket the heartbeat was sent from.
class Gt7Socket {
  Gt7Socket(this.ps5Ip);

  static const _heartbeatPort = 33739;
  static const _heartbeatInterval = Duration(seconds: 1);
  static const _badPacketDisconnectThreshold = 30;

  final String ps5Ip;

  RawDatagramSocket? _socket;
  Timer? _heartbeatTimer;
  StreamSubscription<RawSocketEvent>? _subscription;
  int _consecutiveBadPackets = 0;
  bool _connected = false;

  final _telemetryController = StreamController<Gt7Telemetry>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<Gt7Telemetry> get telemetry => _telemetryController.stream;
  Stream<bool> get connectionStatus => _connectionController.stream;
  bool get connected => _connected;

  Future<void> start() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _subscription = _socket!.listen(_onEvent);
    _sendHeartbeat();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) => _sendHeartbeat());
  }

  void _sendHeartbeat() {
    try {
      _socket?.send(const [0x41], InternetAddress(ps5Ip), _heartbeatPort); // 'A'
    } catch (_) {
      // Bad IP / unreachable host — surfaced via connectionStatus staying false,
      // no need to crash the uplink loop over a single failed send.
    }
  }

  void _onEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _socket?.receive();
    if (datagram == null) return;

    final decrypted = decryptGt7Packet(datagram.data);
    if (decrypted == null) {
      _consecutiveBadPackets++;
      if (_connected && _consecutiveBadPackets > _badPacketDisconnectThreshold) {
        _connected = false;
        _connectionController.add(false);
      }
      return;
    }

    _consecutiveBadPackets = 0;
    if (!_connected) {
      _connected = true;
      _connectionController.add(true);
    }

    final telemetry = parseGt7Packet(decrypted);
    if (telemetry != null) _telemetryController.add(telemetry);
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _subscription?.cancel();
    _socket?.close();
    _telemetryController.close();
    _connectionController.close();
  }
}
