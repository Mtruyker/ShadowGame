window.shadowSdk = new Promise((resolve) => {
  const script = document.createElement('script');
  script.src = '/sdk.js';
  script.onload = async () => {
    try {
      resolve(await window.YaGames.init());
    } catch {
      resolve(null);
    }
  };
  script.onerror = () => resolve(null);
  document.head.appendChild(script);
});

const effects = {
  step: [[132, 76, .035, .038, 'triangle', 0]],
  jump: [[210, 505, .12, .10, 'triangle', 0]],
  land: [[112, 55, .12, .12, 'triangle', 0]],
  flip: [[370, 740, .13, .07, 'sine', 0], [554, 831, .22, .045, 'sine', .035]],
  fall: [[325, 71, .20, .095, 'triangle', 0]],
  finish: [[392, 392, .25, .08, 'sine', 0], [494, 494, .28, .08, 'sine', .09],
           [587, 587, .31, .085, 'sine', .18], [784, 784, .40, .085, 'sine', .29]],
};
let audio;
const voices = new Set();

window.shadowUnlockAudio = () => {
  try {
    const Audio = window.AudioContext || window.webkitAudioContext;
    if (!Audio) return;
    audio ??= new Audio();
    if (audio.state !== 'running') audio.resume().catch(() => {});
  } catch {}
};

window.shadowEffect = (name) => {
  if (!audio || audio.state !== 'running' || !effects[name]) return;
  for (const [from, to, length, volume, type, delay] of effects[name]) {
    const time = audio.currentTime + delay;
    const voice = audio.createOscillator();
    const envelope = audio.createGain();
    voice.type = type;
    voice.frequency.setValueAtTime(from, time);
    voice.frequency.exponentialRampToValueAtTime(to, time + length);
    envelope.gain.setValueAtTime(.001, time);
    envelope.gain.exponentialRampToValueAtTime(volume, time + .012);
    envelope.gain.exponentialRampToValueAtTime(.001, time + length);
    voice.connect(envelope).connect(audio.destination);
    voices.add(voice);
    voice.onended = () => {
      voices.delete(voice);
      voice.disconnect();
      envelope.disconnect();
    };
    voice.start(time);
    voice.stop(time + length);
  }
};

window.shadowSilenceAudio = () => {
  for (const voice of voices) voice.stop();
  voices.clear();
};

document.addEventListener('contextmenu', (event) => event.preventDefault());
