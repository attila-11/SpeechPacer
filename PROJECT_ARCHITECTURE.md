# SpeechPacer Project Architecture

## Overview

SpeechPacer is a HarmonyOS wearable app written in ArkTS and ArkUI. It captures microphone audio on a watch, streams raw PCM audio to a Python WebSocket proxy, receives Deepgram streaming transcripts, calculates live pacing state, provides haptic feedback, and renders a post-session summary.

This document describes the current source tree and runtime behavior.

## Platform and Stack

- Platform: HarmonyOS wearable
- Client language: ArkTS
- UI: ArkUI declarative components
- Audio capture: `@kit.AudioKit`
- Network streaming: `@ohos.net.webSocket`
- Haptics: `@kit.SensorServiceKit`
- Backend: Python `asyncio` and `websockets`
- ASR provider: Deepgram streaming API

## Runtime Flow

```text
HarmonyOS watch microphone
  -> ASRClient audio capturer
  -> WebSocket to Python proxy
  -> Authenticated WebSocket to Deepgram
  -> Transcript JSON back through proxy
  -> PacingEngine and TranscriptStore
  -> LiveSession UI and HapticsController
  -> ResultScreen summary and graph
```

1. `EntryAbility` requests microphone permission and loads `pages/Index`.
2. `Index` routes to `pages/LiveSession` when the user starts a session.
3. `LiveSession.aboutToAppear()` creates a `SessionController`, registers a UI listener, and starts the session.
4. `SessionController.startSession()` resets state, starts the timer, activates haptics, and starts the ASR client.
5. `ASRClient` opens the configured backend WebSocket, starts the microphone capturer, and streams raw audio buffers.
6. `backend/proxy_server.py` relays watch audio to Deepgram and relays transcript frames back to the watch.
7. `ASRClient` parses returned transcript JSON and emits `TranscriptionSegment` values.
8. `SessionController` sends segments to `TranscriptStore` and `PacingEngine`.
9. `PacingEngine.tick()` computes WPM and pacing state once per second.
10. `HapticsController` vibrates only when the pacing state changes.
11. On stop, `TranscriptStore.finalizeSession()` creates a `SessionSummary`, `PostProcessingAnalyzer` creates coaching tips, and `ResultScreen` displays the result.

## Source Layout

```text
entry/src/main/
  ets/
    core/
      PacingEngine.ets
      PostProcessingAnalyzer.ets
      SessionController.ets
    data/
      TranscriptStore.ets
    entryability/
      EntryAbility.ets
    entrybackupability/
      EntryBackupAbility.ets
    pages/
      Index.ets
      LiveSession.ets
      ResultScreen.ets
    services/
      ASRClient.ets
      BackendConfig.ets
      HapticsController.ets
  module.json5
  resources/
    base/
      element/
      media/
      profile/

backend/
  proxy_server.py
  README.md
  requirements.txt
  .env.example
```

## Core Components

### `ASRClient.ets`

Owns microphone capture and watch-to-backend WebSocket connectivity.

- Captures 16 kHz mono `S16LE` PCM audio.
- Streams each captured buffer to `ASR_BACKEND_URL`.
- Parses Deepgram-style transcript messages returned by the proxy.
- Tracks final transcript text plus the current interim utterance.
- Emits full transcript-so-far snapshots to the session controller.

The watch app does not contain a Deepgram API key.

### `BackendConfig.ets`

Contains the compile-time WebSocket endpoint used by the watch app. The public repository defaults to:

```text
ws://127.0.0.1:8765/listen
```

For a physical watch, replace the host with a LAN-reachable development machine or a hosted `wss://` proxy.

### `backend/proxy_server.py`

Bridges the watch and Deepgram.

- Accepts WebSocket connections on `/listen`.
- Serves `GET /` and `GET /health` as simple health checks.
- Reads `DEEPGRAM_API_KEY`, `HOST`, and `PORT` from the environment.
- Injects the Deepgram token into the server-side outbound connection.
- Relays audio and transcript frames without storing them.

### `SessionController.ets`

Orchestrates the live session.

- Starts and stops ASR, haptics, timers, transcript storage, and pacing analysis.
- Runs a one-second timer.
- Sends current metrics to the UI.
- Records WPM history for the result graph.
- Finalizes the session and routes summary data to the result screen.

### `PacingEngine.ets`

Turns transcript growth into current WPM and pacing state.

Key constants:

- Word window: `15`
- Idle reset: `2000 ms`
- Maximum counted silence gap: `1200 ms`
- Too fast threshold: enters at `160 WPM`, exits below `150 WPM`
- Too slow threshold: enters at `95 WPM`, exits above `105 WPM`

The engine waits until at least five words have been recognized before reporting non-zero WPM.

### `PostProcessingAnalyzer.ets`

Analyzes the final transcript after the session.

- Counts filler words: `um`, `uh`, `like`, `so`, `anyway`
- Applies a separate recommendation rule for repeated use of `basically`
- Detects repeated two-word and three-word phrases
- Generates lightweight coaching recommendations from average WPM and filler usage

### `TranscriptStore.ets`

Stores transcript snapshots, WPM history, and the final session summary. Average WPM is calculated from non-zero live WPM samples.

### `HapticsController.ets`

Vibrates only on pacing-state transitions:

- Single pulse for too fast
- Double pulse for too slow
- No pulse for steady good pace

### `LiveSession.ets`

Shows elapsed time and a pacing label. The background color changes by pacing state, and the raw WPM is intentionally hidden during the live session.

### `ResultScreen.ets`

Shows average WPM, session duration, pacing history, coaching tips, and detected filler word count. The pacing chart is drawn with `CanvasRenderingContext2D`.

## Permissions

`entry/src/main/module.json5` declares:

- `ohos.permission.MICROPHONE`
- `ohos.permission.INTERNET`
- `ohos.permission.VIBRATE`

`EntryAbility` requests microphone permission at runtime.

## Public Source Notes

- Deepgram credentials belong only in local environment variables.
- `backend/.env.example` must remain a placeholder file.
- Signing credentials are intentionally omitted from `build-profile.json5`.
- `local.properties`, `.env` files, signing material, build output, IDE metadata, and dependency folders are ignored.

## Known Implementation Notes

- The backend URL is a compile-time constant rather than a user-editable in-app setting.
- The proxy can run locally over `ws://` for emulator testing or behind `wss://` for physical and hosted deployments.
- The app currently routes back from `LiveSession` on ASR errors without showing detailed error text in the UI.
- The app bundle id remains the template-style `com.example.myapplication`; change it before publishing to an app store.
