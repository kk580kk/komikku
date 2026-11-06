import { display, promptAction, router } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { GetChapterPages } from '../domain/GetChapterPages';
import { ChapterRepository } from '../data/ChapterRepository';
import { Chapter, Manga } from '../model/Manga';
import { ImageLoader } from '../service/ImageLoader';
import { Logger } from '../util/Logger';

/** 阅读器路由参数。 */
export class ReaderParams {
  chapterId: number;

  constructor(chapterId: number) {
    this.chapterId = chapterId;
  }
}

/** 单页图片：命中 ImageLoader 的内存/磁盘缓存。 */
@Component
struct ReaderPageImage {
  @Prop url: string = '';
  @Prop targetWidth: number = 1080;
  @State pixelMap: image.PixelMap | undefined = undefined;
  @State failed: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    this.failed = false;
    const result = await ImageLoader.get().load(this.url, this.targetWidth);
    if (result.ok && result.data !== undefined) {
      this.pixelMap = result.data;
    } else {
      this.failed = true;
      Logger.warn('reader', 'image failed: %{public}s', result.error !== undefined ? result.error.message : '');
    }
  }

  build() {
    Column() {
      if (this.pixelMap !== undefined) {
        Image(this.pixelMap)
          .width('100%')
          .objectFit(ImageFit.Contain)
          .draggable(false)
      } else if (this.failed) {
        Column() {
          Text('图片加载失败').fontSize(12).fontColor('#8A8A8E')
          Button('重试').fontSize(12).height(28).margin({ top: 8 }).onClick(() => {
            this.load();
          })
        }
        .width('100%')
        .height(220)
        .justifyContent(FlexAlign.Center)
      } else {
        Column() {
          LoadingProgress().width(28).height(28).color('#8A8A8E')
        }
        .width('100%')
        .height(220)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
  }
}

@Entry
@Component
struct ReaderPage {
  @State chapterTitle: string = '';
  @State pages: string[] = [];
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State currentIndex: number = 0;
  @State barsVisible: boolean = true;
  @State pageWidth: number = 1080;

  private chapterId: number = 0;
  private chapter: Chapter | undefined = undefined;
  private manga: Manga | undefined = undefined;
  private getChapterPages: GetChapterPages = new GetChapterPages();
  private chapterRepo: ChapterRepository = new ChapterRepository();
  private lastSavedIndex: number = -1;
  private saveTimer: number = -1;

  aboutToAppear(): void {
    const params = router.getParams() as ReaderParams;
    this.chapterId = params.chapterId;
    try {
      this.pageWidth = display.getDefaultDisplaySync().width;
    } catch (e) {
      this.pageWidth = 1080;
    }
    this.load();
  }

  aboutToDisappear(): void {
    this.saveProgress(this.currentIndex, false);
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    const result = await this.getChapterPages.execute(this.chapterId);
    if (result.ok && result.data !== undefined) {
      this.chapter = result.data.chapter;
      this.manga = result.data.manga;
      this.chapterTitle = result.data.manga.title + ' · ' + result.data.chapter.name;
      this.pages = result.data.pages.map((p) => p.imageUrl);
      this.currentIndex = Math.min(result.data.chapter.lastPageRead, Math.max(this.pages.length - 1, 0));
      Logger.info('reader', 'loaded pages=%{public}d', this.pages.length);
    } else {
      this.errorMessage = result.error !== undefined ? result.error.message : '加载失败';
    }
    this.loading = false;
  }

  private onScrollIndex(first: number): void {
    if (first === this.currentIndex) {
      return;
    }
    this.currentIndex = first;
    if (this.saveTimer !== -1) {
      clearTimeout(this.saveTimer);
    }
    this.saveTimer = setTimeout(() => {
      this.saveProgress(this.currentIndex, false);
    }, 800);
    if (first >= this.pages.length - 1 && this.pages.length > 0) {
      this.saveProgress(first, true);
    }
  }

  private async saveProgress(index: number, read: boolean): Promise<void> {
    if (index === this.lastSavedIndex) {
      return;
    }
    this.lastSavedIndex = index;
    await this.chapterRepo.markRead(this.chapterId, read, index);
  }

  @Builder
  topBar() {
    Row() {
      Text('‹ 返回')
        .fontSize(14)
        .fontColor('#FFFFFF')
        .onClick(() => {
          router.back();
        })
      Blank()
      Text(this.chapterTitle)
        .fontSize(13)
        .fontColor('#FFFFFF')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Blank()
      Text(`${this.currentIndex + 1}/${this.pages.length}`)
        .fontSize(13)
        .fontColor('#FFFFFF')
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor('#CC000000')
  }

  @Builder
  bottomBar() {
    Row() {
      Button('上一话')
        .fontSize(12)
        .height(30)
        .backgroundColor('#33FFFFFF')
        .layoutWeight(1)
        .enabled(false)
      Button('下一话')
        .fontSize(12)
        .height(30)
        .backgroundColor('#33FFFFFF')
        .layoutWeight(1)
        .margin({ left: 10 })
        .enabled(false)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor('#CC000000')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.loading) {
        Column() {
          LoadingProgress().width(36).height(36).color('#FFFFFF')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#000000')
      } else if (this.errorMessage.length > 0) {
        Column() {
          Text(this.errorMessage).fontSize(13).fontColor('#E5484D')
          Button('重试').fontSize(13).height(32).margin({ top: 12 }).onClick(() => {
            this.load();
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#000000')
      } else {
        List() {
          ForEach(this.pages, (url: string, index: number) => {
            ListItem() {
              ReaderPageImage({ url: url, targetWidth: this.pageWidth })
            }
          }, (url: string) => url)
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .cachedCount(3)
        .onScrollIndex((first: number, last: number, center: number) => {
          this.onScrollIndex(first);
        })
        .onClick(() => {
          this.barsVisible = !this.barsVisible;
        })
        .backgroundColor('#000000')
      }

      if (this.barsVisible && !this.loading) {
        Column() {
          this.topBar()
          Blank()
          this.bottomBar()
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
  }
}
