import { promptAction, router } from '@kit.ArkUI';
import { GetMangaDetail } from '../domain/GetMangaDetail';
import { ToggleFavorite } from '../domain/ToggleFavorite';
import { Chapter, Manga, MangaDetail, MangaDetailParams } from '../model/Manga';
import { Logger } from '../util/Logger';

@Entry
@Component
struct MangaDetailPage {
  @State manga: Manga | undefined = undefined;
  @State favorite: boolean = false;
  @State chapters: Chapter[] = [];
  @State expanded: boolean = false;
  @State loading: boolean = true;
  @State errorMessage: string = '';

  private getMangaDetail: GetMangaDetail = new GetMangaDetail();
  private toggleFavorite: ToggleFavorite = new ToggleFavorite();
  private mangaId: number = 0;

  aboutToAppear(): void {
    const params = router.getParams() as MangaDetailParams;
    this.mangaId = params.mangaId;
    this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    const result = await this.getMangaDetail.execute(this.mangaId);
    if (result.ok && result.data !== undefined) {
      const detail: MangaDetail = result.data;
      this.manga = detail.manga;
      this.favorite = detail.manga.favorite;
      this.chapters = detail.chapters;
      this.errorMessage = '';
    } else {
      this.errorMessage = result.error !== undefined ? result.error.message : '加载失败';
      Logger.error('app', 'load detail failed: %{public}s', this.errorMessage);
    }
    this.loading = false;
  }

  private async onToggleFavorite(): Promise<void> {
    if (this.manga === undefined) {
      return;
    }
    const target: boolean = !this.favorite;
    const result = await this.toggleFavorite.execute(this.manga.id, target);
    if (result.ok) {
      this.favorite = target;
      promptAction.showToast({ message: target ? '已加入书架' : '已移出书架' });
    } else {
      promptAction.showToast({ message: result.error !== undefined ? result.error.message : '操作失败' });
    }
  }

  @Builder
  chapterRow(chapter: Chapter) {
    Row() {
      Column() {
        Text(chapter.name)
          .fontSize(15)
          .fontColor(chapter.read ? '#9A9AA0' : '#1A1A1A')
          .width('100%')
        Text(`${chapter.scanlator} · 第 ${chapter.chapterNumber} 话`)
          .fontSize(11)
          .fontColor('#9A9AA0')
          .width('100%')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (chapter.bookmark) {
        Text('书签')
          .fontSize(11)
          .fontColor('#3F6BD8')
          .border({ width: 1, color: '#3F6BD8', radius: 4 })
          .padding({ left: 4, right: 4, top: 1, bottom: 1 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .onClick(() => {
      promptAction.showToast({ message: `阅读器待实现（M3）：${chapter.name}` });
    })
  }

  @Builder
  body() {
    Scroll() {
      Column() {
        Row() {
          Stack() {
            Text(this.manga !== undefined ? this.manga.title.substring(0, 1) : '?')
              .fontSize(44)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Bold)
          }
          .width(100)
          .height(140)
          .borderRadius(10)
          .linearGradient({
            angle: 135,
            colors: [['#5B8DEF', 0.0], ['#2B2B33', 1.0]]
          })

          Column() {
            Text(this.manga !== undefined ? this.manga.title : '')
              .fontSize(19)
              .fontWeight(FontWeight.Bold)
              .width('100%')
            Text(this.manga !== undefined ? this.manga.author : '')
              .fontSize(13)
              .fontColor('#8A8A8E')
              .width('100%')
              .margin({ top: 6 })
            Text(this.manga !== undefined ? this.manga.sourceId : '')
              .fontSize(11)
              .fontColor('#3F6BD8')
              .width('100%')
              .margin({ top: 6 })

            Row() {
              Button('开始阅读')
                .fontSize(13)
                .height(32)
                .layoutWeight(1)
                .onClick(() => {
                  promptAction.showToast({ message: '阅读器待实现（M3）' });
                })
              Button(this.favorite ? '移出书架' : '加入书架')
                .fontSize(13)
                .height(32)
                .layoutWeight(1)
                .margin({ left: 8 })
                .backgroundColor(this.favorite ? '#E8E8EC' : '#3F6BD8')
                .fontColor(this.favorite ? '#1A1A1A' : '#FFFFFF')
                .onClick(() => {
                  this.onToggleFavorite();
                })
            }
            .width('100%')
            .margin({ top: 14 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .padding({ left: 14 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 12 })

        Text(this.manga !== undefined ? this.manga.description : '')
          .fontSize(13)
          .lineHeight(20)
          .fontColor('#4A4A50')
          .maxLines(this.expanded ? 20 : 3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            this.expanded = !this.expanded;
          })

        Row() {
          Text(`章节 (${this.chapters.length})`).fontSize(15).fontWeight(FontWeight.Medium)
          Blank()
          Text('倒序').fontSize(12).fontColor('#3F6BD8')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 18, bottom: 6 })

        ForEach(this.chapters, (chapter: Chapter) => {
          this.chapterRow(chapter)
        }, (chapter: Chapter) => chapter.id.toString())
      }
      .width('100%')
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回')
          .fontSize(15)
          .fontColor('#3F6BD8')
          .onClick(() => {
            router.back();
          })
        Blank()
        Text('详情').fontSize(15).fontWeight(FontWeight.Medium)
        Blank()
        Text('⋯').fontSize(16).fontColor('#3F6BD8')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      if (this.loading) {
        Column() {
          LoadingProgress().width(36).height(36).color('#3F6BD8')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.errorMessage.length > 0) {
        Column() {
          Text(this.errorMessage).fontSize(14).fontColor('#E5484D')
          Button('重试').fontSize(13).height(32).margin({ top: 12 }).onClick(() => {
            this.load();
          })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        this.body()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
