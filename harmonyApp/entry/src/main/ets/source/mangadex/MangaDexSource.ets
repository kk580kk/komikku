import { Http } from '../../service/Http';
import { Result, AppError, ok, fail } from '../../util/Result';
import { Source, SManga, SChapter, Page } from '../Source';

const API_BASE: string = 'https://api.mangadex.org';
const COVER_BASE: string = 'https://uploads.mangadex.org/covers/';
const SOURCE_ID: string = 'mangadex';
const PAGE_LIMIT: number = 20;
const JSON_HEADERS: Record<string, string> = { 'Accept': 'application/json' };

interface MangaAttributesDto {
  title?: Record<string, string>;
  description?: Record<string, string>;
  status?: string;
  tags?: Array<TagDto>;
}

interface TagAttributesDto {
  name?: Record<string, string>;
}

interface TagDto {
  id?: string;
  attributes?: TagAttributesDto;
}

interface RelationshipAttributesDto {
  fileName?: string;
  name?: string;
}

interface RelationshipDto {
  id?: string;
  type?: string;
  attributes?: RelationshipAttributesDto;
}

interface MangaDto {
  id?: string;
  attributes?: MangaAttributesDto;
  relationships?: Array<RelationshipDto>;
}

interface MangaListDto {
  data?: Array<MangaDto>;
}

interface MangaDetailDto {
  data?: MangaDto;
}

interface ChapterAttributesDto {
  chapter?: string;
  title?: string;
  translatedLanguage?: string;
  publishAt?: string;
}

interface ChapterDto {
  id?: string;
  attributes?: ChapterAttributesDto;
  relationships?: Array<RelationshipDto>;
}

interface ChapterListDto {
  data?: Array<ChapterDto>;
}

interface AtHomeChapterDto {
  hash?: string;
  data?: Array<string>;
}

interface AtHomeDto {
  baseUrl?: string;
  chapter?: AtHomeChapterDto;
}

export class MangaDexSource implements Source {
  readonly id: string = SOURCE_ID;
  readonly name: string = 'MangaDex';
  readonly lang: string = 'en';

  private readonly http: Http = new Http();

  async popular(page: number): Promise<Result<SManga[]>> {
    const offset: number = page * PAGE_LIMIT;
    const url: string = API_BASE + '/manga?limit=' + PAGE_LIMIT + '&offset=' + offset +
      '&includes[]=cover_art&order[followedCount]=desc';
    return this.fetchMangaList(url);
  }

  async search(query: string, page: number): Promise<Result<SManga[]>> {
    const offset: number = page * PAGE_LIMIT;
    const url: string = API_BASE + '/manga?limit=' + PAGE_LIMIT + '&offset=' + offset +
      '&includes[]=cover_art&order[followedCount]=desc&title=' + encodeURIComponent(query);
    return this.fetchMangaList(url);
  }

  async details(manga: SManga): Promise<Result<SManga>> {
    const url: string = API_BASE + '/manga/' + manga.url + '?includes[]=cover_art&includes[]=author&includes[]=artist';
    const r: Result<string> = await this.http.request('GET', url, JSON_HEADERS, undefined);
    if (!r.ok || r.data === undefined) {
      return fail<SManga>(r.error ?? AppError.network('request failed'));
    }
    let parsed: MangaDetailDto;
    try {
      parsed = JSON.parse(r.data) as MangaDetailDto;
    } catch (error) {
      return fail<SManga>(AppError.parse('invalid response'));
    }
    const item: MangaDto | undefined = parsed.data;
    if (item === undefined) {
      return fail<SManga>(AppError.parse('missing data'));
    }
    const idValue: string | undefined = MangaDexSource.asString(item.id);
    const id: string = idValue !== undefined && idValue.length > 0 ? idValue : manga.url;
    return ok<SManga>(MangaDexSource.mapManga(id, item, true));
  }

