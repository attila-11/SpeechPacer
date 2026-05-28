import { router } from '@kit.ArkUI';
import { SessionSummary } from '../data/TranscriptStore';
import { PostSessionAnalysis } from '../core/PostProcessingAnalyzer';

@Entry
@Component
struct ResultScreen {
  @State summary: SessionSummary = { id: '', startTime: 0, endTime: 0, durationMs: 0, avgWpm: 0, transcript: '', wpmHistory: [], tokenList: [] };
  @State analysis: PostSessionAnalysis = { effectiveSpeakingTimeMs: 0, pauseTimeMs: 0, fillerWordCount: 0, fillerDensity: 0, topFillerWords: [], repetitivePhrases: [], recommendations: [] };

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    if (params && params.summaryJson && params.analysisJson) {
      this.summary = JSON.parse(params.summaryJson) as SessionSummary;
      this.analysis = JSON.parse(params.analysisJson) as PostSessionAnalysis;
    }
  }

  formatTime(ms: number): string {
    const totalSeconds = Math.floor(ms / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes}m ${seconds}s`;
  }

  drawGraph() {
    const history = this.summary.wpmHistory;
    if (!history || history.length < 2) return;

    const width = this.context.width;
    const height = this.context.height;

    this.context.clearRect(0, 0, width, height);
    this.context.lineWidth = 4;
    this.context.lineCap = 'round';
    this.context.lineJoin = 'round';

    const maxWpm = Math.max(200, ...history);
    const xStep = width / (history.length - 1);

    for (let i = 1; i < history.length; i++) {
      const wpm1 = history[i - 1];
      const wpm2 = history[i];

      const x1 = (i - 1) * xStep;
      const y1 = height - ((wpm1 / maxWpm) * height);
      const x2 = i * xStep;
      const y2 = height - ((wpm2 / maxWpm) * height);

      this.context.beginPath();
      this.context.moveTo(x1, y1);
      this.context.lineTo(x2, y2);

      if (wpm2 > 160) {
        this.context.strokeStyle = '#FF4444';
      } else if (wpm2 < 105 && wpm2 > 0) {
        this.context.strokeStyle = '#4488FF';
      } else {
        this.context.strokeStyle = '#44FF44';
      }

      this.context.stroke();
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column() {
          Text('Talk Summary')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .margin({ top: 30, bottom: 20 })

          Row() {
            Column() {
              Text(Math.round(this.summary.avgWpm).toString())
                .fontSize(24).fontColor('#007DFF').fontWeight(FontWeight.Bold)
              Text('Avg WPM')
                .fontSize(12).fontColor('#CCCCCC')
            }.layoutWeight(1)

            Column() {
              Text(this.formatTime(this.summary.durationMs))
                .fontSize(24).fontColor('#007DFF').fontWeight(FontWeight.Bold)
              Text('Duration')
                .fontSize(12).fontColor('#CCCCCC')
            }.layoutWeight(1)
          }
          .width('100%')
          .margin({ bottom: 20 })

          Text('Pacing History')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .margin({ bottom: 10 })

          Canvas(this.context)
            .width('90%')
            .height(80)
            .backgroundColor('#111111')
            .borderRadius(10)
            .onReady(() => {
              this.drawGraph();
            })
            .margin({ bottom: 25 })

          Text('Coaching Tips')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ bottom: 10 })

          ForEach(this.analysis.recommendations, (rec: string) => {
            Text('* ' + rec)
              .fontSize(13)
              .fontColor(Color.White)
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ bottom: 8 })
          })

          Text(`Filler Words Detected: ${this.analysis.fillerWordCount}`)
            .fontSize(12)
            .fontColor('#AAAAAA')
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ top: 10, bottom: 80 })
        }
        .width('100%')
        .padding({ left: 15, right: 15 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)

      Button('Done')
        .type(ButtonType.Capsule)
        .backgroundColor('#444444')
        .width('50%')
        .height(40)
        .margin({ bottom: 15 })
        .onClick(() => {
          router.clear();
          router.replaceUrl({ url: 'pages/Index' });
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }
}
