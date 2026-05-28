import { UIAbility, abilityAccessCtrl, common, Permissions, Want, AbilityConstant } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

export default class EntryAbility extends UIAbility {

  // 1. Define the function to request the microphone permission
  async requestMicrophonePermission() {
    let atManager = abilityAccessCtrl.createAtManager();
    let context: common.UIAbilityContext = this.context;

    // The exact string matching what you put in module.json5
    const permissions: Permissions[] = ['ohos.permission.MICROPHONE'];

    try {
      // This triggers the system pop-up dialogue
      let result = await atManager.requestPermissionsFromUser(context, permissions);

      // 0 means granted, -1 means denied
      if (result.authResults[0] === 0) {
        hilog.info(0x0000, 'SpeachPacer', 'Microphone permission granted successfully.');
      } else {
        hilog.error(0x0000, 'SpeachPacer', 'Microphone permission denied by user.');
      }
    } catch (err) {
      hilog.error(0x0000, 'SpeachPacer', `Failed to request permission. Code: ${err?.code}, message: ${err?.message}`);
    }
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'SpeachPacer', '%{public}s', 'Ability onCreate');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, 'SpeachPacer', '%{public}s', 'Ability onWindowStageCreate');

    // 2. Call the permission request as soon as the window stage is created
    this.requestMicrophonePermission();

    // 3. Load the main UI page
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'SpeachPacer', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(0x0000, 'SpeachPacer', 'Succeeded in loading the content.');
    });
  }

  onForeground(): void {
    hilog.info(0x0000, 'SpeachPacer', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(0x0000, 'SpeachPacer', '%{public}s', 'Ability onBackground');
  }

  onDestroy(): void {
    hilog.info(0x0000, 'SpeachPacer', '%{public}s', 'Ability onDestroy');
  }
}