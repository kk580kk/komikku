/**
 * 条目与章节模型。
 * 字段与 `docs/harmony/DATA_MODEL.md` 的 mangas / chapters 表一一对应；
 * 对应 Android 端 `tachiyomi.domain.manga.model.Manga` / `tachiyomi.domain.chapter.model.Chapter`。
 */

export class Manga {
  id: number;
  sourceId: string;
  url: string;
  title: string;
  author: string;
  artist: string;
  description: string;
  genre: string;
  status: number;
  thumbnailUrl: string;
  favorite: boolean;
  viewer: number;
  dateAdded: number;
  lastUpdate: number;
  notes: string;

  constructor(
    id: number,
    sourceId: string,
    url: string,
    title: string,
    author: string,
    artist: string,
    description: string,
    genre: string,
    status: number,
    thumbnailUrl: string,
    favorite: boolean,
    viewer: number,
    dateAdded: number,
    lastUpdate: number,
    notes: string
  ) {
    this.id = id;
    this.sourceId = sourceId;
    this.url = url;
    this.title = title;
    this.author = author;
    this.artist = artist;
    this.description = description;
    this.genre = genre;
    this.status = status;
    this.thumbnailUrl = thumbnailUrl;
    this.favorite = favorite;
    this.viewer = viewer;
    this.dateAdded = dateAdded;
    this.lastUpdate = lastUpdate;
    this.notes = notes;
  }

  /** 新建条目（尚未入库，id 为 0）。 */
  static create(sourceId: string, url: string, title: string): Manga {
    return new Manga(0, sourceId, url, title, '', '', '', '[]', 0, '', false, 0, Date.now(), 0, '');
  }
}

export class Chapter {
  id: number;
  mangaId: number;
  url: string;
  name: string;
  scanlator: string;
  read: boolean;
  bookmark: boolean;
  lastPageRead: number;
  chapterNumber: number;
  sourceOrder: number;
  dateFetch: number;
  dateUpload: number;

  constructor(
    id: number,
    mangaId: number,
    url: string,
    name: string,
    scanlator: string,
    read: boolean,
    bookmark: boolean,
    lastPageRead: number,
    chapterNumber: number,
    sourceOrder: number,
    dateFetch: number,
    dateUpload: number
  ) {
    this.id = id;
    this.mangaId = mangaId;
    this.url = url;
    this.name = name;
    this.scanlator = scanlator;
    this.read = read;
    this.bookmark = bookmark;
    this.lastPageRead = lastPageRead;
    this.chapterNumber = chapterNumber;
    this.sourceOrder = sourceOrder;
    this.dateFetch = dateFetch;
    this.dateUpload = dateUpload;
  }
}

/** 详情页数据：条目 + 章节，避免页面分两次查询。 */
export class MangaDetail {
  manga: Manga;
  chapters: Chapter[];

  constructor(manga: Manga, chapters: Chapter[]) {
    this.manga = manga;
    this.chapters = chapters;
  }
}

/** 路由参数：ArkTS 不允许匿名对象字面量，参数统一用具名类承载。 */
export class MangaDetailParams {
  mangaId: number;

  constructor(mangaId: number) {
    this.mangaId = mangaId;
  }
}

/** 书架列表项：条目 + 未读章节数（未读数由 SQL 子查询得出，不落库）。 */
export class LibraryEntry {
  manga: Manga;
  unreadCount: number;

  constructor(manga: Manga, unreadCount: number) {
    this.manga = manga;
    this.unreadCount = unreadCount;
  }
}
