import { image } from '@kit.ImageKit';
import { ImageLoader } from '../service/ImageLoader';

/**
 * 封面组件：优先真实封面（走 ImageLoader 缓存 + 采样解码），
 * 无 URL 或失败时回退为标题首字 + 渐变色块。
 */
@Component
export struct MangaCover {
  @Prop thumbnailUrl: string = '';
  @Prop title: string = '';
  @Prop targetWidth: number = 360;
  @Prop colorIndex: number = 0;
  @State pixelMap: image.PixelMap | undefined = undefined;

  private palette: string[] = ['#5B8DEF', '#E8734A', '#48A88A', '#9B6BD6', '#D46A8E', '#C9A227'];

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    if (this.thumbnailUrl.length === 0) {
      return;
    }
    const result = await ImageLoader.get().load(this.thumbnailUrl, this.targetWidth);
    if (result.ok && result.data !== undefined) {
      this.pixelMap = result.data;
    }
  }

  build() {
    Stack() {
      if (this.pixelMap !== undefined) {
        Image(this.pixelMap)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .draggable(false)
      } else {
        Column() {
          Text(this.title.length > 0 ? this.title.substring(0, 1) : '?')
            .fontSize(36)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .linearGradient({
          angle: 135,
          colors: [[this.palette[this.colorIndex % this.palette.length], 0.0], ['#2B2B33', 1.0]]
        })
      }
    }
    .width('100%')
    .aspectRatio(0.72)
    .borderRadius(8)
    .clip(true)
  }
}
