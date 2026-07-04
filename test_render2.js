const http = require('http');
const https = require('https');

async function test() {
  try {
    const res = await fetch('https://dukaanzone.onrender.com/api/chats/unread-count');
    const text = await res.text();
    console.log('Status:', res.status);
    console.log('Body:', text);
  } catch (e) {
    console.error(e);
  }
}
test();
