import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Logger } from '../util/Logger';

const DB_NAME: string = 'komikku.db';

/** schema 版本。每次改表结构 +1，并在 Database.migrate 里补一段升级脚本。 */
export const DB_VERSION: number = 1;

const SCHEMA_V1: string[] = [
  `CREATE TABLE IF NOT EXISTS mangas (
     _id           INTEGER PRIMARY KEY AUTOINCREMENT,
     source_id     TEXT    NOT NULL,
     url           TEXT    NOT NULL,
     title         TEXT    NOT NULL,
     author        TEXT,
     artist        TEXT,
     description   TEXT,
     genre         TEXT,
     status        INTEGER NOT NULL DEFAULT 0,
     thumbnail_url TEXT,
     favorite      INTEGER NOT NULL DEFAULT 0,
     viewer        INTEGER NOT NULL DEFAULT 0,
     date_added    INTEGER NOT NULL,
     last_update   INTEGER NOT NULL DEFAULT 0,
     notes         TEXT NOT NULL DEFAULT ''
   )`,
  `CREATE UNIQUE INDEX IF NOT EXISTS idx_mangas_source_url ON mangas(source_id, url)`,
  `CREATE INDEX IF NOT EXISTS idx_mangas_favorite ON mangas(favorite)`,
  `CREATE TABLE IF NOT EXISTS chapters (
     _id            INTEGER PRIMARY KEY AUTOINCREMENT,
     manga_id       INTEGER NOT NULL,
     url            TEXT    NOT NULL,
     name           TEXT    NOT NULL,
     scanlator      TEXT,
     read           INTEGER NOT NULL DEFAULT 0,
     bookmark       INTEGER NOT NULL DEFAULT 0,
     last_page_read INTEGER NOT NULL DEFAULT 0,
     chapter_number REAL    NOT NULL DEFAULT 0,
     source_order   INTEGER NOT NULL DEFAULT 0,
     date_fetch     INTEGER NOT NULL DEFAULT 0,
     date_upload    INTEGER NOT NULL DEFAULT 0,
     UNIQUE(manga_id, url),
     FOREIGN KEY(manga_id) REFERENCES mangas(_id) ON DELETE CASCADE
   )`,
  `CREATE INDEX IF NOT EXISTS idx_chapters_manga ON chapters(manga_id)`,
  `CREATE INDEX IF NOT EXISTS idx_chapters_unread ON chapters(manga_id, read)`,
  `CREATE TABLE IF NOT EXISTS categories (
     _id  INTEGER PRIMARY KEY AUTOINCREMENT,
     name TEXT    NOT NULL,
     sort INTEGER NOT NULL DEFAULT 0
   )`,
  `CREATE TABLE IF NOT EXISTS mangas_categories (
     manga_id    INTEGER NOT NULL,
     category_id INTEGER NOT NULL,
     PRIMARY KEY(manga_id, category_id)
   )`,
  `CREATE TABLE IF NOT EXISTS history (
     chapter_id INTEGER PRIMARY KEY,
     manga_id   INTEGER NOT NULL,
     read_at    INTEGER NOT NULL
   )`,
  `INSERT OR IGNORE INTO categories(_id, name, sort) VALUES (0, '', -1)`,
];

/**
 * RDB 单例。
 *
 * 初始化时机：`EntryAbility.onCreate`；页面侧只通过仓储访问，不直接持有 store。
 * 迁移策略见 `docs/harmony/DATA_MODEL.md` §1：版本号单调递增，脚本只增不改。
 */
export class Database {
  private static store: relationalStore.RdbStore | undefined = undefined;
  private static initializing: Promise<relationalStore.RdbStore> | undefined = undefined;

  static init(context: common.Context): Promise<relationalStore.RdbStore> {
    if (Database.store !== undefined) {
      return Promise.resolve(Database.store);
    }
    if (Database.initializing !== undefined) {
      return Database.initializing;
    }
    Database.initializing = Database.open(context);
    return Database.initializing;
  }

  private static async open(context: common.Context): Promise<relationalStore.RdbStore> {
    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    const store: relationalStore.RdbStore = await relationalStore.getRdbStore(context, config);
    await store.executeSql('PRAGMA foreign_keys = ON');
    await Database.migrate(store);
    Database.store = store;
    Logger.info('data', 'RDB opened, version=%{public}d', store.version);
    return store;
  }

  private static async migrate(store: relationalStore.RdbStore): Promise<void> {
    if (store.version === 0) {
      for (const sql of SCHEMA_V1) {
        await store.executeSql(sql);
      }
      store.version = 1;
      Logger.info('data', 'schema created at v1');
      return;
    }
    if (store.version < DB_VERSION) {
      // v2 起的升级脚本在这里按版本追加，禁止修改已发布脚本。
      Logger.warn('data', 'no migration script for version=%{public}d', store.version);
    }
  }

  static get(): relationalStore.RdbStore {
    if (Database.store === undefined) {
      throw new Error('Database 尚未初始化，请先调用 Database.init(context)');
    }
    return Database.store;
  }
}
