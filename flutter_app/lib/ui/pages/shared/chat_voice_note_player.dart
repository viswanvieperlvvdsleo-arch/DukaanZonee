import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ChatVoiceNotePlayer extends StatefulWidget {
  const ChatVoiceNotePlayer({
    super.key,
    required this.audioUrl,
    required this.isSent,
    this.durationSeconds,
  });

  final String? audioUrl;
  final bool isSent;
  final int? durationSeconds;

  @override
  State<ChatVoiceNotePlayer> createState() => _ChatVoiceNotePlayerState();
}

class _ChatVoiceNotePlayerState extends State<ChatVoiceNotePlayer> {
  late final AudioPlayer _player;
  Duration _position = Duration.zero;
  Duration? _loadedDuration;
  bool _isPlaying = false;
  bool _startingPlayback = false;
  String? _playbackError;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });
    _player.onDurationChanged.listen((value) {
      if (!mounted) return;
      setState(() {
        _loadedDuration = value;
      });
    });
    _player.onPositionChanged.listen((value) {
      if (!mounted) return;
      setState(() {
        _position = value;
      });
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void didUpdateWidget(covariant ChatVoiceNotePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioUrl != widget.audioUrl) {
      _resetPlayback();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Duration get _totalDuration {
    final fallback = Duration(seconds: widget.durationSeconds ?? 0);
    final loaded = _loadedDuration;
    if (loaded == null || loaded.inMilliseconds <= 0) {
      return fallback;
    }
    return loaded;
  }

  double get _progressValue {
    final totalMs = _totalDuration.inMilliseconds;
    if (totalMs <= 0) return 0;
    final currentMs = _position.inMilliseconds.clamp(0, totalMs);
    return currentMs / totalMs;
  }

  Future<void> _resetPlayback() async {
    await _player.stop();
    if (!mounted) return;
    setState(() {
      _position = Duration.zero;
      _loadedDuration = null;
      _isPlaying = false;
      _playbackError = null;
    });
  }

  Future<void> _togglePlayback() async {
    final audioUrl = widget.audioUrl;
    if (audioUrl == null || audioUrl.isEmpty || _startingPlayback) return;

    if (_isPlaying) {
      await _player.pause();
      return;
    }

    try {
      setState(() {
        _startingPlayback = true;
        _playbackError = null;
      });

      final total = _totalDuration;
      if (_position.inMilliseconds > 0 &&
          total.inMilliseconds > 0 &&
          _position >= total) {
        await _player.seek(Duration.zero);
      }

      if (_position.inMilliseconds > 0) {
        await _player.resume();
      } else if (audioUrl.startsWith('data:') ||
          audioUrl.startsWith('http://') ||
          audioUrl.startsWith('https://') ||
          audioUrl.startsWith('blob:')) {
        await _player.play(UrlSource(audioUrl));
      } else if (!kIsWeb) {
        await _player.play(DeviceFileSource(audioUrl));
      } else {
        await _player.play(UrlSource(audioUrl));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _playbackError = 'Playback unavailable';
      });
    } finally {
      if (mounted) {
        setState(() {
          _startingPlayback = false;
        });
      }
    }
  }

  String _formatDuration(Duration value) {
    final totalSeconds = value.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.isSent ? Colors.white : const Color(0xFF5B86C5);
    final detailColor = widget.isSent
        ? Colors.white.withOpacity(0.84)
        : const Color(0xFF7C8AA5);
    final lineColor = widget.isSent
        ? Colors.white.withOpacity(0.22)
        : const Color(0xFFD8E3F2);
    final progressColor = widget.isSent ? Colors.white : const Color(0xFF5B86C5);
    final displayDuration = _position > Duration.zero ? _position : _totalDuration;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _togglePlayback,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: widget.isSent
                  ? Colors.white.withOpacity(0.12)
                  : const Color(0xFFE8F0FB),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: iconColor,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 130,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: _progressValue > 0 ? _progressValue : 0.02,
                  minHeight: 4,
                  backgroundColor: lineColor,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.graphic_eq_rounded,
                    color: detailColor,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDuration(displayDuration),
                    style: TextStyle(
                      color: detailColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (_playbackError != null) ...[
                const SizedBox(height: 4),
                Text(
                  _playbackError!,
                  style: TextStyle(
                    color: detailColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
