import { relationalStore } from '@kit.ArkData';
import { AppError, fail, ok, Result } from '../util/Result';
import { Logger } from '../util/Logger';
import { Database } from './Database';
import { AppContext } from '../service/AppContext';

/** 下载状态机：排队 → 下载中 → 完成 / 失败。 */
export class DownloadStatus {
  static readonly QUEUED: number = 0;
  static readonly DOWNLOADING: number = 1;
  static readonly DONE: number = 2;
  static readonly ERROR: number = 3;
}

export class DownloadEntry {
  chapterId: number;
  mangaId: number;
  status: number;
  pagesTotal: number;
  pagesDone: number;
  createdAt: number;
  updatedAt: number;

  constructor(
    chapterId: number,
    mangaId: number,
    status: number,
    pagesTotal: number,
    pagesDone: number,
    createdAt: number,
    updatedAt: number
  ) {
    this.chapterId = chapterId;
    this.mangaId = mangaId;
    this.status = status;
    this.pagesTotal = pagesTotal;
    this.pagesDone = pagesDone;
    this.createdAt = createdAt;
    this.updatedAt = updatedAt;
  }
}

function mapRow(rs: relationalStore.ResultSet): DownloadEntry {
  return new DownloadEntry(
    rs.getLong(rs.getColumnIndex('chapter_id')),
    rs.getLong(rs.getColumnIndex('manga_id')),
    rs.getLong(rs.getColumnIndex('status')),
    rs.getLong(rs.getColumnIndex('pages_total')),
    rs.getLong(rs.getColumnIndex('pages_done')),
    rs.getLong(rs.getColumnIndex('created_at')),
    rs.getLong(rs.getColumnIndex('updated_at'))
  );
}

/** 下载记录仓储（文件本体在 Downloader 管理的沙箱目录里）。 */
export class DownloadRepository {
  async enqueue(chapterId: number, mangaId: number, pagesTotal: number): Promise<Result<void>> {
    try {
      const now: number = Date.now();
      await (await Database.init(AppContext.require())).executeSql(
        `INSERT INTO downloads (chapter_id, manga_id, status, pages_total, pages_done, created_at, updated_at)
         VALUES (?, ?, ?, ?, 0, ?, ?)
         ON CONFLICT(chapter_id) DO UPDATE SET status = excluded.status, pages_total = excluded.pages_total,
           updated_at = excluded.updated_at`,
        [chapterId, mangaId, DownloadStatus.QUEUED, pagesTotal, now, now]
      );
      return ok<void>(undefined);
    } catch (e) {
      Logger.error('data', 'enqueue download failed: %{public}s', JSON.stringify(e));
      return fail<void>(AppError.storage('加入下载队列失败'));
    }
  }

  async status(chapterId: number): Promise<Result<DownloadEntry>> {
    try {
      const rs: relationalStore.ResultSet = await (await Database.init(AppContext.require())).querySql(
        'SELECT * FROM downloads WHERE chapter_id = ? LIMIT 1',
        [chapterId]
      );
      let entry: DownloadEntry | undefined = undefined;
      if (rs.goToFirstRow()) {
        entry = mapRow(rs);
      }
      rs.close();
      if (entry === undefined) {
        return fail<DownloadEntry>(AppError.storage('无下载记录'));
      }
      return ok<DownloadEntry>(entry);
    } catch (e) {
      Logger.error('data', 'download status failed: %{public}s', JSON.stringify(e));
      return fail<DownloadEntry>(AppError.storage('读取下载状态失败'));
    }
  }

  async isDownloaded(chapterId: number): Promise<boolean> {
    const result = await this.status(chapterId);
    return result.ok && result.data !== undefined && result.data.status === DownloadStatus.DONE;
  }

  async updateProgress(chapterId: number, pagesDone: number, pagesTotal: number): Promise<void> {
    try {
      await (await Database.init(AppContext.require())).executeSql(
        'UPDATE downloads SET status = ?, pages_done = ?, pages_total = ?, updated_at = ? WHERE chapter_id = ?',
        [DownloadStatus.DOWNLOADING, pagesDone, pagesTotal, Date.now(), chapterId]
      );
    } catch (e) {
      Logger.warn('data', 'updateProgress failed: %{public}s', JSON.stringify(e));
    }
  }

  async markDone(chapterId: number, pagesTotal: number): Promise<void> {
    await this.setStatus(chapterId, DownloadStatus.DONE, pagesTotal);
  }

  async markError(chapterId: number): Promise<void> {
    await this.setStatus(chapterId, DownloadStatus.ERROR, -1);
  }

  private async setStatus(chapterId: number, status: number, pagesTotal: number): Promise<void> {
    try {
      const store: relationalStore.RdbStore = await Database.init(AppContext.require());
      if (pagesTotal >= 0) {
        await store.executeSql(
          'UPDATE downloads SET status = ?, pages_done = ?, pages_total = ?, updated_at = ? WHERE chapter_id = ?',
          [status, pagesTotal, pagesTotal, Date.now(), chapterId]
        );
      } else {
        await store.executeSql(
          'UPDATE downloads SET status = ?, updated_at = ? WHERE chapter_id = ?',
          [status, Date.now(), chapterId]
        );
      }
    } catch (e) {
      Logger.warn('data', 'setStatus failed: %{public}s', JSON.stringify(e));
    }
  }

  async listByManga(mangaId: number): Promise<DownloadEntry[]> {
    try {
      const rs: relationalStore.ResultSet = await (await Database.init(AppContext.require())).querySql(
        'SELECT * FROM downloads WHERE manga_id = ? ORDER BY chapter_id',
        [mangaId]
      );
      const list: DownloadEntry[] = [];
      while (rs.goToNextRow()) {
        list.push(mapRow(rs));
      }
      rs.close();
      return list;
    } catch (e) {
      Logger.warn('data', 'listByManga failed: %{public}s', JSON.stringify(e));
      return [];
    }
  }

  async clearAll(): Promise<void> {
    try {
      await (await Database.init(AppContext.require())).executeSql('DELETE FROM downloads', []);
    } catch (e) {
      Logger.warn('data', 'clearAll failed: %{public}s', JSON.stringify(e));
    }
  }
}
