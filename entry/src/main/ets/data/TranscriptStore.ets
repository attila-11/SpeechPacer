import { TranscriptionSegment } from '../services/ASRClient';

export interface SessionSummary {
  id: string;
  startTime: number;
  endTime: number;
  durationMs: number;
  avgWpm: number;
  transcript: string;
  wpmHistory: number[];
  // FIX: Explicitly type this as TranscriptionSegment[] instead of any[]
  tokenList: TranscriptionSegment[];
}

export class TranscriptStore {
  private startTime: number = 0;
  private currentText: string = "";
  private wpmHistory: number[] = [];
  private tokens: TranscriptionSegment[] = [];

  startSession() {
    this.startTime = Date.now();
    this.currentText = "";
    this.wpmHistory = [];
    this.tokens = [];
  }

  appendSegment(segment: TranscriptionSegment) {
    this.currentText = segment.text;
    this.tokens.push(segment);
  }

  recordWpm(wpm: number) {
    this.wpmHistory.push(wpm);
  }

  finalizeSession(lastAvgWpm: number): SessionSummary {
    // Calculate the true average WPM across the entire speech
    let finalAvgWpm = lastAvgWpm;
    if (this.wpmHistory.length > 0) {
      const activeWpms = this.wpmHistory.filter(w => w > 0);
      if (activeWpms.length > 0) {
        const sum = activeWpms.reduce((a, b) => a + b, 0);
        finalAvgWpm = sum / activeWpms.length;
      }
    }

    return {
      id: Date.now().toString(),
      startTime: this.startTime,
      endTime: Date.now(),
      durationMs: Date.now() - this.startTime,
      avgWpm: finalAvgWpm,
      transcript: this.currentText,
      wpmHistory: this.wpmHistory,
      tokenList: this.tokens
    };
  }
}