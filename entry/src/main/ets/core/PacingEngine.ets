import { TranscriptionSegment } from '../services/ASRClient';

export enum PacingState {
  TOO_SLOW = 'TOO_SLOW',
  OK = 'OK',
  TOO_FAST = 'TOO_FAST'
}

export interface PacingMetrics {
  currentWpm: number;
  pacingState: PacingState;
}

export interface PacingListener {
  onMetricsUpdated(metrics: PacingMetrics): void;
}

export class PacingEngine {
  // We analyze the last 15 words (roughly one full sentence)
  private readonly WORD_WINDOW = 15;
  private readonly IDLE_RESET_MS = 2000;

  // Any gap between words longer than 1.2s is considered a "breath/pause",
  // not "slow talking", and is ignored in the math!
  private readonly MAX_GAP_MS = 1200;

  // Tuned thresholds for a comfortable, professional speaking pace
  private readonly FAST_UPPER = 160;
  private readonly FAST_LOWER = 150;
  private readonly SLOW_LOWER = 95;  // Adjusted for natural dramatic pauses
  private readonly SLOW_UPPER = 105;

  private wordTimestamps: number[] = [];
  private lastWordTime: number = 0;
  private totalWordsRecognized: number = 0;

  private currentWpm: number = 0;
  private currentState: PacingState = PacingState.OK;
  private listener?: PacingListener;

  setListener(listener: PacingListener) {
    this.listener = listener;
  }

  processSegment(segment: TranscriptionSegment) {
    const words = segment.text.trim().split(/\s+/).filter(word => word.length > 0);
    const currentWordCount = words.length;

    if (currentWordCount > this.totalWordsRecognized) {
      const newWordsCount = currentWordCount - this.totalWordsRecognized;
      const now = Date.now();
      const baselineTime = this.lastWordTime > 0
        ? this.lastWordTime
        : now - (newWordsCount * 400);
      const elapsedMs = Math.max(now - baselineTime, newWordsCount * 180);
      const timePerWord = elapsedMs / newWordsCount;

      for (let i = 0; i < newWordsCount; i++) {
        this.wordTimestamps.push(baselineTime + (timePerWord * (i + 1)));
      }

      if (this.wordTimestamps.length > this.WORD_WINDOW) {
        this.wordTimestamps = this.wordTimestamps.slice(this.wordTimestamps.length - this.WORD_WINDOW);
      }

      this.totalWordsRecognized = currentWordCount;
      this.lastWordTime = now;
    }
  }

  tick(now: number) {
    if (this.lastWordTime > 0 && now - this.lastWordTime > this.IDLE_RESET_MS) {
      this.wordTimestamps = [];
      this.lastWordTime = 0;
      this.currentWpm = 0;
      this.currentState = PacingState.OK;
      this.listener?.onMetricsUpdated({
        currentWpm: 0,
        pacingState: this.currentState
      });
      return;
    }

    // Only calculate if we have a sensible number of words (at least 5)
    if (this.wordTimestamps.length >= 5) {
      let effectiveElapsedMs = 0;

      // Calculate the time it took to speak these words, explicitly capping pauses
      for (let i = 1; i < this.wordTimestamps.length; i++) {
        const gap = this.wordTimestamps[i] - this.wordTimestamps[i - 1];
        effectiveElapsedMs += Math.min(gap, this.MAX_GAP_MS);
      }

      // Prevent division by zero or infinite spikes
      effectiveElapsedMs = Math.max(effectiveElapsedMs, 1000);

      this.currentWpm = (this.wordTimestamps.length / effectiveElapsedMs) * 60000;
    }

    // Schmitt Trigger State Logic
    switch (this.currentState) {
      case PacingState.TOO_FAST:
        if (this.currentWpm <= this.SLOW_LOWER && this.currentWpm > 0) {
          this.currentState = PacingState.TOO_SLOW;
        } else if (this.currentWpm < this.FAST_LOWER) {
          this.currentState = PacingState.OK;
        }
        break;
      case PacingState.TOO_SLOW:
        if (this.currentWpm >= this.FAST_UPPER) {
          this.currentState = PacingState.TOO_FAST;
        } else if (this.currentWpm > this.SLOW_UPPER) {
          this.currentState = PacingState.OK;
        }
        break;
      case PacingState.OK:
      default:
        if (this.currentWpm >= this.FAST_UPPER) {
          this.currentState = PacingState.TOO_FAST;
        } else if (this.currentWpm > 0 && this.currentWpm <= this.SLOW_LOWER) {
          this.currentState = PacingState.TOO_SLOW;
        }
        break;
    }

    this.listener?.onMetricsUpdated({
      currentWpm: Math.round(this.currentWpm),
      pacingState: this.currentState
    });
  }

  reset() {
    this.wordTimestamps = [];
    this.lastWordTime = 0;
    this.totalWordsRecognized = 0;
    this.currentWpm = 0;
    this.currentState = PacingState.OK;
  }
}
