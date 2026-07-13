// Minimal LiveKit token server for SIMUL.
//
// The Flutter app calls:  GET /token?room=<id>&identity=<uid>&name=<name>&canPublish=true
// and expects JSON:       { "token": "<jwt>" }
//
// Run locally:
//   npm install
//   LIVEKIT_API_KEY=devkey LIVEKIT_API_SECRET=secret node server.js
// (those defaults match `livekit-server --dev`)
//
// For LiveKit Cloud, set LIVEKIT_API_KEY / LIVEKIT_API_SECRET from your
// project's "Keys" page. NEVER ship the secret inside the Flutter app — it
// must live only on this server.

const express = require('express');
const cors = require('cors');
const { AccessToken } = require('livekit-server-sdk');

const API_KEY    = process.env.LIVEKIT_API_KEY    || 'devkey';
const API_SECRET = process.env.LIVEKIT_API_SECRET || 'secret';
const PORT       = process.env.PORT || 5000;

const app = express();
app.use(cors()); // required so the Flutter web build can call this from a browser

app.get('/token', async (req, res) => {
  try {
    const room     = String(req.query.room     || '').trim();
    const identity = String(req.query.identity || '').trim();
    const name     = String(req.query.name     || 'Guest').trim();
    const canPublish = String(req.query.canPublish || 'true') === 'true';

    if (!room || !identity) {
      return res.status(400).json({ error: 'room and identity are required' });
    }

    const at = new AccessToken(API_KEY, API_SECRET, { identity, name });
    at.addGrant({
      room,
      roomJoin: true,
      canPublish,          // mic + screen share
      canPublishData: true,
      canSubscribe: true,
    });

    // v2 of the SDK returns a Promise from toJwt()
    const token = await at.toJwt();
    res.json({ token });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: String(e) });
  }
});

app.get('/', (_req, res) => res.send('SIMUL token server OK'));

app.listen(PORT, () => console.log(`Token server on http://localhost:${PORT}`));
