import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { HttpError } from './httpError.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const scriptPath = path.join(__dirname, 'decode_qr_image.py');

export async function decodeQrImage(imageData) {
  if (!imageData || typeof imageData !== 'string') {
    throw new HttpError(400, 'Missing QR image data');
  }

  return await new Promise((resolve, reject) => {
    const child = spawn('python', [scriptPath], {
      stdio: ['pipe', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';

    child.stdout.on('data', (chunk) => {
      stdout += chunk.toString();
    });

    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
    });

    child.on('error', (error) => {
      reject(new HttpError(500, `QR decoder failed to start: ${error.message}`));
    });

    child.on('close', (code) => {
      try {
        if (code !== 0) {
          throw new HttpError(
            500,
            `QR decoder exited with code ${code}${stderr ? `: ${stderr.trim()}` : ''}`,
          );
        }
        const parsed = JSON.parse(stdout || '{}');
        if (!parsed.ok || !parsed.payload) {
          throw new HttpError(400, parsed.error || 'No QR found in image');
        }
        resolve(parsed.payload);
      } catch (error) {
        reject(
          error instanceof HttpError
            ? error
            : new HttpError(500, `Could not parse QR decoder output: ${error}`),
        );
      }
    });

    child.stdin.write(JSON.stringify({ imageData }));
    child.stdin.end();
  });
}
