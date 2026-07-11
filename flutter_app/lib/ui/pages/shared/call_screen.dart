import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';
import 'package:dukaan_zone_flutter/services/sound_web_bridge_stub.dart'
    if (dart.library.html) 'package:dukaan_zone_flutter/services/sound_web_bridge_web.dart';

// ─────────────────────────────────────────────────────────────
// Enum: call state machine
// ─────────────────────────────────────────────────────────────
enum CallState { ringing, connecting, active, ended }

// ─────────────────────────────────────────────────────────────
// INCOMING CALL OVERLAY  (shown on top of any screen)
// ─────────────────────────────────────────────────────────────
class IncomingCallOverlay extends StatefulWidget {
  const IncomingCallOverlay({
    super.key,
    required this.callId,
    required this.callerName,
    required this.callerColor,
    required this.isVideo,
    required this.channelName,
    required this.onDismiss,
  });

  final String callId;
  final String callerName;
  final Color callerColor;
  final bool isVideo;
  final String channelName;
  final VoidCallback onDismiss;

  @override
  State<IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends State<IncomingCallOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  StreamSubscription<LiveEvent>? _callSub;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // Start ringing sound
    _startRingtone();

    // Auto-dismiss if caller cancels
    _callSub = liveSocketService.events.listen((event) {
      if (event.type == 'call.updated' &&
          event.payload['id'] == widget.callId) {
        final status = event.payload['status']?.toString() ?? '';
        if (status == 'ended' || status == 'missed' || status == 'declined') {
          if (mounted) widget.onDismiss();
        }
      }
    });

