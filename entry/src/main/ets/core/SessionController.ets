import { ASRClient, AsrListener, TranscriptionSegment } from '../services/ASRClient';
import { PacingEngine, PacingListener, PacingMetrics, PacingState } from './PacingEngine';
import { HapticsController } from '../services/HapticsController';
import { TranscriptStore, SessionSummary } from '../data/TranscriptStore';
import { PostProcessingAnalyzer, PostSessionAnalysis } from './PostProcessingAnalyzer';

export interface SessionUIListener {
  onTimerUpdate(elapsedMs: number): void;
  onMetricsUpdate(metrics: PacingMetrics): void;
  onSessionEnded(summary: SessionSummary, analysis: PostSessionAnalysis): void;
  onError(message: string): void;
}

export class SessionController implements AsrListener, PacingListener {
  private asrClient: ASRClient;
  private pacingEngine: PacingEngine;
  private hapticsController: HapticsController;
  private transcriptStore: TranscriptStore;
  private analyzer: PostProcessingAnalyzer;

  private uiListener?: SessionUIListener;
  private timerId?: number;
  private startTime: number = 0;
  private lastAvgWpm: number = 0;
  private stopPromise?: Promise<void>;

  constructor() {
    this.asrClient = new ASRClient();
    this.pacingEngine = new PacingEngine();
    this.hapticsController = new HapticsController();
    this.transcriptStore = new TranscriptStore();
    this.analyzer = new PostProcessingAnalyzer();

    this.pacingEngine.setListener(this);
  }

  setUIListener(listener: SessionUIListener) {
    this.uiListener = listener;
  }

  async startSession(): Promise<void> {
    try {
      await this.asrClient.init();
      this.transcriptStore.startSession();
      this.pacingEngine.reset();
      this.hapticsController.setSessionActive(true);

      this.startTime = Date.now();
      this.startTimer();

      await this.asrClient.startSession(this);
    } catch (err) {
      this.uiListener?.onError('Failed to start session: ' + err);
    }
  }

  async stopSession(): Promise<void> {
    if (this.stopPromise) {
      return this.stopPromise;
    }

    this.stopPromise = this.stopSessionInternal();
    try {
      await this.stopPromise;
    } finally {
      this.stopPromise = undefined;
    }
  }

  private async stopSessionInternal(): Promise<void> {
    this.stopTimer();

    try {
      await this.asrClient.stopSession();
    } catch (e) {
      console.error('SpeachPacer: Ignored error closing ASR ' + JSON.stringify(e));
    }

    this.hapticsController.setSessionActive(false);
    await this.hapticsController.stop();

    // Recompute once after ASR shutdown so any last transcript flushed on close
    // is reflected in the stored WPM history before finalization.
    this.pacingEngine.tick(Date.now());

    const summary = this.transcriptStore.finalizeSession(this.lastAvgWpm);
    const analysis = this.analyzer.analyze(summary);

    this.uiListener?.onSessionEnded(summary, analysis);
  }

  onPartialResult(segment: TranscriptionSegment): void {
    this.transcriptStore.appendSegment(segment);
    this.pacingEngine.processSegment(segment);
  }

  onFinalResult(fullText: string): void {
    const finalSegment: TranscriptionSegment = {
      text: fullText,
      isFinal: true,
      timestamp: Date.now() - this.startTime
    };

    this.transcriptStore.appendSegment(finalSegment);
    this.pacingEngine.processSegment(finalSegment);
  }

  onError(error: string): void {
    this.uiListener?.onError(error);
  }

  onMetricsUpdated(metrics: PacingMetrics): void {
    this.lastAvgWpm = metrics.currentWpm;
    this.uiListener?.onMetricsUpdate(metrics);
    this.hapticsController.processCurrentState(metrics.pacingState);

    // Feed the live WPM into our historical graph record
    this.transcriptStore.recordWpm(metrics.currentWpm);
  }

  private startTimer() {
    this.timerId = setInterval(() => {
      const now = Date.now();
      const elapsed = now - this.startTime;

      this.pacingEngine.tick(now);
      this.uiListener?.onTimerUpdate(elapsed);
    }, 1000);
  }

  private stopTimer() {
    if (this.timerId) {
      clearInterval(this.timerId);
      this.timerId = undefined;
    }
  }
}
