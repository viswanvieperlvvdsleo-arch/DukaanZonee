import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:js' as js;

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();
  final Map<String, Timer> _activeAlerts = {};

  // Selected sound tone preference
  final ValueNotifier<String> selectedTone = ValueNotifier<String>('Default Chime');

  final List<String> availableTones = [
    'Default Chime',
    'Cash Register',
    'Digital Beep',
    'Success Ping',
    'Alert Siren',
    'Soft Pop',
    'Vroom Engine',
    'Silent'
  ];

  final Map<String, String> _toneUrls = {
    'Default Chime': 'https://assets.mixkit.co/active_storage/sfx/2869/2869-600.wav',
    'Cash Register': 'https://assets.mixkit.co/active_storage/sfx/2019/2019-600.wav',
    'Digital Beep': 'https://assets.mixkit.co/active_storage/sfx/911/911-600.wav',
    'Success Ping': 'https://assets.mixkit.co/active_storage/sfx/2568/2568-600.wav',
    'Alert Siren': 'https://assets.mixkit.co/active_storage/sfx/1653/1653-600.wav',
    'Soft Pop': 'https://assets.mixkit.co/active_storage/sfx/1005/1005-600.wav',
    'Vroom Engine': 'https://assets.mixkit.co/active_storage/sfx/2190/2190-600.wav',
  };

  Future<void> init() async {
    await _tts.setLanguage("en-IN");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);

    // Inject Web Audio API Synthesizer on Web to produce actual instrument/synth tones offline
    if (kIsWeb) {
      try {
        js.context.callMethod('eval', ["""
          window.dukaanZoneSynth = function(toneName) {
            try {
              var AudioContext = window.AudioContext || window.webkitAudioContext;
              if (!AudioContext) return;
              var ctx = new AudioContext();
              
              function playTone(freq, type, duration, delay) {
                setTimeout(function() {
                  var osc = ctx.createOscillator();
                  var gain = ctx.createGain();
                  osc.type = type;
                  osc.frequency.value = freq;
                  
                  gain.gain.setValueAtTime(0.15, ctx.currentTime);
                  gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + duration);
                  
                  osc.connect(gain);
                  gain.connect(ctx.destination);
                  
                  osc.start();
                  osc.stop(ctx.currentTime + duration);
                }, delay * 1000);
              }
              
              if (toneName === 'Default Chime') {
                playTone(523.25, 'sine', 0.3, 0.0); // C5
                playTone(659.25, 'sine', 0.3, 0.12); // E5
                playTone(784.00, 'sine', 0.5, 0.24); // G5
              } else if (toneName === 'Cash Register') {
                playTone(1500, 'sine', 0.08, 0.0);
                playTone(2200, 'sine', 0.3, 0.05);
              } else if (toneName === 'Digital Beep') {
                playTone(1000, 'square', 0.08, 0.0);
                playTone(1000, 'square', 0.08, 0.15);
              } else if (toneName === 'Success Ping') {
                playTone(440, 'sine', 0.08, 0.0);
                playTone(554, 'sine', 0.08, 0.06);
                playTone(659, 'sine', 0.08, 0.12);
                playTone(880, 'sine', 0.25, 0.18);
              } else if (toneName === 'Alert Siren') {
                playTone(800, 'sawtooth', 0.12, 0.0);
                playTone(600, 'sawtooth', 0.12, 0.12);
                playTone(800, 'sawtooth', 0.12, 0.24);
                playTone(600, 'sawtooth', 0.12, 0.36);
              } else if (toneName === 'Soft Pop') {
                playTone(300, 'triangle', 0.15, 0.0);
              } else if (toneName === 'Vroom Engine') {
                playTone(65, 'sawtooth', 0.25, 0.0);
                playTone(85, 'sawtooth', 0.2, 0.08);
                playTone(110, 'sawtooth', 0.3, 0.16);
              }
            } catch (e) {
              console.error(e);
            }
          };
        """]);
      } catch (e) {
        print("Failed to inject JS synthesizer: $e");
      }
    }
  }

  /// General TTS speaker method
  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  /// Plays the selected notification sound preview
  Future<void> playSelectedTone() async {
    final tone = selectedTone.value;
    if (tone == 'Silent') return;

    // 1. Try playing Web Audio API synthesized instrument tones on Web
    if (kIsWeb) {
      try {
        js.context.callMethod('dukaanZoneSynth', [tone]);
        return; // Played successfully!
      } catch (e) {
        print("Failed to play Web Audio: $e. Falling back to native player.");
      }
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
    // 1. Play Tone (Selected notification sound)
    await playSelectedTone();

    // 2. Speak the message
    await _tts.speak("Alert, the item $productName got low.");
  }

  /// Starts a persistent hourly alert for a specific product
  void startHourlyAlert(String productId, String productName) {
    if (_activeAlerts.containsKey(productId)) return;

    // Trigger immediately first
    triggerVoiceAlert(productName);

    // Set up hourly timer
    _activeAlerts[productId] = Timer.periodic(const Duration(hours: 1), (timer) {
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