  async chapters(manga: SManga): Promise<Result<SChapter[]>> {
    const url: string = API_BASE + '/manga/' + manga.url +
      '/feed?limit=500&translatedLanguage[]=en&order[chapter]=desc&includes[]=scanlation_group&includes[]=user';
    const r: Result<string> = await this.http.request('GET', url, JSON_HEADERS, undefined);
    if (!r.ok || r.data === undefined) {
      return fail<SChapter[]>(r.error ?? AppError.network('request failed'));
    }
    let parsed: ChapterListDto;
    try {
      parsed = JSON.parse(r.data) as ChapterListDto;
    } catch (error) {
      return fail<SChapter[]>(AppError.parse('invalid response'));
    }
    const rawList: Array<ChapterDto> | undefined = parsed.data;
    if (rawList === undefined) {
      return fail<SChapter[]>(AppError.parse('missing data'));
    }
    const list: Array<SChapter> = [];
    for (let i = 0; i < rawList.length; i++) {
      const item: ChapterDto = rawList[i];
      const id: string | undefined = MangaDexSource.asString(item.id);
      if (id === undefined || id.length === 0) {
        continue;
      }
      list.push(MangaDexSource.mapChapter(id, item, i));
    }
    return ok<SChapter[]>(list);
  }

  async pages(chapter: SChapter): Promise<Result<Page[]>> {
    const url: string = API_BASE + '/at-home/server/' + chapter.url;
    const r: Result<string> = await this.http.request('GET', url, JSON_HEADERS, undefined);
    if (!r.ok || r.data === undefined) {
      return fail<Page[]>(r.error ?? AppError.network('request failed'));
    }
    let parsed: AtHomeDto;
    try {
      parsed = JSON.parse(r.data) as AtHomeDto;
    } catch (error) {
      return fail<Page[]>(AppError.parse('invalid response'));
    }
    const chapterInfo: AtHomeChapterDto | undefined = parsed.chapter;
    const baseUrl: string | undefined = MangaDexSource.asString(parsed.baseUrl);
    const hash: string | undefined = MangaDexSource.asString(chapterInfo?.hash);
    const files: Array<string> | undefined = chapterInfo?.data;
    if (baseUrl === undefined || baseUrl.length === 0 || hash === undefined || hash.length === 0 ||
      files === undefined) {
      return fail<Page[]>(AppError.parse('missing at-home data'));
    }
    const list: Array<Page> = [];
    for (let i = 0; i < files.length; i++) {
      const file: string | undefined = MangaDexSource.asString(files[i]);
      if (file === undefined || file.length === 0) {
        continue;
      }
      list.push(new Page(i, baseUrl + '/data/' + hash + '/' + file));
    }
    return ok<Page[]>(list);
  }

  private async fetchMangaList(url: string): Promise<Result<SManga[]>> {
    const r: Result<string> = await this.http.request('GET', url, JSON_HEADERS, undefined);
    if (!r.ok || r.data === undefined) {
      return fail<SManga[]>(r.error ?? AppError.network('request failed'));
    }
    let parsed: MangaListDto;
    try {
      parsed = JSON.parse(r.data) as MangaListDto;
    } catch (error) {
      return fail<SManga[]>(AppError.parse('invalid response'));
    }
    const rawList: Array<MangaDto> | undefined = parsed.data;
    if (rawList === undefined) {
      return fail<SManga[]>(AppError.parse('missing data'));
    }
    const list: Array<SManga> = [];
    for (let i = 0; i < rawList.length; i++) {
      const item: MangaDto = rawList[i];
      const id: string | undefined = MangaDexSource.asString(item.id);
      if (id === undefined || id.length === 0) {
        continue;
      }
      list.push(MangaDexSource.mapManga(id, item, false));
    }
    return ok<SManga[]>(list);
  }

