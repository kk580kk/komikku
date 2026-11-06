/**
 * 条目模型：对应 Android 端 `tachiyomi.domain.manga.model.Manga` 的最小子集。
 * 后续接入 relationalStore 时，保持字段与 SQLDelight 的 mangas 表一一对应。
 */
export class Manga {
  id: number;
  title: string;
  author: string;
  artist: string;
  description: string;
  sourceName: string;
  coverUrl: string;
  unreadCount: number;
  inLibrary: boolean;

  constructor(
    id: number,
    title: string,
    author: string,
    artist: string,
    description: string,
    sourceName: string,
    coverUrl: string,
    unreadCount: number,
    inLibrary: boolean
  ) {
    this.id = id;
    this.title = title;
    this.author = author;
    this.artist = artist;
    this.description = description;
    this.sourceName = sourceName;
    this.coverUrl = coverUrl;
    this.unreadCount = unreadCount;
    this.inLibrary = inLibrary;
  }
}

/** 章节模型：对应 Android 端 `tachiyomi.domain.chapter.model.Chapter`。 */
export class Chapter {
  id: number;
  mangaId: number;
  name: string;
  chapterNumber: number;
  read: boolean;
  bookmark: boolean;
  scanlator: string;

  constructor(
    id: number,
    mangaId: number,
    name: string,
    chapterNumber: number,
    read: boolean,
    bookmark: boolean,
    scanlator: string
  ) {
    this.id = id;
    this.mangaId = mangaId;
    this.name = name;
    this.chapterNumber = chapterNumber;
    this.read = read;
    this.bookmark = bookmark;
    this.scanlator = scanlator;
  }
}

/** 路由参数：ArkTS 不允许匿名对象字面量，参数统一用具名类承载。 */
export class MangaDetailParams {
  mangaId: number;

  constructor(mangaId: number) {
    this.mangaId = mangaId;
  }
}
