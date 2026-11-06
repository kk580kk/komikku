import { relationalStore } from '@kit.ArkData';
import { Chapter, Manga } from '../model/Manga';

/** ResultSet → 领域模型。列名必须与 DATA_MODEL.md 保持一致。 */
export function mapMangaRow(rs: relationalStore.ResultSet): Manga {
  return new Manga(
    rs.getLong(rs.getColumnIndex('_id')),
    rs.getString(rs.getColumnIndex('source_id')),
    rs.getString(rs.getColumnIndex('url')),
    rs.getString(rs.getColumnIndex('title')),
    rs.getString(rs.getColumnIndex('author')),
    rs.getString(rs.getColumnIndex('artist')),
    rs.getString(rs.getColumnIndex('description')),
    rs.getString(rs.getColumnIndex('genre')),
    rs.getLong(rs.getColumnIndex('status')),
    rs.getString(rs.getColumnIndex('thumbnail_url')),
    rs.getLong(rs.getColumnIndex('favorite')) === 1,
    rs.getLong(rs.getColumnIndex('viewer')),
    rs.getLong(rs.getColumnIndex('date_added')),
    rs.getLong(rs.getColumnIndex('last_update')),
    rs.getString(rs.getColumnIndex('notes'))
  );
}

export function mapChapterRow(rs: relationalStore.ResultSet): Chapter {
  return new Chapter(
    rs.getLong(rs.getColumnIndex('_id')),
    rs.getLong(rs.getColumnIndex('manga_id')),
    rs.getString(rs.getColumnIndex('url')),
    rs.getString(rs.getColumnIndex('name')),
    rs.getString(rs.getColumnIndex('scanlator')),
    rs.getLong(rs.getColumnIndex('read')) === 1,
    rs.getLong(rs.getColumnIndex('bookmark')) === 1,
    rs.getLong(rs.getColumnIndex('last_page_read')),
    rs.getDouble(rs.getColumnIndex('chapter_number')),
    rs.getLong(rs.getColumnIndex('source_order')),
    rs.getLong(rs.getColumnIndex('date_fetch')),
    rs.getLong(rs.getColumnIndex('date_upload'))
  );
}

/** Manga → 入库 ValuesBucket。 */
export function toMangaBucket(manga: Manga): relationalStore.ValuesBucket {
  const bucket: relationalStore.ValuesBucket = {
    source_id: manga.sourceId,
    url: manga.url,
    title: manga.title,
    author: manga.author,
    artist: manga.artist,
    description: manga.description,
    genre: manga.genre,
    status: manga.status,
    thumbnail_url: manga.thumbnailUrl,
    favorite: manga.favorite ? 1 : 0,
    viewer: manga.viewer,
    date_added: manga.dateAdded,
    last_update: manga.lastUpdate,
    notes: manga.notes
  };
  return bucket;
}

/** Chapter → 入库 ValuesBucket（不含 _id / manga_id，由调用方补）。 */
export function toChapterBucket(chapter: Chapter): relationalStore.ValuesBucket {
  const bucket: relationalStore.ValuesBucket = {
    manga_id: chapter.mangaId,
    url: chapter.url,
    name: chapter.name,
    scanlator: chapter.scanlator,
    read: chapter.read ? 1 : 0,
    bookmark: chapter.bookmark ? 1 : 0,
    last_page_read: chapter.lastPageRead,
    chapter_number: chapter.chapterNumber,
    source_order: chapter.sourceOrder,
    date_fetch: chapter.dateFetch,
    date_upload: chapter.dateUpload
  };
  return bucket;
}