  private static mapManga(id: string, item: MangaDto, initialized: boolean): SManga {
    const attrs: MangaAttributesDto | undefined = item.attributes;
    const rels: Array<RelationshipDto> | undefined = item.relationships;
    const title: string = MangaDexSource.pickLocalized(attrs?.title);
    const author: string = MangaDexSource.pickRelationName(rels, 'author');
    const artist: string = MangaDexSource.pickRelationName(rels, 'artist');
    const description: string = MangaDexSource.pickLocalized(attrs?.description);
    const genre: string = MangaDexSource.pickTagNames(attrs?.tags);
    const thumbnailUrl: string = MangaDexSource.pickCoverUrl(id, rels);
    return new SManga(id, title, author, artist, description, genre, 0, thumbnailUrl, SOURCE_ID, initialized);
  }

  private static mapChapter(id: string, item: ChapterDto, order: number): SChapter {
    const attrs: ChapterAttributesDto | undefined = item.attributes;
    const chapterAttr: string | undefined = MangaDexSource.asString(attrs?.chapter);
    const titleAttr: string | undefined = MangaDexSource.asString(attrs?.title);
    const publishAt: string | undefined = MangaDexSource.asString(attrs?.publishAt);
    let name: string = 'Oneshot';
    if (chapterAttr !== undefined && chapterAttr.length > 0) {
      name = 'Chapter ' + chapterAttr;
    } else if (titleAttr !== undefined && titleAttr.length > 0) {
      name = titleAttr;
    }
    let chapterNumber: number = 0;
    if (chapterAttr !== undefined && chapterAttr.length > 0) {
      const parsed: number = parseFloat(chapterAttr);
      if (!isNaN(parsed)) {
        chapterNumber = parsed;
      }
    }
    let dateUpload: number = 0;
    if (publishAt !== undefined) {
      const ts: number = Date.parse(publishAt);
      if (!isNaN(ts)) {
        dateUpload = ts;
      }
    }
    const scanlator: string = MangaDexSource.pickRelationName(item.relationships, 'scanlation_group');
    return new SChapter(id, name, chapterNumber, scanlator, dateUpload, order);
  }

  private static pickLocalized(value: Record<string, string> | undefined): string {
    if (value === undefined) {
      return '';
    }
    const preferred: string | undefined = MangaDexSource.asString(value['en']);
    if (preferred !== undefined && preferred.length > 0) {
      return preferred;
    }
    const keys: Array<string> = Object.keys(value);
    for (const key of keys) {
      const text: string | undefined = MangaDexSource.asString(value[key]);
      if (text !== undefined && text.length > 0) {
        return text;
      }
    }
    return '';
  }

  private static pickTagNames(tags: Array<TagDto> | undefined): string {
    if (tags === undefined) {
      return '';
    }
    const names: Array<string> = [];
    for (const tag of tags) {
      const name: string = MangaDexSource.pickLocalized(tag.attributes?.name);
      if (name.length > 0) {
        names.push(name);
      }
    }
    return names.join(',');
  }

  private static pickRelationName(rels: Array<RelationshipDto> | undefined, type: string): string {
    if (rels === undefined) {
      return '';
    }
    for (const rel of rels) {
      if (rel.type === type) {
        const name: string | undefined = MangaDexSource.asString(rel.attributes?.name);
        if (name !== undefined && name.length > 0) {
          return name;
        }
      }
    }
    return '';
  }

  private static pickCoverUrl(mangaId: string, rels: Array<RelationshipDto> | undefined): string {
    if (rels === undefined) {
      return '';
    }
    for (const rel of rels) {
      if (rel.type === 'cover_art') {
        const fileName: string | undefined = MangaDexSource.asString(rel.attributes?.fileName);
        if (fileName !== undefined && fileName.length > 0) {
          return COVER_BASE + mangaId + '/' + fileName + '.256.jpg';
        }
      }
    }
    return '';
  }

  private static asString(value: string | undefined): string | undefined {
    return typeof value === 'string' ? value : undefined;
  }
}
