import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

import 'sound_web_bridge_stub.dart'
    if (dart.library.html) 'sound_web_bridge_web.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();
  final Map<String, Timer> _activeAlerts = {};

  // Selected sound tone preference
  final ValueNotifier<String> selectedTone = ValueNotifier<String>(
    'Default Chime',
  );

  final List<String> availableTones = [
    'Default Chime',
    'Cash Register',
    'Digital Beep',
    'Success Ping',
    'Alert Siren',
    'Soft Pop',
    'Vroom Engine',
    'Silent',
  ];

  final Map<String, String> _toneUrls = {
    'Default Chime':
        'https://assets.mixkit.co/active_storage/sfx/2869/2869-600.wav',
    'Cash Register':
        'https://assets.mixkit.co/active_storage/sfx/2019/2019-600.wav',
    'Digital Beep':
        'https://assets.mixkit.co/active_storage/sfx/911/911-600.wav',
    'Success Ping':
        'https://assets.mixkit.co/active_storage/sfx/2568/2568-600.wav',
    'Alert Siren':
        'https://assets.mixkit.co/active_storage/sfx/1653/1653-600.wav',
    'Soft Pop': 'https://assets.mixkit.co/active_storage/sfx/1005/1005-600.wav',
    'Vroom Engine':
        'https://assets.mixkit.co/active_storage/sfx/2190/2190-600.wav',
  };

  Future<void> init() async {
    await _tts.setLanguage("en-IN");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);

    initWebSynth();
  }

  /// General TTS speaker method
  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  /// Plays the selected notification sound preview
  Future<void> playSelectedTone() async {
    final tone = selectedTone.value;
    if (tone == 'Silent') return;

    // 1. Try playing Web Audio API synthesized instrument tones on Web.
    if (playWebSynth(tone)) {
      return;
    }

    // 2. Play Mobile/Native sound (falls back to native file or system alert)
    final url = _toneUrls[tone];
    if (url != null) {
      try {
        await _player.stop();
        await _player.play(UrlSource(url));
        return;
      } catch (e) {
        print("Failed to play native audio source: $e");
      }
    }
  }

  /// Plays the selected notification tone followed by a voice message
  Future<void> triggerVoiceAlert(String productName) async {
    await playSelectedTone();

    final cleanName = productName.trim().isEmpty
        ? 'one item'
        : productName.trim();
    await _tts.setLanguage("en-IN");
    await _tts.setPitch(0.92);
    await _tts.setSpeechRate(0.42);
    await _tts.stop();
    await _tts.speak("Low stock alert. $cleanName needs restock.");
  }

  /// Starts a persistent hourly alert for a specific product
  void startHourlyAlert(String productId, String productName) {
    if (_activeAlerts.containsKey(productId)) return;

    // Trigger immediately first
    triggerVoiceAlert(productName);

    // Set up hourly timer
    _activeAlerts[productId] = Timer.periodic(const Duration(hours: 1), (
      timer,
    ) {
      triggerVoiceAlert(productName);
    });
  }

  /// Stops alerts for a product (called when restocked)
  void stopAlert(String productId) {
    _activeAlerts[productId]?.cancel();
    _activeAlerts.remove(productId);
  }

  void dispose() {
    for (var timer in _activeAlerts.values) {
      timer.cancel();
    }
    _activeAlerts.clear();
  }
}

final soundService = SoundService();
