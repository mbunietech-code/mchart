import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'env.dart';

/// Minimal Laravel Reverb / Pusher-protocol client over a plain WebSocket.
///
/// Chosen over `pusher_channels_flutter` because that plugin has no Windows or
/// macOS desktop support. Reverb speaks the Pusher wire protocol, which is
/// simple enough to implement directly and keeps the client fully portable.
class RealtimeClient {
  RealtimeClient({required Dio authDio}) : _authDio = authDio;

  final Dio _authDio;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  String? _socketId;
  bool _disposed = false;
  bool _connecting = false;
  int _attempts = 0;

  final _connected = ValueNotifier<bool>(false);
  ValueListenable<bool> get connected => _connected;

  /// channelName -> (eventName -> listeners)
  final Map<String, Map<String, List<void Function(Map<String, dynamic>)>>> _handlers = {};
  final Set<String> _subscribed = {};

  void connect() {
    if (!Env.realtimeEnabled) return;
    if (_disposed || _channel != null || _connecting) return;
    if (_attempts >= 8) return; // gave up; a later explicit connect() resets this
    _connecting = true;

    final WebSocketChannel channel;
    try {
      channel = WebSocketChannel.connect(Env.reverbUri);
    } catch (_) {
      _connecting = false;
      _scheduleReconnect();
      return;
    }
    _channel = channel;

    // Attach the stream listener immediately so transport errors are always handled.
    _sub = channel.stream.listen(
      _onFrame,
      onError: (Object _) => _scheduleReconnect(),
      onDone: _scheduleReconnect,
      cancelOnError: true,
    );

    channel.ready.then((_) {
      _connecting = false;
      _attempts = 0;
    }).catchError((Object _) {
      _connecting = false;
    });
  }

  /// Call to retry after the client has given up (e.g. app resumed).
  void resetAndConnect() {
    _attempts = 0;
    connect();
  }

  void _onFrame(dynamic raw) {
    final frame = jsonDecode(raw as String) as Map<String, dynamic>;
    final event = frame['event'] as String?;
    final channel = frame['channel'] as String?;
    final data = _decodeData(frame['data']);

    switch (event) {
      case 'pusher:connection_established':
        _socketId = data['socket_id']?.toString();
        _connected.value = true;
        _startPing();
        for (final name in _subscribed.toList()) {
          _subscribed.remove(name);
          subscribe(name);
        }
      case 'pusher:error':
        if (kDebugMode) debugPrint('[realtime] error: $data');
      case 'pusher_internal:subscription_succeeded':
        break;
      default:
        if (channel != null && event != null) {
          final listeners = _handlers[channel]?[event];
          if (listeners != null) {
            for (final l in List.of(listeners)) {
              l(data);
            }
          }
        }
    }
  }

  Map<String, dynamic> _decodeData(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String && data.isNotEmpty) {
      final decoded = jsonDecode(data);
      return decoded is Map<String, dynamic> ? decoded : {'value': decoded};
    }
    return const {};
  }

  Future<void> subscribe(String channel) async {
    if (_subscribed.contains(channel)) return;
    _subscribed.add(channel);
    if (!_connected.value) return;

    if (channel.startsWith('private-') || channel.startsWith('presence-')) {
      final auth = await _authorize(channel);
      if (auth == null) {
        _subscribed.remove(channel);
        return;
      }
      _send({
        'event': 'pusher:subscribe',
        'data': {'channel': channel, 'auth': auth},
      });
    } else {
      _send({
        'event': 'pusher:subscribe',
        'data': {'channel': channel},
      });
    }
  }

  void unsubscribe(String channel) {
    _subscribed.remove(channel);
    _handlers.remove(channel);
    _send({
      'event': 'pusher:unsubscribe',
      'data': {'channel': channel},
    });
  }

  /// Register a handler. Returns a disposer.
  VoidCallback on(String channel, String event, void Function(Map<String, dynamic>) handler) {
    final normalized = event.startsWith('.') ? event.substring(1) : event;
    final channelMap = _handlers.putIfAbsent(
      channel,
      () => <String, List<void Function(Map<String, dynamic>)>>{},
    );
    channelMap.putIfAbsent(normalized, () => []).add(handler);
    channelMap.putIfAbsent('.$normalized', () => []).add(handler);
    subscribe(channel);
    return () {
      _handlers[channel]?[normalized]?.remove(handler);
      _handlers[channel]?['.$normalized']?.remove(handler);
    };
  }

  Future<String?> _authorize(String channel) async {
    if (_socketId == null) return null;
    try {
      final res = await _authDio.post<Map<String, dynamic>>(
        Env.broadcastAuthUrl,
        data: {'socket_id': _socketId, 'channel_name': channel},
      );
      return res.data?['auth'] as String?;
    } catch (_) {
      return null;
    }
  }

  void _send(Map<String, dynamic> payload) => _channel?.sink.add(jsonEncode(payload));

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _send({'event': 'pusher:ping', 'data': {}});
    });
  }

  void _scheduleReconnect() {
    _connected.value = false;
    _connecting = false;
    _pingTimer?.cancel();
    _sub?.cancel();
    _channel = null;
    _sub = null;
    if (_disposed || _reconnectTimer != null && _reconnectTimer!.isActive) return;
    _attempts = (_attempts + 1).clamp(1, 10);
    final delay = Duration(seconds: (3 * _attempts).clamp(3, 30));
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      connect();
    });
  }

  void dispose() {
    _disposed = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _connected.dispose();
  }
}
