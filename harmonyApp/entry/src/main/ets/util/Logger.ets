import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;

/**
 * 统一日志出口。禁止在业务代码里直接用 console.log。
 * 用法：Logger.info('source', 'fetch page=%{public}d', page)
 */
export class Logger {
  static debug(tag: string, format: string, ...args: Array<Object>): void {
    hilog.debug(DOMAIN, tag, format, args);
  }

  static info(tag: string, format: string, ...args: Array<Object>): void {
    hilog.info(DOMAIN, tag, format, args);
  }

  static warn(tag: string, format: string, ...args: Array<Object>): void {
    hilog.warn(DOMAIN, tag, format, args);
  }

  static error(tag: string, format: string, ...args: Array<Object>): void {
    hilog.error(DOMAIN, tag, format, args);
  }
}
