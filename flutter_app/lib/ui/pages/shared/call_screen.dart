import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
    required this.channelName,
    required this.callId,
    required this.isVideo,
    required this.remoteName,
    required this.remoteAvatarColor,
  });

  final String channelName;
  final String callId;
  final bool isVideo;
  final String remoteName;
  final Color remoteAvatarColor;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  RtcEngine? _engine;
  bool _localUserJoined = false;
  int? _remoteUid;
  bool _muted = false;
  bool _localVideoDisabled = false;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  @override
  void dispose() {
    _disposeAgora();
    super.dispose();
  }

  Future<void> _initAgora() async {
    try {
      final res = await apiClient.getJson('/api/chats/rooms/${widget.channelName}/call-token');
      final appId = res['appId']?.toString() ?? '';
      final token = res['token']?.toString() ?? '';
      
      if (appId.isEmpty) {
        debugPrint('Agora App ID is empty');
        return;
      }

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint("local user ${connection.localUid} joined");
            if (mounted) {
              setState(() {
                _localUserJoined = true;
              });
            }
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint("remote user $remoteUid joined");
            if (mounted) {
              setState(() {
                _remoteUid = remoteUid;
              });
            }
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint("remote user $remoteUid left");
            if (mounted) {
              setState(() {
                _remoteUid = null;
              });
            }
            _endCall();
          },
        ),
      );

      if (widget.isVideo) {
        await _engine!.enableVideo();
        await _engine!.startPreview();
      } else {
        await _engine!.enableAudio();
      }

      await _engine!.joinChannel(
        token: token,
        channelId: widget.channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      debugPrint("Agora init failed: $e");
    }
  }

  Future<void> _disposeAgora() async {
    try {
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (e) {
      debugPrint("Agora release failed: $e");
    }
  }

  void _endCall() {
    liveSocketService.sendCallEnd(id: widget.callId);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
    });
    _engine?.muteLocalAudioStream(_muted);
  }

  void _toggleVideo() {
    setState(() {
      _localVideoDisabled = !_localVideoDisabled;
    });
    _engine?.muteLocalVideoStream(_localVideoDisabled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.95),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: widget.isVideo && _remoteUid != null
                  ? AgoraVideoView(
                      controller: VideoViewController.remote(
                        rtcEngine: _engine!,
                        canvas: VideoCanvas(uid: _remoteUid),
                        connection: RtcConnection(channelId: widget.channelName),
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 70,
                            backgroundColor: widget.remoteAvatarColor,
                            child: Text(
                              widget.remoteName.isNotEmpty ? widget.remoteName[0].toUpperCase() : 'C',
                              style: const TextStyle(
                                fontSize: 48,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            widget.remoteName,
                            style: const TextStyle(
                              fontSize: 26,
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _remoteUid != null ? 'Connected' : 'Calling...',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white60,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            if (widget.isVideo && _localUserJoined && !_localVideoDisabled)
              Positioned(
                right: 24,
                top: 24,
                width: 120,
                height: 160,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white30, width: 2),
                  ),
                  child: AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: _engine!,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withOpacity(0.18),
                    child: IconButton(
                      icon: Icon(
                        _muted ? Icons.mic_off : Icons.mic,
                        color: Colors.white,
                      ),
                      onPressed: _toggleMute,
                    ),
                  ),
                  GestureDetector(
                    onTap: _endCall,
                    child: const CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.red,
                      child: Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  if (widget.isVideo)
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.18),
                      child: IconButton(
                        icon: Icon(
                          _localVideoDisabled ? Icons.videocam_off : Icons.videocam,
                          color: Colors.white,
                        ),
                        onPressed: _toggleVideo,
                      ),
                    )
                  else
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.18),
                      child: const Icon(
                        Icons.volume_up,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
