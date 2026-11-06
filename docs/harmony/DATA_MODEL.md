# 数据模型

存储：`@ohos.data.relationalStore`（RDB，底层 SQLite），库名 `komikku.db`，安全级别 `S1`。

## 1. 表设计（schema v1）

字段在 Android 端 `data/src/main/sqldelight/tachiyomi/data/*.sq` 基础上做了裁剪：去掉 SQLDelight 类型适配列，
保留业务语义；`source` 由整数 ID 改为字符串 ID（内置源用 `mangadex`、`ehentai` 这样的稳定标识）。

### mangas

```sql
CREATE TABLE IF NOT EXISTS mangas (
  _id            INTEGER PRIMARY KEY AUTOINCREMENT,
  source_id      TEXT    NOT NULL,
  url            TEXT    NOT NULL,
  title          TEXT    NOT NULL,
  author         TEXT,
  artist         TEXT,
  description    TEXT,
  genre          TEXT,               -- JSON 数组字符串
  status         INTEGER NOT NULL DEFAULT 0,
  thumbnail_url  TEXT,
  favorite       INTEGER NOT NULL DEFAULT 0,
  viewer         INTEGER NOT NULL DEFAULT 0,
  date_added     INTEGER NOT NULL,   -- epoch millis
  last_update    INTEGER NOT NULL DEFAULT 0,
  notes          TEXT NOT NULL DEFAULT ''
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_mangas_source_url ON mangas(source_id, url);
CREATE INDEX IF NOT EXISTS idx_mangas_favorite ON mangas(favorite);
```

### chapters

```sql
CREATE TABLE IF NOT EXISTS chapters (
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
);
CREATE INDEX IF NOT EXISTS idx_chapters_manga ON chapters(manga_id);
CREATE INDEX IF NOT EXISTS idx_chapters_unread ON chapters(manga_id, read);
```

> RDB 默认不开启外键约束，`Database.init` 里执行 `PRAGMA foreign_keys = ON`；删除漫画时仍显式删章节，双保险。

### categories / mangas_categories

```sql
CREATE TABLE IF NOT EXISTS categories (
  _id   INTEGER PRIMARY KEY AUTOINCREMENT,
  name  TEXT    NOT NULL,
  sort  INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS mangas_categories (
  manga_id    INTEGER NOT NULL,
  category_id INTEGER NOT NULL,
  PRIMARY KEY(manga_id, category_id)
);
```

`_id = 0` 为"默认分类"，初始化时插入，不可删除。

### history（阅读记录）

```sql
CREATE TABLE IF NOT EXISTS history (
  chapter_id INTEGER PRIMARY KEY,
  manga_id   INTEGER NOT NULL,
  read_at    INTEGER NOT NULL
);
```

### 迁移记录

用 RDB 自带的 `store.version` 做版本号；每次 `init`：

```
if (store.version === 0) { 建全部表; store.version = 1 }
if (store.version === 1 && TARGET === 2) { 执行 v2 脚本; store.version = 2 }
```

迁移脚本按 `migrations/v2.sql`、`v3.sql` 放 `ets/data/migrations/`，**只增不改**，禁止修改已发布的脚本。

## 2. 仓储接口

```ts
export interface MangaRepository {
  library(query?: string, categoryId?: number): Promise<Manga[]>;
  get(id: number): Promise<Manga | null>;
  findBySourceUrl(sourceId: string, url: string): Promise<Manga | null>;
  upsert(manga: Manga): Promise<number>;   // 返回 _id
  setFavorite(id: number, favorite: boolean): Promise<void>;
  remove(id: number): Promise<void>;
}

export interface ChapterRepository {
  byManga(mangaId: number): Promise<Chapter[]>;
  upsertAll(mangaId: number, chapters: Chapter[]): Promise<void>;
  markRead(id: number, read: boolean, lastPage?: number): Promise<void>;
  unreadCount(mangaId: number): Promise<number>;
}
```

约定：

- 仓储只做数据读写，**不含业务规则**（例如"加入书架时要拉章节"属于 domain）
- `upsert` 按 `(source_id, url)` / `(manga_id, url)` 判重，已存在则更新可变字段（title、thumbnail、last_update）
- 所有方法返回 `Promise`，内部吞掉 RGB 错误并抛 `StorageError`

## 3. 与 Android schema 的差异

| Android | HarmonyOS | 原因 |
|---|---|---|
| `source INTEGER` | `source_id TEXT` | 内置源无需数字 ID，字符串更直观 |
| `version` / `last_modified_at` / `is_syncing` | 移除 | 为多端同步设计，MVP 不需要 |
| `memo BLOB(JSON)` | 移除 | MVP 无该功能 |
| `viewer` / `chapter_flags` | 保留 `viewer`，去掉位标志 | 阅读器模式改为独立表（M3 再定） |
| SQLCipher 加密 | 无 | RDB 不支持；应用沙箱 + 上架合规说明（见待决） |
