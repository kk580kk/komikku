import { GetChapterPages } from './GetChapterPages';
import { Downloader, DownloadProgress } from '../service/Downloader';
import { Page } from '../source/Source';
import { AppError, fail, ok, Result } from '../util/Result';

/** 用例：把一章的图片下载到本地（断点续传由 Downloader 负责）。 */
export class DownloadChapter {
  private getChapterPages: GetChapterPages = new GetChapterPages();

  async execute(chapterId: number, onProgress: DownloadProgress | undefined = undefined): Promise<Result<void>> {
    const result = await this.getChapterPages.execute(chapterId);
    if (!result.ok || result.data === undefined) {
      return fail<void>(result.error ?? AppError.storage('章节不存在'));
    }
    const pages: Page[] = result.data.pages;
    return Downloader.get().downloadChapter(result.data.manga.id, result.data.chapter.id, pages, onProgress);
  }
}
