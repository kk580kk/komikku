import { promptAction, router } from '@kit.ArkUI';
import { AddToLibrary } from '../domain/AddToLibrary';
import { FetchPopular } from '../domain/FetchPopular';
import { SearchManga } from '../domain/SearchManga';
import { SManga } from '../source/Source';
import { GetLibrary } from '../domain/GetLibrary';
import { LibraryEntry, MangaDetailParams } from '../model/Manga';
import { Logger } from '../util/Logger';

@Entry
@Component
struct Index {
  @State entries: LibraryEntry[] = [];
  @State activeTab: number = 0;
  @State keyword: string = '';
  @State loading: boolean = true;
  @State errorMessage: string = '';

  @State browseItems: SManga[] = [];
  @State browseLoading: boolean = false;
  @State browseError: string = '';
  @State browsePage: number = 0;
  @State browseQuery: string = '';

  private getLibrary: GetLibrary = new GetLibrary();
  private fetchPopular: FetchPopular = new FetchPopular();
  private searchManga: SearchManga = new SearchManga();
  private addToLibrary: AddToLibrary = new AddToLibrary();
  private coverColors: string[] = ['#5B8DEF', '#E8734A', '#48A88A', '#9B6BD6', '#D46A8E', '#C9A227'];

  aboutToAppear(): void {
    this.loadLibrary();
  }

  onPageShow(): void {
    this.loadLibrary();
  }

  private async loadLibrary(): Promise<void> {
    this.loading = true;
    const result = await this.getLibrary.execute(this.keyword);
    if (result.ok && result.data !== undefined) {
      this.entries = result.data;
      this.errorMessage = '';
    } else {
      this.errorMessage = result.error !== undefined ? result.error.message : '加载失败';
      Logger.error('app', 'load library failed: %{public}s', this.errorMessage);
    }
    this.loading = false;
  }

  private async loadPopular(): Promise<void> {
    this.browseLoading = true;
    this.browseError = '';
    const result = await this.fetchPopular.execute('mangadex', 0);
    if (result.ok && result.data !== undefined) {
      this.browseItems = result.data;
      this.browsePage = 0;
      this.browseQuery = '';
    } else {
      this.browseError = result.error !== undefined ? result.error.message : '加载失败';
      Logger.error('app', 'popular failed: %{public}s', this.browseError);
    }
    this.browseLoading = false;
  }

  private async loadMore(): Promise<void> {
    if (this.browseLoading || this.browseQuery.length > 0) {
      return;
    }
    const next: number = this.browsePage + 1;
    const result = await this.fetchPopular.execute('mangadex', next);
    if (result.ok && result.data !== undefined) {
      this.browsePage = next;
      this.browseItems = this.browseItems.concat(result.data);
    }
  }

  private async search(query: string): Promise<void> {
    if (query.trim().length === 0) {
      this.loadPopular();
      return;
    }
    this.browseLoading = true;
    this.browseError = '';
    const result = await this.searchManga.execute('mangadex', query, 0);
    if (result.ok && result.data !== undefined) {
      this.browseItems = result.data;
      this.browsePage = 0;
    } else {
      this.browseError = result.error !== undefined ? result.error.message : '搜索失败';
    }
    this.browseLoading = false;
  }

  private async add(item: SManga): Promise<void> {
    promptAction.showToast({ message: '正在加入书架…' });
    const result = await this.addToLibrary.execute(item);
    if (result.ok) {
      promptAction.showToast({ message: '已加入书架' });
      this.loadLibrary();
    } else {
      const message: string = result.error !== undefined ? result.error.message : '加入失败';
      promptAction.showToast({ message: message });
      Logger.error('app', 'add to library failed: %{public}s', message);
    }
  }

  @Builder
  tabItem(title: string, index: number) {
    Column() {
      Text(title)
        .fontSize(12)
        .fontColor(this.activeTab === index ? '#3F6BD8' : '#8A8A8E')
        .fontWeight(this.activeTab === index ? FontWeight.Medium : FontWeight.Normal)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }

  @Builder
  mangaCard(entry: LibraryEntry, index: number) {
    Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        Stack() {
          Text(entry.manga.title.substring(0, 1))
            .fontSize(40)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .aspectRatio(0.72)
        .borderRadius(10)
        .linearGradient({
          angle: 135,
          colors: [[this.coverColors[index % this.coverColors.length], 0.0], ['#2B2B33', 1.0]]
        })

        if (entry.unreadCount > 0) {
          Text(`${entry.unreadCount}`)
            .fontSize(10)
            .fontColor('#FFFFFF')
            .backgroundColor('#E5484D')
            .borderRadius(9)
            .constraintSize({ minWidth: 18 })
            .height(18)
            .textAlign(TextAlign.Center)
            .padding({ left: 5, right: 5 })
            .margin({ top: 6, right: 6 })
        }
      }
      .width('100%')

      Text(entry.manga.title)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 6 })
        .width('100%')

