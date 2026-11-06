import { relationalStore } from '@kit.ArkData';
import { LibraryEntry, Manga } from '../model/Manga';
import { AppError, fail, ok, Result } from '../util/Result';
import { Logger } from '../util/Logger';
import { Database } from './Database';
import { AppContext } from '../service/AppContext';
import { mapMangaRow, toMangaBucket } from './Mapper';

/**
 * 条目仓储。只做数据读写，业务规则在 domain 层。
 * 对应 Android 端 `tachiyomi.data.manga.MangaRepositoryImpl`（裁剪版）。
 */
export class MangaRepository {
  /** 书架：favorite=1，按标题搜索；顺带用子查询取未读数。 */
  async library(query: string): Promise<Result<LibraryEntry[]>> {
    try {
      const store: relationalStore.RdbStore = await Database.init(AppContext.require());
      const trimmed: string = query.trim();
      let sql: string =
        `SELECT m.*, (SELECT COUNT(*) FROM chapters c WHERE c.manga_id = m._id AND c.read = 0) AS unread_count
         FROM mangas m WHERE m.favorite = 1 ORDER BY m.last_update DESC, m._id DESC LIMIT 500`;
      let args: Array<relationalStore.ValueType> = [];
      if (trimmed.length > 0) {
        sql =
          `SELECT m.*, (SELECT COUNT(*) FROM chapters c WHERE c.manga_id = m._id AND c.read = 0) AS unread_count
           FROM mangas m WHERE m.favorite = 1 AND m.title LIKE ? ORDER BY m.last_update DESC LIMIT 500`;
        args = [`%${trimmed}%`];
      }
      const rs: relationalStore.ResultSet = await store.querySql(sql, args);
      const list: LibraryEntry[] = [];
      while (rs.goToNextRow()) {
        list.push(new LibraryEntry(mapMangaRow(rs), rs.getLong(rs.getColumnIndex('unread_count'))));
      }
      rs.close();
      return ok(list);
    } catch (e) {
      Logger.error('data', 'library query failed: %{public}s', JSON.stringify(e));
      return fail<LibraryEntry[]>(AppError.storage('读取书架失败'));
    }
  }

  async get(id: number): Promise<Result<Manga>> {
    try {
      const rs: relationalStore.ResultSet =
        await (await Database.init(AppContext.require())).querySql('SELECT * FROM mangas WHERE _id = ? LIMIT 1', [id]);
      let manga: Manga | undefined = undefined;
      if (rs.goToFirstRow()) {
        manga = mapMangaRow(rs);
      }
      rs.close();
      if (manga === undefined) {
        return fail<Manga>(AppError.storage(`条目不存在: ${id}`));
      }
      return ok(manga);
    } catch (e) {
      Logger.error('data', 'get manga failed: %{public}s', JSON.stringify(e));
      return fail<Manga>(AppError.storage('读取条目失败'));
    }
  }

  async findBySourceUrl(sourceId: string, url: string): Promise<Result<Manga>> {
    try {
      const rs: relationalStore.ResultSet = await (await Database.init(AppContext.require()))
        .querySql('SELECT * FROM mangas WHERE source_id = ? AND url = ? LIMIT 1', [sourceId, url]);
      let manga: Manga | undefined = undefined;
      if (rs.goToFirstRow()) {
        manga = mapMangaRow(rs);
      }
      rs.close();
      if (manga === undefined) {
        return fail<Manga>(AppError.storage('条目不存在'));
      }
      return ok(manga);
    } catch (e) {
      Logger.error('data', 'find manga failed: %{public}s', JSON.stringify(e));
      return fail<Manga>(AppError.storage('查询条目失败'));
    }
  }

  /** 按 (source_id, url) 判重：存在则更新可变字段，否则插入。返回 _id。 */
  async upsert(manga: Manga): Promise<Result<number>> {
    try {
      const store: relationalStore.RdbStore = await Database.init(AppContext.require());
      await store.executeSql(
        `INSERT INTO mangas
           (source_id, url, title, author, artist, description, genre, status, thumbnail_url,
            favorite, viewer, date_added, last_update, notes)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(source_id, url) DO UPDATE SET
           title = excluded.title,
           author = excluded.author,
           artist = excluded.artist,
           description = excluded.description,
           genre = excluded.genre,
           status = excluded.status,
           thumbnail_url = excluded.thumbnail_url,
           last_update = excluded.last_update`,
        [
          manga.sourceId, manga.url, manga.title, manga.author, manga.artist, manga.description,
          manga.genre, manga.status, manga.thumbnailUrl, manga.favorite ? 1 : 0, manga.viewer,
          manga.dateAdded, manga.lastUpdate, manga.notes
        ]
      );
      const rs: relationalStore.ResultSet = await store.querySql(
        'SELECT _id FROM mangas WHERE source_id = ? AND url = ? LIMIT 1',
        [manga.sourceId, manga.url]
      );
      let id: number = 0;
      if (rs.goToFirstRow()) {
        id = rs.getLong(rs.getColumnIndex('_id'));
      }
      rs.close();
      return ok(id);
    } catch (e) {
      Logger.error('data', 'upsert manga failed: %{public}s', JSON.stringify(e));
      return fail<number>(AppError.storage('保存条目失败'));
    }
  }

  async setFavorite(id: number, favorite: boolean): Promise<Result<void>> {
    try {
      const bucket: relationalStore.ValuesBucket = { favorite: favorite ? 1 : 0 };
      const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('mangas');
      predicates.equalTo('_id', id);
      await (await Database.init(AppContext.require())).update(bucket, predicates);
      return ok(undefined);
    } catch (e) {
      Logger.error('data', 'setFavorite failed: %{public}s', JSON.stringify(e));
      return fail<void>(AppError.storage('更新收藏状态失败'));
    }
  }

  async remove(id: number): Promise<Result<void>> {
    try {
      const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('chapters');
      predicates.equalTo('manga_id', id);
      await (await Database.init(AppContext.require())).delete(predicates);

      const mangaPredicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('mangas');
      mangaPredicates.equalTo('_id', id);
      await (await Database.init(AppContext.require())).delete(mangaPredicates);
      return ok(undefined);
    } catch (e) {
      Logger.error('data', 'remove manga failed: %{public}s', JSON.stringify(e));
      return fail<void>(AppError.storage('删除条目失败'));
    }
  }
}
