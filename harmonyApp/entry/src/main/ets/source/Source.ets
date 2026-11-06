import { Result } from '../util/Result';

/**
 * 内置图源接口。
 *
 * 与 Android 端 `source-api` 的 `Source` / `CatalogueSource` 对应，但只保留我们需要的部分：
 * 不支持扩展安装，所有源都在 `source/` 下内置实现。
 */

/** 源层条目（对应 Android 的 `SManga`）。 */
export class SManga {
  url: string;
  title: string;
  author: string;
  artist: string;
  description: string;
  genre: string;
  status: number;
  thumbnailUrl: string;
  /** 源内唯一标识（MangaDex 用 UUID；其它源可用 url）。 */
  sourceId: string;
  /** 初始化标记：详情是否已拉取。 */
  initialized: boolean;

  constructor(
    url: string,
    title: string,
    author: string,
    artist: string,
    description: string,
    genre: string,
    status: number,
    thumbnailUrl: string,
    sourceId: string,
    initialized: boolean
  ) {
    this.url = url;
    this.title = title;
    this.author = author;
    this.artist = artist;
    this.description = description;
    this.genre = genre;
    this.status = status;
    this.thumbnailUrl = thumbnailUrl;
    this.sourceId = sourceId;
    this.initialized = initialized;
  }
}

/** 源层章节（对应 Android 的 `SChapter`）。 */
export class SChapter {
  url: string;
  name: string;
  chapterNumber: number;
  scanlator: string;
  dateUpload: number;
  sourceOrder: number;

  constructor(url: string, name: string, chapterNumber: number, scanlator: string, dateUpload: number, sourceOrder: number) {
    this.url = url;
    this.name = name;
    this.chapterNumber = chapterNumber;
    this.scanlator = scanlator;
    this.dateUpload = dateUpload;
    this.sourceOrder = sourceOrder;
  }
}

/** 阅读页。`imageUrl` 为可直接下载的绝对地址。 */
export class Page {
  index: number;
  imageUrl: string;

  constructor(index: number, imageUrl: string) {
    this.index = index;
    this.imageUrl = imageUrl;
  }
}

export interface Source {
  readonly id: string;
  readonly name: string;
  readonly lang: string;

  popular(page: number): Promise<Result<SManga[]>>;
  search(query: string, page: number): Promise<Result<SManga[]>>;
  details(manga: SManga): Promise<Result<SManga>>;
  chapters(manga: SManga): Promise<Result<SChapter[]>>;
  pages(chapter: SChapter): Promise<Result<Page[]>>;
}
