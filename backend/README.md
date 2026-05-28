# Deepgram Proxy

This backend receives watch audio over WebSocket, opens an authenticated streaming connection to Deepgram, and relays transcript messages back to the watch.

## What It Does

- Accepts a WebSocket connection from the watch app at `/listen`
- Forwards Linear16 PCM audio to Deepgram
- Relays Deepgram transcript messages back to the watch unchanged
- Keeps the Deepgram API key outside of the watch app

You can run it locally during development or deploy it behind a trusted TLS endpoint for physical-device testing.

## Setup

1. Create a virtual environment.
2. Install dependencies:

```powershell
python -m venv .venv
.\.venv\Scripts\pip install -r backend\requirements.txt
```

3. Copy `backend/.env.example` to `backend/.env` or set environment variables:

```powershell
$env:DEEPGRAM_API_KEY="your_deepgram_api_key"
$env:HOST="0.0.0.0"
$env:PORT="8765"
```

4. Start the proxy:

```powershell
.\.venv\Scripts\python backend\proxy_server.py
```

## App Configuration

Set the watch app backend URL in `entry/src/main/ets/services/BackendConfig.ets`.

- Emulator on same machine: `ws://127.0.0.1:8765/listen`
- Physical watch on local network: `ws://<YOUR_COMPUTER_LAN_IP>:8765/listen`
- Hosted proxy: `wss://<YOUR_PROXY_HOST>/listen`

Your computer and watch must be on the same network for the physical watch setup.

## Public Source Safety

- Do not commit `backend/.env`.
- Do not put a real API key in `backend/.env.example`.
- Rotate any key that has ever been committed or shared.
