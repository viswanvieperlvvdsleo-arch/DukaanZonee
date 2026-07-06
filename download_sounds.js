const https = require('https');
const fs = require('fs');
const path = require('path');

const sounds = {
  'default_chime.wav': 'https://assets.mixkit.co/active_storage/sfx/2869/2869-600.wav',
  'cash_register.wav': 'https://assets.mixkit.co/active_storage/sfx/2019/2019-600.wav',
  'digital_beep.wav': 'https://assets.mixkit.co/active_storage/sfx/911/911-600.wav',
  'success_ping.wav': 'https://assets.mixkit.co/active_storage/sfx/2568/2568-600.wav',
  'alert_siren.wav': 'https://assets.mixkit.co/active_storage/sfx/1653/1653-600.wav',
  'soft_pop.wav': 'https://assets.mixkit.co/active_storage/sfx/1005/1005-600.wav',
  'vroom_engine.wav': 'https://assets.mixkit.co/active_storage/sfx/2190/2190-600.wav'
};

const dir = path.join(__dirname, 'flutter_app', 'assets', 'sounds');
if (!fs.existsSync(dir)) {
  fs.mkdirSync(dir, { recursive: true });
}

async function download() {
  for (const [filename, url] of Object.entries(sounds)) {
    const dest = path.join(dir, filename);
    console.log(`Downloading ${filename}...`);
    await new Promise((resolve, reject) => {
      https.get(url, (res) => {
        if (res.statusCode !== 200) {
           console.log(`Failed to get ${url} - ${res.statusCode}`);
           resolve();
           return;
        }
        const file = fs.createWriteStream(dest);
        res.pipe(file);
        file.on('finish', () => {
          file.close();
          resolve();
        });
      }).on('error', (err) => {
        console.log(`Error on ${filename}:`, err.message);
        resolve();
      });
    });
  }
  console.log('Done!');
}

download();
