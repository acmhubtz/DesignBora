import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../../features/calls/call_screen.dart';
import '../api/api_client.dart';
import '../constants/api_constants.dart';
import '../notifications/push_service.dart';

enum CallPhase { idle, outgoing, incoming, connecting, active, ended }

/// Simu za sauti (WebRTC). Sauti inaenda simu kwa simu; backend inapitisha signaling tu.
class CallManager extends ChangeNotifier with WidgetsBindingObserver {
  CallManager._();
  static final CallManager instance = CallManager._();

  final ApiClient _api = ApiClient();

  CallPhase phase = CallPhase.idle;
  int? callId;
  int? orderId;
  String otherName = '';
  bool isCaller = false;
  bool muted = false;
  bool speaker = false;
  DateTime? connectedAt;
  String? endMessage;

  int? _myId;
  StompClient? _stomp;
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  List<Map<String, dynamic>> _iceServers = const [];
  final List<RTCIceCandidate> _pendingCandidates = [];
  bool _remoteSet = false;
  bool _screenOpen = false;
  bool _checking = false;
  Timer? _ringTimer;
  Timer? _connectTimer;
  Timer? _vibrateTimer;

  bool get busy => phase != CallPhase.idle;

  // App ikirudi mbele: angalia kama kuna simu inayoingia
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) checkIncoming();
  }

  // ------------------------------------------------------------ kupiga

  Future<void> startOutgoing({
    required int orderId,
    required String otherName,
  }) async {
    if (busy) return;
    this.orderId = orderId;
    this.otherName = otherName;
    isCaller = true;
    _setPhase(CallPhase.outgoing);
    _openScreen();
    try {
      _localStream = await _getMic(); // ruhusa ya kipaza sauti kabla ya kuita
      final res = await _api.dio.post('/orders/$orderId/calls');
      callId = (res.data['data']['id'] as num).toInt();
      await _prepare();
      _ringTimer = Timer(const Duration(seconds: 60), () {
        if (phase == CallPhase.outgoing) hangUp(message: 'Hakupokea simu');
      });
    } catch (e) {
      await _cleanup(_err(e));
    }
  }

  // ------------------------------------------------------------ kupokea

  Future<void> checkIncoming() async {
    if (busy || _checking) return;
    _checking = true;
    try {
      if (await _api.getToken() == null) return;
      final res = await _api.dio.get('/calls/incoming');
      final data = res.data['data'];
      if (data == null || busy) return;
      callId = (data['id'] as num).toInt();
      orderId = (data['orderId'] as num).toInt();
      otherName = '${data['callerName'] ?? 'DesignBora'}';
      isCaller = false;
      _setPhase(CallPhase.incoming);
      _openScreen();
      _startVibrate();
      await _prepare(); // sikiliza: mpigaji akikata kabla hujapokea
    } catch (e) {
      debugPrint('Simu inayoingia: $e');
    } finally {
      _checking = false;
    }
  }

  Future<void> accept() async {
    if (phase != CallPhase.incoming) return;
    _stopVibrate();
    _setPhase(CallPhase.connecting);
    _startConnectTimer();
    try {
      _localStream = await _getMic();
      await _createPeer(); // tayari kabla OFFER haijafika
      await _api.dio.post('/calls/$callId/accept');
    } catch (e) {
      await hangUp(message: _err(e));
    }
  }

  Future<void> reject() async {
    if (phase != CallPhase.incoming) return;
    final id = callId;
    await _cleanup('Umekataa simu');
    if (id != null) _post('/calls/$id/reject');
  }

  Future<void> hangUp({String? message}) async {
    if (phase == CallPhase.idle || phase == CallPhase.ended) return;
    final id = callId;
    await _cleanup(message ?? 'Simu imekatwa');
    if (id != null) _post('/calls/$id/end');
  }

  void toggleMute() {
    muted = !muted;
    for (final t in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = !muted;
    }
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    speaker = !speaker;
    try {
      await Helper.setSpeakerphoneOn(speaker);
    } catch (_) {}
    notifyListeners();
  }

  void screenClosed() => _screenOpen = false;

  // ------------------------------------------------------------ signaling

  Future<void> _prepare() async {
    _myId = await _api.getUserId();
    final ice = await _api.dio.get('/calls/ice-servers');
    _iceServers = (ice.data['data']['iceServers'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    await _connectStomp();
  }

  Future<void> _connectStomp() async {
    final token = await _api.getToken();
    final connected = Completer<void>();
    final id = callId;
    _stomp = StompClient(
      config: StompConfig(
        url: ApiConstants.wsUrl,
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
        onConnect: (_) {
          _stomp?.subscribe(
            destination: '/topic/call/$id',
            callback: (frame) {
              if (frame.body == null) return;
              _onSignal(jsonDecode(frame.body!) as Map<String, dynamic>);
            },
          );
          if (!connected.isCompleted) connected.complete();
        },
        onWebSocketError: (e) => debugPrint('Call WS: $e'),
        onStompError: (f) => debugPrint('Call STOMP: ${f.body}'),
      ),
    );
    _stomp!.activate();
    await connected.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Imeshindwa kuunganisha na server'),
    );
    // SUBSCRIBE ifike server kabla ya hatua inayofuata
    await Future.delayed(const Duration(milliseconds: 400));
  }

  Future<void> _onSignal(Map<String, dynamic> msg) async {
    final sender = msg['senderId'];
    if (sender != null && (sender as num).toInt() == _myId) return;

    try {
      switch (msg['type']) {
        case 'ACCEPTED':
          if (isCaller && phase == CallPhase.outgoing) {
            _ringTimer?.cancel();
            _setPhase(CallPhase.connecting);
            _startConnectTimer();
            await _createPeer();
            final offer = await _pc!.createOffer({
              'offerToReceiveAudio': true,
              'offerToReceiveVideo': false,
            });
            await _pc!.setLocalDescription(offer);
            _send({'type': 'OFFER', 'sdp': offer.sdp});
          }
        case 'OFFER':
          if (!isCaller && _pc != null) {
            await _pc!.setRemoteDescription(
              RTCSessionDescription(msg['sdp'] as String, 'offer'),
            );
            await _flushCandidates();
            final answer = await _pc!.createAnswer({
              'offerToReceiveAudio': true,
              'offerToReceiveVideo': false,
            });
            await _pc!.setLocalDescription(answer);
            _send({'type': 'ANSWER', 'sdp': answer.sdp});
          }
        case 'ANSWER':
          if (isCaller && _pc != null) {
            await _pc!.setRemoteDescription(
              RTCSessionDescription(msg['sdp'] as String, 'answer'),
            );
            await _flushCandidates();
          }
        case 'ICE':
          final c = RTCIceCandidate(
            msg['candidate'] as String?,
            msg['sdpMid'] as String?,
            (msg['sdpMLineIndex'] as num?)?.toInt(),
          );
          if (_pc != null && _remoteSet) {
            await _pc!.addCandidate(c);
          } else {
            _pendingCandidates.add(c);
          }
        case 'REJECTED':
          await _cleanup('$otherName amekataa simu');
        case 'MISSED':
          await _cleanup(isCaller ? 'Hakupokea simu' : 'Simu imekatika');
        case 'ENDED':
          await _cleanup('Simu imeisha');
      }
    } catch (e) {
      debugPrint('Signal ${msg['type']}: $e');
    }
  }

  Future<void> _createPeer() async {
    _pc = await createPeerConnection({
      'iceServers': _iceServers,
      'sdpSemantics': 'unified-plan',
    });
    for (final t in _localStream!.getAudioTracks()) {
      await _pc!.addTrack(t, _localStream!);
    }
    _pc!.onIceCandidate = (c) {
      if (c.candidate == null) return;
      _send({
        'type': 'ICE',
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });
    };
    _pc!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
          phase == CallPhase.connecting) {
        _connectTimer?.cancel();
        connectedAt = DateTime.now();
        _setPhase(CallPhase.active);
        Helper.setSpeakerphoneOn(speaker).catchError((_) {});
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        hangUp(message: 'Muunganisho umekatika. Angalia mtandao wako.');
      }
    };
  }

  Future<void> _flushCandidates() async {
    _remoteSet = true;
    for (final c in _pendingCandidates) {
      await _pc?.addCandidate(c);
    }
    _pendingCandidates.clear();
  }

  void _send(Map<String, dynamic> m) {
    _stomp?.send(destination: '/app/call.signal/$callId', body: jsonEncode(m));
  }

  // ------------------------------------------------------------ wasaidizi

  Future<MediaStream> _getMic() =>
      navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});

  void _startConnectTimer() {
    _connectTimer?.cancel();
    _connectTimer = Timer(const Duration(seconds: 25), () {
      if (phase == CallPhase.connecting) {
        hangUp(message: 'Imeshindwa kuunganisha sauti. Jaribu tena.');
      }
    });
  }

  void _startVibrate() {
    _vibrateTimer?.cancel();
    HapticFeedback.vibrate();
    _vibrateTimer = Timer.periodic(
      const Duration(milliseconds: 1500),
      (_) => HapticFeedback.vibrate(),
    );
  }

  void _stopVibrate() {
    _vibrateTimer?.cancel();
    _vibrateTimer = null;
  }

  void _openScreen() {
    if (_screenOpen) return;
    final nav = PushService.navigatorKey.currentState;
    if (nav == null) return;
    _screenOpen = true;
    nav.push(MaterialPageRoute(builder: (_) => const CallScreen()));
  }

  void _setPhase(CallPhase p) {
    phase = p;
    notifyListeners();
  }

  Future<void> _cleanup(String message) async {
    if (phase == CallPhase.idle || phase == CallPhase.ended) return;
    endMessage = message;
    _ringTimer?.cancel();
    _connectTimer?.cancel();
    _stopVibrate();
    _setPhase(CallPhase.ended);

    try {
      for (final t in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
        await t.stop();
      }
      await _localStream?.dispose();
    } catch (_) {}
    try {
      await _pc?.close();
    } catch (_) {}
    _stomp?.deactivate();
    _localStream = null;
    _pc = null;
    _stomp = null;
    _pendingCandidates.clear();
    _remoteSet = false;
    try {
      await Helper.setSpeakerphoneOn(false);
    } catch (_) {}

    Future.delayed(const Duration(milliseconds: 1800), () {
      phase = CallPhase.idle;
      callId = null;
      orderId = null;
      muted = false;
      speaker = false;
      connectedAt = null;
      endMessage = null;
      notifyListeners();
    });
  }

  void _post(String path) {
    _api.dio
        .post(path)
        .then((_) {})
        .catchError((Object e) => debugPrint('$path: $e'));
  }

  String _err(Object e) {
    try {
      final d = (e as dynamic).response?.data;
      if (d != null && d['message'] != null) return d['message'].toString();
    } catch (_) {}
    final s = '$e';
    if (s.contains('Permission') ||
        s.contains('NotAllowed') ||
        s.contains('denied')) {
      return 'Ruhusu DesignBora kutumia kipaza sauti: Settings → Apps → DesignBora → Permissions';
    }
    return 'Imeshindwa kupiga simu. Angalia mtandao na ujaribu tena.';
  }
}
