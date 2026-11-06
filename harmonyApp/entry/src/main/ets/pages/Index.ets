import { router } from '@kit.ArkUI';
import { LibraryRepository } from '../data/LibraryRepository';
import { Manga, MangaDetailParams } from '../model/Manga';

@Entry
@Component
struct Index {
  @State mangas: Manga[] = LibraryRepository.listLibrary();
  @State activeTab: number = 0;
  private coverColors: string[] = ['#5B8DEF', '#E8734A', '#48A88A', '#9B6BD6', '#D46A8E', '#C9A227'];

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
  mangaCard(manga: Manga, index: number) {
    Column() {
      Stack() {
        Text(manga.title.substring(0, 1))
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

      Text(manga.title)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 6 })
        .width('100%')

      Text(manga.unreadCount > 0 ? `${manga.unreadCount} 话未读` : '已读完')
        .fontSize(11)
        .fontColor(manga.unreadCount > 0 ? '#3F6BD8' : '#8A8A8E')
        .margin({ top: 2 })
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      router.pushUrl({ url: 'pages/MangaDetailPage', params: new MangaDetailParams(manga.id) });
    })
  }

  @Builder
  bookshelf() {
    Column() {
      Row() {
        Text('书架').fontSize(26).fontWeight(FontWeight.Bold)
        Blank()
        Text(`${this.mangas.length} 部`).fontSize(13).fontColor('#8A8A8E')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 10 })

      Grid() {
        ForEach(this.mangas, (manga: Manga, index: number) => {
          GridItem() {
            this.mangaCard(manga, index)
          }
        }, (manga: Manga) => manga.id.toString())
      }
      .columnsTemplate('1fr 1fr 1fr')
      .columnsGap(12)
      .rowsGap(18)
      .padding({ left: 16, right: 16, bottom: 12 })
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  browse() {
    Column() {
      Text('浏览').fontSize(26).fontWeight(FontWeight.Bold).width('100%')
        .padding({ left: 16, right: 16, top: 14 })
      Text('内置图源（MangaDex / E-Hentai / NHentai …）在 M1 接入')
        .fontSize(13)
        .fontColor('#8A8A8E')
        .width('100%')
        .padding({ left: 16, right: 16, top: 8 })
      Blank()
      Text('尚未接入图源')
        .fontSize(14)
        .fontColor('#B0B0B5')
      Blank()
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  more() {
    Column() {
      Text('更多').fontSize(26).fontWeight(FontWeight.Bold).width('100%')
        .padding({ left: 16, right: 16, top: 14 })
      this.settingRow('扩展与图源', '内置源，M1 接入')
      this.settingRow('下载', '未实现')
      this.settingRow('备份与恢复', '未实现')
      this.settingRow('关于', 'Komikku HarmonyOS 0.1.0')
      Blank()
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  settingRow(title: string, subtitle: string) {
    Row() {
      Column() {
        Text(title).fontSize(15).width('100%')
        Text(subtitle).fontSize(12).fontColor('#8A8A8E').width('100%').margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
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
    })
    .backgroundColor('#F5F5F7')
    .width('100%')
    .height('100%')
  }
}
