import { relationalStore } from '@kit.ArkData';
import { Chapter } from '../model/Manga';
import { AppError, fail, ok, Result } from '../util/Result';
import { Logger } from '../util/Logger';
import { Database } from './Database';
import { AppContext } from '../service/AppContext';
import { mapChapterRow } from './Mapper';

/**
 * 章节仓储。
 *
 * 合并规则：按 (manga_id, url) 判重；已存在只更新来自源的字段（name / chapter_number /
 * source_order / date_upload），**不动** read / bookmark / last_page_read —— 用户的阅读状态
 * 不能被一次刷新覆盖掉。
 */
export class ChapterRepository {
  async byId(chapterId: number): Promise<Result<Chapter>> {
    try {
      const rs: relationalStore.ResultSet = await (await Database.init(AppContext.require())).querySql(
        'SELECT * FROM chapters WHERE _id = ? LIMIT 1',
        [chapterId]
      );
      let chapter: Chapter | undefined = undefined;
      if (rs.goToFirstRow()) {
        chapter = mapChapterRow(rs);
      }
      rs.close();
      if (chapter === undefined) {
        return fail<Chapter>(AppError.storage('章节不存在: ' + chapterId));
      }
      return ok<Chapter>(chapter);
    } catch (e) {
      Logger.error('data', 'byId failed: %{public}s', JSON.stringify(e));
      return fail<Chapter>(AppError.storage('读取章节失败'));
    }
  }

  async byManga(mangaId: number): Promise<Result<Chapter[]>> {
    try {
      const rs: relationalStore.ResultSet = await (await Database.init(AppContext.require())).querySql(
        'SELECT * FROM chapters WHERE manga_id = ? ORDER BY source_order ASC, chapter_number DESC',
        [mangaId]
      );
      const list: Chapter[] = [];
      while (rs.goToNextRow()) {
        list.push(mapChapterRow(rs));
      }
      rs.close();
      return ok(list);
    } catch (e) {
      Logger.error('data', 'byManga failed: %{public}s', JSON.stringify(e));
      return fail<Chapter[]>(AppError.storage('读取章节失败'));
    }
  }

  async upsertAll(mangaId: number, chapters: Chapter[]): Promise<Result<number>> {
    try {
      const store: relationalStore.RdbStore = await Database.init(AppContext.require());
      let changed: number = 0;
      for (const chapter of chapters) {
        await store.executeSql(
          `INSERT INTO chapters
             (manga_id, url, name, scanlator, read, bookmark, last_page_read,
              chapter_number, source_order, date_fetch, date_upload)
           VALUES (?, ?, ?, ?, 0, 0, 0, ?, ?, ?, ?)
           ON CONFLICT(manga_id, url) DO UPDATE SET
             name = excluded.name,
             scanlator = excluded.scanlator,
             chapter_number = excluded.chapter_number,
             source_order = excluded.source_order,
             date_upload = excluded.date_upload`,
          [
            mangaId, chapter.url, chapter.name, chapter.scanlator, chapter.chapterNumber,
            chapter.sourceOrder, chapter.dateFetch, chapter.dateUpload
          ]
        );
        changed++;
      }
      return ok(changed);
    } catch (e) {
      Logger.error('data', 'upsertAll failed: %{public}s', JSON.stringify(e));
      return fail<number>(AppError.storage('保存章节失败'));
    }
  }

  async markRead(id: number, read: boolean, lastPage: number = -1): Promise<Result<void>> {
    try {
      const store: relationalStore.RdbStore = await Database.init(AppContext.require());
      if (lastPage >= 0) {
        await store.executeSql(
          'UPDATE chapters SET read = ?, last_page_read = ? WHERE _id = ?',
          [read ? 1 : 0, lastPage, id]
        );
      } else {
        await store.executeSql('UPDATE chapters SET read = ? WHERE _id = ?', [read ? 1 : 0, id]);
      }
      return ok<void>(undefined);
    } catch (e) {
      Logger.error('data', 'markRead failed: %{public}s', JSON.stringify(e));
      return fail<void>(AppError.storage('更新阅读状态失败'));
    }
  }

  async unreadCount(mangaId: number): Promise<number> {
    try {
      const rs: relationalStore.ResultSet = await (await Database.init(AppContext.require())).querySql(
        'SELECT COUNT(*) AS c FROM chapters WHERE manga_id = ? AND read = 0',
        [mangaId]
      );
      let count: number = 0;
      if (rs.goToFirstRow()) {
        count = rs.getLong(rs.getColumnIndex('c'));
      }
      rs.close();
      return count;
    } catch (e) {
      Logger.error('data', 'unreadCount failed: %{public}s', JSON.stringify(e));
      return 0;
    }
  }
}
