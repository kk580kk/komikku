import { promptAction, router } from '@kit.ArkUI';
import { fileIo } from '@kit.CoreFileKit';
import { DownloadRepository } from '../data/DownloadRepository';
import { ImageLoader } from '../service/ImageLoader';
import { Downloader } from '../service/Downloader';
import { AppContext } from '../service/AppContext';
import { Logger } from '../util/Logger';

/** 设置页：缓存与下载管理（MVP 只做这两块）。 */
@Entry
@Component
struct SettingsPage {
  @State cacheText: string = '计算中…';
  @State downloadText: string = '计算中…';
  @State busy: boolean = false;

  private downloadRepo: DownloadRepository = new DownloadRepository();

  aboutToAppear(): void {
    this.refresh();
  }

  private dirSize(path: string): number {
    let total: number = 0;
    try {
      if (!fileIo.accessSync(path)) {
        return 0;
      }
      const names: string[] = fileIo.listFileSync(path);
      for (const name of names) {
        const child: string = path + '/' + name;
        const stat = fileIo.statSync(child);
        total += stat.isDirectory() ? this.dirSize(child) : stat.size;
      }
    } catch (e) {
      Logger.warn('settings', 'dirSize failed: %{public}s', JSON.stringify(e));
    }
    return total;
  }

  private human(bytes: number): string {
    if (bytes < 1024) {
      return bytes + ' B';
    }
    if (bytes < 1024 * 1024) {
      return (bytes / 1024).toFixed(1) + ' KB';
    }
    return (bytes / 1024 / 1024).toFixed(1) + ' MB';
  }

  private refresh(): void {
    const covers: number = this.dirSize(AppContext.require().cacheDir + '/covers');
    const downloads: number = this.dirSize(AppContext.require().filesDir + '/downloads');
    this.cacheText = this.human(covers);
    this.downloadText = this.human(downloads);
  }

  private async clearCovers(): Promise<void> {
    this.busy = true;
    await ImageLoader.get().clearMemory();
    await ImageLoader.get().clearDisk();
    this.busy = false;
    promptAction.showToast({ message: '图片缓存已清理' });
    this.refresh();
  }

  private async clearDownloads(): Promise<void> {
    this.busy = true;
    await this.downloadRepo.clearAll();
    const root: string = AppContext.require().filesDir + '/downloads';
    try {
      if (fileIo.accessSync(root)) {
        fileIo.rmdirSync(root);
      }
    } catch (e) {
      Logger.warn('settings', 'clear downloads failed: %{public}s', JSON.stringify(e));
    }
    this.busy = false;
    promptAction.showToast({ message: '下载内容已清理' });
    this.refresh();
  }

  @Builder
  section(title: string) {
    Text(title)
      .fontSize(13)
      .fontColor('#8A8A8E')
      .width('100%')
      .padding({ left: 16, right: 16, top: 18, bottom: 6 })
  }

  @Builder
  row(title: string, value: string, action: string, run: () => void) {
    Row() {
      Column() {
        Text(title).fontSize(15).width('100%')
        Text(value).fontSize(12).fontColor('#8A8A8E').margin({ top: 2 }).width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button(action)
        .fontSize(12)
        .height(30)
        .backgroundColor('#E8E8EC')
        .fontColor('#1A1A1A')
        .enabled(!this.busy)
        .onClick(() => {
          run();
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回').fontSize(15).fontColor('#3F6BD8').onClick(() => {
          router.back();
        })
        Blank()
        Text('设置').fontSize(15).fontWeight(FontWeight.Medium)
        Blank()
        Text(' ').fontSize(15)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Scroll() {
        Column() {
          this.section('存储')
          this.row('图片缓存', this.cacheText, '清理', () => {
            this.clearCovers();
          })
          this.row('下载内容', this.downloadText, '全部删除', () => {
            this.clearDownloads();
          })

          this.section('关于')
          this.row('应用', 'Komikku HarmonyOS 0.1.0', '', () => {})
          this.row('图源', '内置 MangaDex', '', () => {})
          this.row('构建', 'DevEco 26.0.0 / API 26', '', () => {})
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F7')
  }
}
