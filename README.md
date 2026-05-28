# SpeechPacer

SpeechPacer is a HarmonyOS wearable app for live public-speaking feedback. It records microphone audio on a smartwatch, streams low-latency PCM audio through a small Python WebSocket proxy, receives live Deepgram transcripts, and turns the transcript stream into pacing guidance, haptic nudges, and a post-session summary.

## Features

- Live speech capture from a HarmonyOS wearable microphone
- 16 kHz mono Linear16 PCM audio streaming over WebSocket
- Python proxy that keeps Deepgram credentials off the watch
- Rolling WPM analysis using a 15-word window
- Pause-aware pacing math with a 1.2 second gap cap
- Schmitt-trigger pacing state transitions to avoid visual and haptic flicker
- Haptic feedback when the user moves into too-fast or too-slow pacing bands
- On-device post-session summary with average WPM, pacing history, filler words, and coaching tips

## Architecture

```text
HarmonyOS watch
  -> Python WebSocket proxy
  -> Deepgram streaming API
  -> Python WebSocket proxy
  -> HarmonyOS watch pacing engine and UI
```

The wearable app never stores the Deepgram API key. The key is read by the backend proxy from environment variables and injected only into the proxy-to-Deepgram connection.

## Repository Layout

```text
AppScope/                         App-level HarmonyOS metadata and icon resources
backend/                          Python Deepgram proxy
entry/src/main/ets/core/          Pacing, session, and post-processing logic
entry/src/main/ets/data/          Transcript and session summary storage
entry/src/main/ets/pages/         Watch UI pages
entry/src/main/ets/services/      Audio, WebSocket, backend config, and haptics
entry/src/main/resources/         HarmonyOS module resources
PROJECT_ARCHITECTURE.md           More detailed implementation notes
```

## Requirements

- Huawei DevEco Studio
- HarmonyOS wearable SDK compatible with the project target in `build-profile.json5`
- Python 3.10 or newer for the backend proxy
- A Deepgram API key

## Backend Setup

Create a virtual environment and install the proxy dependency:

```powershell
python -m venv .venv
.\.venv\Scripts\pip install -r backend\requirements.txt
```

Create `backend/.env` from `backend/.env.example`, or set the same variables in your shell:

```powershell
$env:DEEPGRAM_API_KEY="your_deepgram_api_key"
$env:HOST="0.0.0.0"
$env:PORT="8765"
```

Start the proxy:

```powershell
.\.venv\Scripts\python backend\proxy_server.py
```

The proxy exposes:

- `GET /health` for a basic health check
- `ws://<host>:<port>/listen` for watch audio streaming

For a hosted deployment, run the same Python proxy behind a trusted TLS endpoint and configure the app with your own `wss://.../listen` URL.

## Watch App Configuration

Set the backend endpoint in:

```text
entry/src/main/ets/services/BackendConfig.ets
```

Defaults:

- Emulator on the same machine: `ws://127.0.0.1:8765/listen`
- Physical watch: replace the host with a reachable LAN address or a hosted `wss://` proxy URL

## Build Notes

Open the project in DevEco Studio and let the IDE resolve the HarmonyOS toolchain. Public signing credentials are intentionally not included. Configure your own signing material locally before building a signed release package.

The app declares these permissions in `entry/src/main/module.json5`:

- `ohos.permission.MICROPHONE`
- `ohos.permission.INTERNET`
- `ohos.permission.VIBRATE`

## Security Notes

- Do not commit real `.env` files, Deepgram keys, signing certificates, signing passwords, or local SDK paths.
- `backend/.env.example` is only a placeholder template.
- `build-profile.json5` omits signing credentials on purpose for public source release.
- Use `wss://` for hosted or production deployments.

## Current Limitations

- ASR depends on Deepgram and the Python proxy; there is no offline transcription path.
- The backend URL is a compile-time constant in `BackendConfig.ets`.
- Post-session analytics are intentionally lightweight and run locally on the watch.
- A license file has not been added yet; add one before inviting outside reuse or contributions.
