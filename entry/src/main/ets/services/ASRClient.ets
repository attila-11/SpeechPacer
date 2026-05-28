import { audio } from '@kit.AudioKit';
import webSocket from '@ohos.net.webSocket';
import { BusinessError } from '@kit.BasicServicesKit';
import { ASR_BACKEND_URL } from './BackendConfig';
export interface TranscriptionSegment {
  text: string;
  isFinal: boolean;
  timestamp: number;
}

export interface AsrListener {
  onPartialResult(segment: TranscriptionSegment): void;
  onFinalResult(fullText: string): void;
  onError(error: string): void;
}

interface DeepgramAlternative { transcript: string; }
interface DeepgramChannel { alternatives: DeepgramAlternative[]; }
interface DeepgramMessage { is_final: boolean; channel: DeepgramChannel; }

export class ASRClient {


  private audioCapturer?: audio.AudioCapturer;
  private ws?: webSocket.WebSocket;

  private isStarted: boolean = false;
  private isWsOpen: boolean = false;
  private startTime: number = 0;
  private stopPromise?: Promise<void>;
  private resolveStopPromise?: () => void;

  private accumulatedText: string = "";
  private currentUtterance: string = "";

  async init(): Promise<void> {
    // No Huawei engine to initialize anymore, but we keep this method
    // to maintain compatibility with your SessionController!
    return Promise.resolve();
  }

  async startSession(listener: AsrListener): Promise<void> {
    if (this.isStarted) return;

    try {
      this.isStarted = true;
      this.startTime = Date.now();
      this.accumulatedText = "";
      this.currentUtterance = "";
      this.isWsOpen = false;

      // 1. Start the audio microphone
      await this.initAudioCapturer();

      // 2. Connect to the local backend proxy
      this.initWebSocket(listener);

      await this.audioCapturer?.start();

      // 3. Start reading audio and throwing it to the WebSocket
      this.startAudioCaptureLoop(listener);

      console.info('SpeachPacer: ASR session started');
    } catch (err) {
      console.error(`SpeachPacer: Failed to start session: ${JSON.stringify(err)}`);
      listener.onError(JSON.stringify(err));
      this.isStarted = false;
    }
  }

  async stopSession(): Promise<void> {
    if (!this.isStarted) return;
    this.isStarted = false;

    try {
      await this.audioCapturer?.stop();
      await this.audioCapturer?.release();

      if (this.isWsOpen && this.ws) {
        this.stopPromise = new Promise<void>((resolve) => {
          this.resolveStopPromise = resolve;
        });

        // Ask the backend/Deepgram pipeline to flush any buffered audio, then close cleanly.
        await this.ws.send(JSON.stringify({ type: 'Finalize' }));
        await this.ws.send(JSON.stringify({ type: 'CloseStream' }));

        await Promise.race([
          this.stopPromise,
          new Promise<void>((resolve) => setTimeout(resolve, 1500))
        ]);
      }
      console.info('SpeachPacer: ASR session stopped');
    } catch (err) {
      console.error(`SpeachPacer: Error stopping session: ${JSON.stringify(err)}`);
    } finally {
      this.resolveStopPromise?.();
      this.resolveStopPromise = undefined;
      this.stopPromise = undefined;
    }
  }

  private initWebSocket(listener: AsrListener) {
    this.ws = webSocket.createWebSocket();

    const url = ASR_BACKEND_URL;

    this.ws.on('open', (err, value) => {
      console.info('SpeachPacer: Connected to backend');
      this.isWsOpen = true;
    });

    this.ws.on('message', (err, value) => {
      if (err) {
        console.error(`SpeachPacer: Message callback error ${JSON.stringify(err)}`);
        return;
      }
      if (!value) {
        return;
      }

      if (typeof value === 'string') {
        try {
          let data: DeepgramMessage = JSON.parse(value) as DeepgramMessage;
          let transcript = data.channel?.alternatives?.[0]?.transcript;
          if (transcript !== undefined && transcript !== "") {
            transcript = transcript.trim();
            if (transcript.length === 0) {
              return;
            }

            if (data.is_final) {
              this.accumulatedText += transcript + " ";
              this.currentUtterance = "";
            } else {
              this.currentUtterance = transcript;
            }

            const fullTextSoFar = (this.accumulatedText + this.currentUtterance).trim();

            listener.onPartialResult({
              text: fullTextSoFar,
              isFinal: data.is_final,
              timestamp: Date.now() - this.startTime
            });
          }
        } catch (e) {
          console.error(`SpeachPacer: Failed to parse backend response raw=${value}`);
        }
      }
    });

    this.ws.on('close', (err, value) => {
      console.info('SpeachPacer: Backend connection closed');
      this.isWsOpen = false;
      const final = (this.accumulatedText + this.currentUtterance).trim();
      if (final.length > 0) {
        listener.onFinalResult(final);
      }
      this.resolveStopPromise?.();
    });

    this.ws.on('error', (err) => {
      console.error(`SpeachPacer: Backend WebSocket Error: ${JSON.stringify(err)}`);
    });

    this.ws.connect(url, (err, value) => {
      if (err) {
        console.error(`SpeachPacer: Connect Error: ${JSON.stringify(err)}`);
      }
    });
  }

  private async initAudioCapturer() {
    let audioConfig: audio.AudioCapturerOptions = {
      streamInfo: {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      },
      capturerInfo: {
        source: audio.SourceType.SOURCE_TYPE_MIC,
        capturerFlags: 0
      }
    };

    this.audioCapturer = await audio.createAudioCapturer(audioConfig);
  }

  private async startAudioCaptureLoop(listener: AsrListener) {
    while (this.isStarted && this.audioCapturer) {
      try {
        let bufferSize = await this.audioCapturer.getBufferSize();
        let buffer = await this.audioCapturer.read(bufferSize, true);

        // If Deepgram is ready, instantly stream the audio buffer.
        if (buffer && this.isWsOpen && this.ws) {
          await this.ws.send(buffer);
        }
      } catch (e) {
        console.error(`SpeachPacer: Audio Loop Error: ${JSON.stringify(e)}`);
        await new Promise<void>(resolve => setTimeout(resolve, 20));
      }
    }
  }
}
