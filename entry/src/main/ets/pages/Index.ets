import { router } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  @State message: string = 'Ready to Speak?';

  build() {
    Column() {
      // App Title/Logo area
      Column() {
        Text('SpeechPacer')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .margin({ top: 40 })

        Text('Pace your talk, perfect your delivery')
          .fontSize(12)
          .fontColor('#CCCCCC')
          .margin({ top: 4 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      Blank()

      // Main action button
      Button('Start Session')
        .type(ButtonType.Capsule)
        .backgroundColor('#007DFF')
        .width('80%')
        .height(50)
        .margin({ bottom: 40 })
        .onClick(() => {
          console.info('SpeechPacer: Navigating to LiveSession');
          router.pushUrl({
            url: 'pages/LiveSession'
          });
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .padding(10)
  }
}