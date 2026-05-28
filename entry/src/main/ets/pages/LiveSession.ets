import { router } from '@kit.ArkUI';
import { SessionController, SessionUIListener } from '../core/SessionController';
import { PacingMetrics, PacingState } from '../core/PacingEngine';
import { SessionSummary } from '../data/TranscriptStore';
import { PostSessionAnalysis } from '../core/PostProcessingAnalyzer';

class SessionUIListenerImpl implements SessionUIListener {
  private onTimerUpdateCallback: (elapsed: number) => void;
  private onMetricsUpdateCallback: (metrics: PacingMetrics) => void;
  private onSessionEndedCallback: (summary: SessionSummary, analysis: PostSessionAnalysis) => void;
  private onErrorCallback: (message: string) => void;

  constructor(onTimer: (e: number) => void, onMetrics: (m: PacingMetrics) => void, onEnded: (s: SessionSummary, a: PostSessionAnalysis) => void, onError: (msg: string) => void) {
    this.onTimerUpdateCallback = onTimer;
    this.onMetricsUpdateCallback = onMetrics;
    this.onSessionEndedCallback = onEnded;
    this.onErrorCallback = onError;
  }
  onTimerUpdate(elapsedMs: number): void { this.onTimerUpdateCallback(elapsedMs); }
  onMetricsUpdate(metrics: PacingMetrics): void { this.onMetricsUpdateCallback(metrics); }
  onSessionEnded(summary: SessionSummary, analysis: PostSessionAnalysis): void { this.onSessionEndedCallback(summary, analysis); }
  onError(message: string): void { this.onErrorCallback(message); }
}

@Entry
@Component
struct LiveSession {
  private controller: SessionController = new SessionController();

  @State elapsedMs: number = 0;
  @State metrics: PacingMetrics = {
    currentWpm: 0,
    pacingState: PacingState.OK
  };
  @State isEnding: boolean = false;

  aboutToAppear() {
    const uiListener = new SessionUIListenerImpl(
      (elapsed: number) => { this.elapsedMs = elapsed; },
      (metrics: PacingMetrics) => {
        this.metrics = {
          currentWpm: metrics.currentWpm,
          pacingState: metrics.pacingState
        };
      },
      (summary: SessionSummary, analysis: PostSessionAnalysis) => {
        router.replaceUrl({
          url: 'pages/ResultScreen',
          params: {
            summaryJson: JSON.stringify(summary),
            analysisJson: JSON.stringify(analysis)
          }
        });
      },
      (message: string) => { router.back(); }
    );

    this.controller.setUIListener(uiListener);
    this.controller.startSession();
  }

  aboutToDisappear() {
    void this.controller.stopSession();
  }

  formatTime(ms: number): string {
    const totalSeconds = Math.floor(ms / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
  }

  getBackgroundColor(): string {
    switch (this.metrics.pacingState) {
      case PacingState.TOO_FAST: return '#3B1212';
      case PacingState.TOO_SLOW: return '#12223B';
      default: return '#123B1A';
    }
  }

  getPacingLabel(): string {
    switch (this.metrics.pacingState) {
      case PacingState.TOO_FAST: return 'SLOW DOWN';
      case PacingState.TOO_SLOW: return 'SPEED UP';
      default: return 'GOOD PACE';
    }
  }

  build() {
    Column() {
      Text(this.formatTime(this.elapsedMs))
        .fontSize(26)
        .fontWeight(FontWeight.Bolder)
        .fontColor(Color.White)
        .margin({ bottom: 20 })

      Text(this.getPacingLabel())
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .margin({ bottom: 5 })

      Blank().height(44) // Keeps layout steady where the PAUSED text used to be

      Button('Stop')
        .type(ButtonType.Circle)
        .backgroundColor('#222222')
        .width(55)
        .height(55)
        .onClick(() => {
          if (this.isEnding) return;
          this.isEnding = true;
          void this.controller.stopSession();
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getBackgroundColor())
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .animation({ duration: 500, curve: Curve.EaseInOut })
  }
}
