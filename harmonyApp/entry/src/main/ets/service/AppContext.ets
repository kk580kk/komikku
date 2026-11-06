import { common } from '@kit.AbilityKit';

/**
 * 应用级 Context 持有者。
 *
 * 在 `EntryAbility.onCreate` 注入一次，供数据层懒初始化 RDB 使用；
 * 页面/组件不直接传 Context 给仓储，避免把 Ability 上下文泄露到 UI 层。
 */
export class AppContext {
  private static context: common.Context | undefined = undefined;

  static set(context: common.Context): void {
    AppContext.context = context;
  }

  static require(): common.Context {
    if (AppContext.context === undefined) {
      throw new Error('AppContext 未初始化：请在 EntryAbility.onCreate 中调用 AppContext.set(this.context)');
    }
    return AppContext.context;
  }
}
