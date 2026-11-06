import { promptAction, router } from '@kit.ArkUI';
import { LibraryRepository } from '../data/LibraryRepository';
import { Chapter, Manga, MangaDetailParams } from '../model/Manga';

@Entry
@Component
struct MangaDetailPage {
  @State manga: Manga | undefined = undefined;
  @State chapters: Chapter[] = [];
  @State expanded: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as MangaDetailParams;
    this.manga = LibraryRepository.findById(params.mangaId);
    this.chapters = LibraryRepository.listChapters(params.mangaId);
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
        Text('详情')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text('⋯')
          .fontSize(16)
          .fontColor('#3F6BD8')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

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
              Text(this.manga !== undefined ? this.manga.sourceName : '')
                .fontSize(11)
                .fontColor('#3F6BD8')
                .width('100%')
                .margin({ top: 6 })
              Button('开始阅读')
                .fontSize(13)
                .height(32)
                .margin({ top: 14 })
                .onClick(() => {
                  promptAction.showToast({ message: '阅读器待实现（M3）' });
                })
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
            Text('排序').fontSize(12).fontColor('#3F6BD8')
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
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