      Text(entry.unreadCount > 0 ? `${entry.unreadCount} 话未读` : '已读完')
        .fontSize(11)
        .fontColor(entry.unreadCount > 0 ? '#3F6BD8' : '#8A8A8E')
        .margin({ top: 2 })
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      router.pushUrl({ url: 'pages/MangaDetailPage', params: new MangaDetailParams(entry.manga.id) });
    })
  }

  @Builder
  stateHint() {
    Column() {
      if (this.loading) {
        LoadingProgress().width(36).height(36).color('#3F6BD8')
        Text('加载中…').fontSize(13).fontColor('#8A8A8E').margin({ top: 8 })
      } else if (this.errorMessage.length > 0) {
        Text(this.errorMessage).fontSize(14).fontColor('#E5484D')
        Button('重试')
          .fontSize(13)
          .height(32)
          .margin({ top: 12 })
          .onClick(() => {
            this.loadLibrary();
          })
      } else {
        Text('书架还是空的').fontSize(15).fontColor('#4A4A50')
        Text('去「浏览」里找点漫画吧').fontSize(12).fontColor('#8A8A8E').margin({ top: 6 })
      }
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  bookshelf() {
    Column() {
      Row() {
        Text('书架').fontSize(26).fontWeight(FontWeight.Bold)
        Blank()
        Text(`${this.entries.length} 部`).fontSize(13).fontColor('#8A8A8E')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 8 })

      Search({ value: this.keyword, placeholder: '搜索书架' })
        .width('100%')
        .height(36)
        .margin({ left: 16, right: 16, bottom: 10 })
        .onChange((value: string) => {
          this.keyword = value;
          this.loadLibrary();
        })

      if (this.loading || this.errorMessage.length > 0 || this.entries.length === 0) {
        this.stateHint()
      } else {
        Grid() {
          ForEach(this.entries, (entry: LibraryEntry, index: number) => {
            GridItem() {
              this.mangaCard(entry, index)
            }
          }, (entry: LibraryEntry) => entry.manga.id.toString())
        }
        .columnsTemplate('1fr 1fr 1fr')
        .columnsGap(12)
        .rowsGap(18)
        .padding({ left: 16, right: 16, bottom: 12 })
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  browseRow(item: SManga) {
    Row() {
      Column() {
        Text(item.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(item.author.length > 0 ? item.author : item.sourceId)
          .fontSize(12)
          .fontColor('#8A8A8E')
          .margin({ top: 3 })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Button('加入')
        .fontSize(12)
        .height(28)
        .backgroundColor('#3F6BD8')
        .onClick(() => {
          this.add(item);
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .onClick(() => {
      this.add(item);
    })
  }

  @Builder
  browse() {
    Column() {
      Row() {
        Text('浏览').fontSize(26).fontWeight(FontWeight.Bold)
        Blank()
        Text('MangaDex').fontSize(12).fontColor('#3F6BD8')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 8 })

      Search({ value: this.browseQuery, placeholder: '搜索 MangaDex' })
        .width('100%')
        .height(36)
        .margin({ left: 16, right: 16, bottom: 8 })
        .onSubmit((value: string) => {
          this.browseQuery = value;
          this.search(value);
        })

      if (this.browseLoading) {
        Column() {
          LoadingProgress().width(32).height(32).color('#3F6BD8')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.browseError.length > 0) {
        Column() {
          Text(this.browseError).fontSize(13).fontColor('#E5484D')
          Button('重试').fontSize(13).height(32).margin({ top: 10 }).onClick(() => {
            this.loadPopular();
          })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.browseItems.length === 0) {
        Column() {
          Text('暂无结果').fontSize(14).fontColor('#8A8A8E')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.browseItems, (item: SManga) => {
            ListItem() {
              this.browseRow(item)
            }
          }, (item: SManga) => item.sourceId + item.url)
        }
        .layoutWeight(1)
        .divider({ strokeWidth: 0.5, color: '#E8E8EC', startMargin: 16, endMargin: 16 })
        .onReachEnd(() => {
          this.loadMore();
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  settingRow(title: string, subtitle: string) {
    Column() {
      Text(title).fontSize(15).width('100%')
      Text(subtitle).fontSize(12).fontColor('#8A8A8E').width('100%').margin({ top: 2 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  @Builder
  more() {
    Column() {
      Text('更多').fontSize(26).fontWeight(FontWeight.Bold).width('100%')
        .padding({ left: 16, right: 16, top: 14 })
      this.settingRow('图源', '内置源，M2 接入')
      this.settingRow('下载', '未实现')
      this.settingRow('备份与恢复', '未实现')
      this.settingRow('关于', 'Komikku HarmonyOS 0.1.0')
      Blank()
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.activeTab }) {
      TabContent() {
        this.bookshelf()
      }.tabBar(this.tabItem('书架', 0))

      TabContent() {
        this.browse()
      }.tabBar(this.tabItem('浏览', 1))

      TabContent() {
        this.more()
      }.tabBar(this.tabItem('更多', 2))
    }
    .onChange((index: number) => {
      this.activeTab = index;
      if (index === 1 && this.browseItems.length === 0 && !this.browseLoading) {
        this.loadPopular();
      }
    })
    .backgroundColor('#F5F5F7')
    .width('100%')
    .height('100%')
  }
}
