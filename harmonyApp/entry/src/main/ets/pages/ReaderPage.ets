import { display, promptAction, router } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { GetChapterPages } from '../domain/GetChapterPages';
import { DownloadChapter } from '../domain/DownloadChapter';
import { Downloader } from '../service/Downloader';
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
  @Prop localPath: string = '';
  @Prop targetWidth: number = 1080;
  @State pixelMap: image.PixelMap | undefined = undefined;
  @State failed: boolean = false;
  @State zoom: number = 1;
  private baseZoom: number = 1;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    this.failed = false;
    const result = this.localPath.length > 0
      ? await ImageLoader.get().loadFile(this.localPath, this.targetWidth)
      : await ImageLoader.get().load(this.url, this.targetWidth);
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
          .scale({ x: this.zoom, y: this.zoom })
          .gesture(
            GestureGroup(
              GestureMode.Exclusive,
              TapGesture({ count: 2 }).onAction(() => {
                this.zoom = this.zoom > 1 ? 1 : 2;
              }),
              PinchGesture({ fingers: 2 })
                .onActionStart(() => {
                  this.baseZoom = this.zoom;
                })
                .onActionUpdate((event: GestureEvent) => {
                  const next: number = this.baseZoom * event.scale;
                  this.zoom = Math.min(3, Math.max(1, next));
                })
            )
          )
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
  @State hasPrev: boolean = false;
  @State hasNext: boolean = false;
  @State localPaths: string[] = [];
  @State downloaded: boolean = false;
  @State downloading: boolean = false;
  @State downloadText: string = '';

  private chapterId: number = 0;
  private prevChapterId: number = 0;
  private nextChapterId: number = 0;
  private chapter: Chapter | undefined = undefined;
  private manga: Manga | undefined = undefined;
  private getChapterPages: GetChapterPages = new GetChapterPages();
  private downloadChapter: DownloadChapter = new DownloadChapter();
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
      await this.loadSiblings(result.data.chapter.mangaId, result.data.chapter.id);
      const locals: string[] = Downloader.get().localPages(
        result.data.manga.id, result.data.chapter.id, result.data.pages.length);
      this.localPaths = locals;
      this.downloaded = locals.length === result.data.pages.length && locals.length > 0;
    } else {
      this.errorMessage = result.error !== undefined ? result.error.message : '加载失败';
    }
    this.loading = false;
  }

  /** 章节按 source_order 升序排列，上一话 = 前一个元素。 */
  private async loadSiblings(mangaId: number, currentId: number): Promise<void> {
    const result = await this.chapterRepo.byManga(mangaId);
    if (!result.ok || result.data === undefined) {
      return;
    }
    // 按话数升序排，保证「上一话」是更小的话数（与详情页的展示顺序无关）
    const ordered: Chapter[] = result.data.slice().sort((a: Chapter, b: Chapter) => a.chapterNumber - b.chapterNumber);
    const index: number = ordered.findIndex((c: Chapter) => c.id === currentId);
    if (index < 0) {
      return;
    }
    this.prevChapterId = index > 0 ? ordered[index - 1].id : 0;
    this.nextChapterId = index < ordered.length - 1 ? ordered[index + 1].id : 0;
    this.hasPrev = this.prevChapterId > 0;
    this.hasNext = this.nextChapterId > 0;
  }

  private openChapter(targetId: number): void {
    if (targetId <= 0) {
      return;
    }
    router.replaceUrl({ url: 'pages/ReaderPage', params: new ReaderParams(targetId) });
  }

  private async startDownload(): Promise<void> {
    if (this.downloading || this.downloaded) {
      return;
    }
    this.downloading = true;
    this.downloadText = '下载中…';
    const result = await this.downloadChapter.execute(this.chapterId, (done: number, total: number) => {
      this.downloadText = '下载 ' + done + '/' + total;
    });
    this.downloading = false;
    this.downloadText = '';
    if (result.ok) {
      this.downloaded = true;
      if (this.manga !== undefined && this.chapter !== undefined) {
        this.localPaths = Downloader.get().localPages(this.manga.id, this.chapter.id, this.pages.length);
      }
      promptAction.showToast({ message: '下载完成，可离线阅读' });
    } else {
      const message: string = result.error !== undefined ? result.error.message : '下载失败';
      promptAction.showToast({ message: message });
      Logger.error('reader', 'download failed: %{public}s', message);
    }
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
      Text(this.downloading ? this.downloadText : (this.downloaded ? '已下载' : '下载'))
        .fontSize(13)
        .fontColor(this.downloaded ? '#8FE3A0' : '#FFFFFF')
        .margin({ right: 12 })
        .onClick(() => {
          this.startDownload();
        })
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
        .fontColor(this.hasPrev ? '#FFFFFF' : '#66FFFFFF')
        .layoutWeight(1)
        .enabled(this.hasPrev)
        .onClick(() => {
          this.openChapter(this.prevChapterId);
        })
      Button('下一话')
        .fontSize(12)
        .height(30)
        .backgroundColor('#33FFFFFF')
        .fontColor(this.hasNext ? '#FFFFFF' : '#66FFFFFF')
        .layoutWeight(1)
        .margin({ left: 10 })
        .enabled(this.hasNext)
        .onClick(() => {
          this.openChapter(this.nextChapterId);
        })
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
              ReaderPageImage({
                url: url,
                localPath: index < this.localPaths.length ? this.localPaths[index] : '',
                targetWidth: this.pageWidth
              })
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
