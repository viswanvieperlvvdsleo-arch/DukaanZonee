import 'dart:js' as js;

void initWebSynth() {
  try {
    js.context.callMethod('eval', [
      """
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
            playTone(523.25, 'sine', 0.3, 0.0);
            playTone(659.25, 'sine', 0.3, 0.12);
            playTone(784.00, 'sine', 0.5, 0.24);
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
      """,
    ]);
  } catch (e) {
    // Web synth is a nice-to-have; native audio fallback still handles alerts.
  }
}

bool playWebSynth(String tone) {
  try {
    js.context.callMethod('dukaanZoneSynth', [tone]);
    return true;
  } catch (e) {
    return false;
  }
}