    // Auto-dismiss after 45 seconds (missed call)
    Future.delayed(const Duration(seconds: 45), () {
      if (mounted) {
        liveSocketService.sendCallEnd(id: widget.callId, status: 'missed');
        widget.onDismiss();
      }
    });
  }

  void _startRingtone() {
    if (kIsWeb) {
      try { playRingtone(); } catch (_) {}
    }
  }

  void _stopRingtone() {
    if (kIsWeb) {
      try { stopRingtone(); } catch (_) {}
    }
  }

  @override
  void dispose() {
    _stopRingtone();
    _pulseCtrl.dispose();
    _callSub?.cancel();
    super.dispose();
  }

  void _accept() {
    _stopRingtone();
    widget.onDismiss();
    liveSocketService.sendCallEnd(id: widget.callId, status: 'accepted');
    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      Navigator.of(ctx).push(MaterialPageRoute(
        builder: (_) => CallScreen(
          channelName: widget.channelName,
          callId: widget.callId,
          isVideo: widget.isVideo,
          remoteName: widget.callerName,
          remoteAvatarColor: widget.callerColor,
          isIncoming: true,
        ),
      ));
    }
  }

  void _decline() {
    _stopRingtone();
    liveSocketService.sendCallEnd(id: widget.callId, status: 'declined');
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1A1A2E).withOpacity(0.97),
              const Color(0xFF16213E).withOpacity(0.97),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 40,
              spreadRadius: 8,
            ),
          ],
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 60),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.isVideo ? '📹 Incoming Video Call' : '📞 Incoming Voice Call',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Transform.scale(
                scale: 1.0 + (_pulseCtrl.value * 0.1),
                child: CircleAvatar(
                  radius: 52,
                  backgroundColor: widget.callerColor,
                  child: Text(
                    widget.callerName.isNotEmpty
                        ? widget.callerName[0].toUpperCase()
                        : 'C',
                    style: const TextStyle(
                      fontSize: 40,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'is calling you…',
              style: TextStyle(color: Colors.white54, fontSize: 15),
            ),
            const SizedBox(height: 36),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CallAction(
                  icon: Icons.call_end,
                  label: 'Decline',
                  color: Colors.red,
                  onTap: _decline,
                ),
                _CallAction(
                  icon: widget.isVideo ? Icons.videocam : Icons.call,
                  label: 'Accept',
                  color: Colors.green,
                  onTap: _accept,
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _CallAction extends StatelessWidget {
  const _CallAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GLOBAL NAVIGATOR KEY
// ─────────────────────────────────────────────────────────────
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ─────────────────────────────────────────────────────────────
// GLOBAL CALL MANAGER  (singleton, listens from app root)
// ─────────────────────────────────────────────────────────────
class GlobalCallManager {
  GlobalCallManager._();
  static final instance = GlobalCallManager._();

  StreamSubscription<LiveEvent>? _sub;
  OverlayEntry? _overlayEntry;
  String? _activeOverlayCallId;

  void init() {
    _sub?.cancel();
    _sub = liveSocketService.events.listen(_onEvent);
  }

  void dispose() {
    _sub?.cancel();
  }

  void _onEvent(LiveEvent event) {
    if (event.type != 'call.started') return;

    final callId = event.payload['id']?.toString();
    if (callId == null || callId == _activeOverlayCallId) return;

    final callerData = Map<String, dynamic>.from(
        event.payload['caller'] as Map? ?? {});
    final senderId = callerData['id']?.toString();

    // Ignore if WE are the caller
    if (senderId == authService.currentUser.value?.id) return;

    final channelName = event.payload['roomId']?.toString() ?? '';
    final kind = event.payload['kind']?.toString() ?? 'voice';
    final callerName = callerData['name']?.toString() ?? 'Unknown';

    _showIncomingCallOverlay(
      callId: callId,
      callerName: callerName,
      isVideo: kind == 'video',
      channelName: channelName,
    );
  }

  void _showIncomingCallOverlay({
    required String callId,
    required String callerName,
    required bool isVideo,
    required String channelName,
  }) {
    final overlayState = navigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    _activeOverlayCallId = callId;
    _overlayEntry?.remove();

    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        child: IncomingCallOverlay(
          callId: callId,
          callerName: callerName,
          callerColor: const Color(0xFF6C63FF),
          isVideo: isVideo,
          channelName: channelName,
          onDismiss: _dismissOverlay,
        ),
      ),
    );

    overlayState.insert(_overlayEntry!);
  }

  void _dismissOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _activeOverlayCallId = null;
  }
}

// ─────────────────────────────────────────────────────────────
// CALL SCREEN
// ─────────────────────────────────────────────────────────────
class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
    required this.channelName,
    required this.callId,
    required this.isVideo,
    required this.remoteName,
    required this.remoteAvatarColor,
    this.isIncoming = false,
  });

  final String channelName;
  final String callId;
  final bool isVideo;
  final String remoteName;
  final Color remoteAvatarColor;
  final bool isIncoming;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  RtcEngine? _engine;
  CallState _callState = CallState.ringing;
  int? _remoteUid;
  bool _muted = false;
  bool _localVideoDisabled = false;
  bool _speakerOn = true;
  StreamSubscription<LiveEvent>? _callSub;
  DateTime? _callAnsweredAt;
  Timer? _durationTimer;
  int _durationSeconds = 0;

  @override
  void initState() {
    super.initState();
    _listenCallEvents();
    _initAgora();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _callSub?.cancel();
    _disposeAgora();
    super.dispose();
  }

  void _listenCallEvents() {
    _callSub = liveSocketService.events.listen((event) {
      if (event.type == 'call.updated' &&
          event.payload['id'] == widget.callId) {
        final status = event.payload['status']?.toString() ?? '';
        if (!mounted) return;
        if (status == 'declined') {
          _showCallEndMessage('Call declined');
          _leaveAndPop();
        } else if (status == 'missed') {
          _showCallEndMessage('No answer');
          _leaveAndPop();
        } else if (status == 'ended') {
          _leaveAndPop();
        } else if (status == 'accepted') {
          setState(() => _callState = CallState.connecting);
        }
      }
    });
  }

  /// Agora channel IDs must only contain [a-zA-Z0-9_-] and max 64 chars.
  String get _safeChannelId => widget.channelName
      .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_')
      .substring(0, widget.channelName.length.clamp(0, 64));

  Future<void> _initAgora() async {
    try {
      final res = await apiClient.getJson(
          '/api/chats/rooms/${Uri.encodeComponent(widget.channelName)}/call-token');
      final appId = res['appId']?.toString() ?? '';
      final token = res['token']?.toString() ?? '';

      if (appId.isEmpty) {
        debugPrint('[CallScreen] Agora App ID empty');
        if (mounted) setState(() => _callState = CallState.ended);
        return;
      }

      debugPrint('[CallScreen] Joining channel: $_safeChannelId');

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      _engine!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection conn, int elapsed) {
          debugPrint('[CallScreen] Joined uid=${conn.localUid}');
          if (mounted) setState(() => _callState = CallState.connecting);
        },
        onUserJoined: (RtcConnection conn, int remoteUid, int elapsed) {
          debugPrint('[CallScreen] Remote $remoteUid joined');
          if (mounted) {
            setState(() {
              _remoteUid = remoteUid;
              _callState = CallState.active;
            });
            _callAnsweredAt = DateTime.now();
            _startDurationTimer();
          }
        },
        onUserOffline: (RtcConnection conn, int remoteUid,
            UserOfflineReasonType reason) {
          debugPrint('[CallScreen] Remote $remoteUid left: $reason');
          if (mounted) setState(() => _remoteUid = null);
          _endCall(status: 'ended');
        },
        onError: (ErrorCodeType code, String msg) {
          debugPrint('[CallScreen] Error $code: $msg');
        },
      ));

      // Always enable audio (video calls need audio too)
      await _engine!.enableAudio();

      if (widget.isVideo) {
        await _engine!.enableVideo();
        await _engine!.startPreview();
      }

      if (!kIsWeb) {
        await _engine!.setEnableSpeakerphone(true);
      }

      await _engine!.joinChannel(
        token: token,
        channelId: _safeChannelId,
        uid: 0,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          publishMicrophoneTrack: true,
          publishCameraTrack: widget.isVideo,
        ),
      );
    } catch (e) {
      debugPrint('[CallScreen] Agora init failed: $e');
      if (mounted) setState(() => _callState = CallState.ended);
    }
  }

  Future<void> _disposeAgora() async {
    try {
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (e) {
      debugPrint('[CallScreen] Agora release: $e');
    }
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _durationSeconds++);
    });
  }

  void _endCall({String status = 'ended'}) {
    liveSocketService.sendCallEnd(id: widget.callId, status: status);
    _leaveAndPop();
  }

  void _leaveAndPop() {
    _durationTimer?.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  void _showCallEndMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.black87,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _engine?.muteLocalAudioStream(_muted);
  }

  void _toggleVideo() {
    setState(() => _localVideoDisabled = !_localVideoDisabled);
    _engine?.muteLocalVideoStream(_localVideoDisabled);
  }

  void _toggleSpeaker() {
    setState(() => _speakerOn = !_speakerOn);
    if (!kIsWeb) _engine?.setEnableSpeakerphone(_speakerOn);
  }

  String get _statusLabel {
    switch (_callState) {
      case CallState.ringing:
        return widget.isIncoming ? 'Ringing…' : 'Calling…';
      case CallState.connecting:
        return 'Connecting…';
      case CallState.active:
        return _formatDuration(_durationSeconds);
      case CallState.ended:
        return 'Call Ended';
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (_) => _endCall(),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A1A),
        body: SafeArea(
          child: Stack(
            children: [
              // Remote video (full screen)
              if (widget.isVideo && _remoteUid != null && _engine != null)
                Positioned.fill(
                  child: AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: _engine!,
                      canvas: VideoCanvas(uid: _remoteUid),
                      connection:
                          RtcConnection(channelId: _safeChannelId),
                    ),
                  ),
                ),

              // Avatar / status center
              if (!widget.isVideo || _remoteUid == null)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.0,
                        colors: [
                          widget.remoteAvatarColor.withOpacity(0.25),
                          const Color(0xFF0A0A1A),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.95, end: 1.05),
                          duration: const Duration(milliseconds: 900),
                          builder: (_, v, child) =>
                              Transform.scale(scale: v, child: child),
                          child: CircleAvatar(
                            radius: 72,
                            backgroundColor:
                                widget.remoteAvatarColor.withOpacity(0.85),
                            child: Text(
                              widget.remoteName.isNotEmpty
                                  ? widget.remoteName[0].toUpperCase()
                                  : 'C',
                              style: const TextStyle(
                                fontSize: 52,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          widget.remoteName,
                          style: const TextStyle(
                            fontSize: 28,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _statusLabel,
                          style: TextStyle(
                            fontSize: 16,
                            color: _callState == CallState.active
                                ? Colors.greenAccent
                                : Colors.white54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Local video PiP
              if (widget.isVideo && !_localVideoDisabled && _engine != null)
                Positioned(
                  right: 16,
                  top: 16,
                  width: 110,
                  height: 150,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white30, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: _engine!,
                        canvas: const VideoCanvas(uid: 0),
                      ),
                    ),
                  ),
                ),

              // Controls
              Positioned(
                left: 0,
                right: 0,
                bottom: 40,
                child: Column(
                  children: [
                    if (_callState == CallState.active)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.circle,
                                color: Colors.greenAccent, size: 10),
                            const SizedBox(width: 6),
                            Text(
                              _formatDuration(_durationSeconds),
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ControlButton(
                          icon: _muted ? Icons.mic_off : Icons.mic,
                          label: _muted ? 'Unmute' : 'Mute',
                          color: _muted ? Colors.red : Colors.white,
                          onTap: _toggleMute,
                        ),
                        GestureDetector(
                          onTap: () => _endCall(),
                          child: Column(
                            children: [
                              const CircleAvatar(
                                radius: 36,
                                backgroundColor: Colors.red,
                                child: Icon(Icons.call_end,
                                    color: Colors.white, size: 32),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'End',
                                style: TextStyle(
                                    color: Colors.red.shade300,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        if (widget.isVideo)
                          _ControlButton(
                            icon: _localVideoDisabled
                                ? Icons.videocam_off
                                : Icons.videocam,
                            label: _localVideoDisabled ? 'Cam Off' : 'Cam On',
                            color:
                                _localVideoDisabled ? Colors.red : Colors.white,
                            onTap: _toggleVideo,
                          )
                        else
                          _ControlButton(
                            icon: _speakerOn
                                ? Icons.volume_up
                                : Icons.volume_off,
                            label: _speakerOn ? 'Speaker' : 'Earpiece',
                            color: Colors.white,
                            onTap: _toggleSpeaker,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withOpacity(0.12),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
                color: color.withOpacity(0.85),
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
