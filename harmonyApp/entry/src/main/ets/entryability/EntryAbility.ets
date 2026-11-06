import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppContext } from '../service/AppContext';
import { Database } from '../data/Database';
import { Seed } from '../data/Seed';
import { Logger } from '../util/Logger';

const TAG: string = 'app';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    AppContext.set(this.context);
    Logger.info(TAG, 'ability onCreate');

    // 数据库在后台初始化，页面侧通过仓储懒等待同一个初始化 Promise。
    Database.init(this.context)
      .then((store) => Seed.ensure(store))
      .then(() => Logger.info(TAG, 'database ready'))
      .catch((err: Error) => Logger.error(TAG, 'database init failed: %{public}s', err.message));
  }

  onDestroy(): void {
    Logger.info(TAG, 'ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        Logger.error(TAG, 'load content failed: %{public}s', JSON.stringify(err));
        return;
      }
      Logger.info(TAG, 'content loaded');
    });
  }

  onWindowStageDestroy(): void {
    Logger.info(TAG, 'window stage destroyed');
  }

  onForeground(): void {
    Logger.info(TAG, 'ability onForeground');
  }

  onBackground(): void {
    Logger.info(TAG, 'ability onBackground');
  }
}
