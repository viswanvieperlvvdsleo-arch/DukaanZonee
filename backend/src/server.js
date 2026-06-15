import { createApp } from './app.js';
import { config } from './config.js';
import { createServer } from 'node:http';
import { attachRealtime } from './realtime/socketHub.js';

const app = createApp();
const server = createServer(app);

attachRealtime(server);

server.listen(config.port, () => {
  console.log(`DukaanZone API listening on http://localhost:${config.port}`);
  console.log(`DukaanZone realtime listening on ws://localhost:${config.port}/ws`);
});
