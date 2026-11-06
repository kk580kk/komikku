import { http } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
import { AppContext } from './AppContext';
import { Page } from '../source/Source';
import { DownloadRepository } from '../data/DownloadRepository';
import { AppError, fail, ok, Result } from '../util/Result';
import { Logger } from '../util/Logger';

/** 下载进度回调：(已完成页数, 总页数)。 */
export type DownloadProgress = (done: number, total: number) => void;

/**
 * 章节下载器。
 *
 * 文件落盘：`filesDir/downloads/<mangaId>/<chapterId>/<index>.img`
 * - filesDir 是应用私有持久目录，卸载才清
 * - 已存在的页直接跳过，所以重跑=断点续传
 * - 状态写 downloads 表，供阅读器判断走本地还是网络
 */
export class Downloader {
  private static instance: Downloader | undefined = undefined;
  private repo: DownloadRepository = new DownloadRepository();
  private running: boolean = false;

  static get(): Downloader {
    if (Downloader.instance === undefined) {
      Downloader.instance = new Downloader();
    }
    return Downloader.instance;
  }

  isRunning(): boolean {
    return this.running;
  }

  chapterDir(mangaId: number, chapterId: number): string {
    return AppContext.require().filesDir + '/downloads/' + mangaId + '/' + chapterId;
  }

  /** 已存在的本地页（按 index 升序）；不完整时返回空数组，调用方回退网络。 */
  localPages(mangaId: number, chapterId: number, total: number): string[] {
    const dir: string = this.chapterDir(mangaId, chapterId);
    const paths: string[] = [];
    for (let i = 0; i < total; i++) {
      const path: string = dir + '/' + i + '.img';
      if (fileIo.accessSync(path)) {
        paths.push(path);
      } else {
        return [];
      }
    }
    return paths;
  }

  async downloadChapter(
    mangaId: number,
    chapterId: number,
    pages: Page[],
    onProgress: DownloadProgress | undefined = undefined
  ): Promise<Result<void>> {
    if (pages.length === 0) {
      return fail<void>(AppError.parse('该章节没有可下载的页面'));
    }
    if (this.running) {
      return fail<void>(AppError.network('已有下载任务在进行'));
    }
    this.running = true;
    try {
      const dir: string = this.chapterDir(mangaId, chapterId);
      if (!fileIo.accessSync(dir)) {
        fileIo.mkdirSync(dir, true);
      }
      await this.repo.enqueue(chapterId, mangaId, pages.length);
      let done: number = 0;
      for (const page of pages) {
        const path: string = dir + '/' + page.index + '.img';
        if (!fileIo.accessSync(path)) {
          const bytes: Result<ArrayBuffer> = await this.fetch(page.imageUrl);
          if (!bytes.ok || bytes.data === undefined) {
            await this.repo.markError(chapterId);
            return fail<void>(bytes.error ?? AppError.network('下载失败'));
          }
          this.writeFile(path, bytes.data);
        }
        done++;
        await this.repo.updateProgress(chapterId, done, pages.length);
        if (onProgress !== undefined) {
          onProgress(done, pages.length);
        }
      }
      await this.repo.markDone(chapterId, pages.length);
      Logger.info('download', 'chapter %{public}d done, pages=%{public}d', chapterId, pages.length);
      return ok<void>(undefined);
    } catch (e) {
      Logger.error('download', 'downloadChapter failed: %{public}s', JSON.stringify(e));
      await this.repo.markError(chapterId);
      return fail<void>(AppError.storage('下载失败'));
    } finally {
      this.running = false;
    }
  }

  private async fetch(url: string): Promise<Result<ArrayBuffer>> {
    const req: http.HttpRequest = http.createHttp();
    try {
      const header: Record<string, string> = { 'User-Agent': 'Komikku/0.1.0 (HarmonyOS)' };
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: header,
        connectTimeout: 15000,
        readTimeout: 30000,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      };
      const resp: http.HttpResponse = await req.request(url, options);
      if (resp.responseCode < 200 || resp.responseCode >= 300) {
        return fail<ArrayBuffer>(AppError.network('下载返回 HTTP ' + resp.responseCode));
      }
      const raw = resp.result;
      if (!(raw instanceof ArrayBuffer)) {
        return fail<ArrayBuffer>(AppError.parse('下载内容不是二进制'));
      }
      return ok<ArrayBuffer>(raw);
    } catch (e) {
      Logger.warn('download', 'fetch failed: %{public}s', JSON.stringify(e));
      return fail<ArrayBuffer>(AppError.network('网络请求失败'));
    } finally {
      req.destroy();
    }
  }

  private writeFile(path: string, buf: ArrayBuffer): void {
    const file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, buf);
    } finally {
      fileIo.closeSync(file);
    }
  }

  /** 删除某章已下载的文件（数据库记录由调用方处理）。 */
  removeChapterFiles(mangaId: number, chapterId: number): void {
    const dir: string = this.chapterDir(mangaId, chapterId);
    try {
      if (fileIo.accessSync(dir)) {
        fileIo.rmdirSync(dir);
      }
    } catch (e) {
      Logger.warn('download', 'remove files failed: %{public}s', JSON.stringify(e));
    }
  }
}
