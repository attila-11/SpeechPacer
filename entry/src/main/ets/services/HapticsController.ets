import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { PacingState } from '../core/PacingEngine';

export class HapticsController {
  private lastState: PacingState = PacingState.OK;
  private isSessionActive: boolean = false;

  setSessionActive(active: boolean) {
    this.isSessionActive = active;
  }

  async processCurrentState(state: PacingState): Promise<void> {
    if (!this.isSessionActive) return;

    // ONLY trigger if the state has actually changed. No repeating nags.
    if (state !== this.lastState) {
      this.lastState = state;

      if (state === PacingState.TOO_FAST) {
        await this.hapticTap(1);
      } else if (state === PacingState.TOO_SLOW) {
        await this.hapticTap(2);
      }
    }
  }

  private async hapticTap(pulseCount: number): Promise<void> {
    try {
      // 80ms creates a sharp, professional "tap" rather than an annoying "buzz"
      if (pulseCount === 1) {
        await this.startVibration(80);
      } else if (pulseCount === 2) {
        await this.startVibration(80);
        await new Promise<void>((resolve) => { setTimeout(resolve, 200); });
        await this.stop();
        await this.startVibration(80);
      }
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      console.error(`SpeachPacer: Vibration failed. Code: ${e.code}`);
    }
  }

  private startVibration(duration: number): Promise<void> {
    return new Promise((resolve, reject) => {
      try {
        vibrator.startVibration({
          type: 'time',
          duration: duration,
        }, {
          id: 0,
          usage: 'touch' // Changed from 'alarm' to 'touch' for a cleaner haptic feel
        }, (error: BusinessError) => {
          if (error) { reject(error); } else { resolve(); }
        });
      } catch (err) {
        reject(err);
      }
    });
  }

  async stop(): Promise<void> {
    try {
      await vibrator.stopVibration();
    } catch (err) {}
  }
}