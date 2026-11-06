import { http } from '@kit.NetworkKit';
import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { AppContext } from './AppContext';
import { AppError, Result, ok, fail } from '../util/Result';
import { Logger } from '../util/Logger';

function safeUrl(url: string): string {
  const q: number = url.indexOf('?');
  if (q >= 0) {
    return url.substring(0, q);
  }
  return url;
}

function fnv1aHex(input: string): string {
  let hash: number = 0x811c9dc5;
  for (let i = 0; i < input.length; i++) {
    hash = (hash ^ input.charCodeAt(i)) >>> 0;
    const low: number = hash & 0xffff;
    const high: number = (hash >>> 16) & 0xffff;
    const product: number = ((high * 16777619) & 0xffff) * 65536 + low * 16777619;
    hash = product % 4294967296;
  }
  return hash.toString(16);
}

export class ImageLoader {
  private static instance: ImageLoader | undefined = undefined;
  private static readonly MAX_MEMORY: number = 40;
  private memory: Map<string, image.PixelMap> = new Map<string, image.PixelMap>();

  static get(): ImageLoader {
    if (ImageLoader.instance === undefined) {
      ImageLoader.instance = new ImageLoader();
    }
    return ImageLoader.instance;
  }

  async load(url: string, targetWidth: number): Promise<Result<image.PixelMap>> {
    const cached: image.PixelMap | undefined = this.memory.get(url);
    if (cached !== undefined) {
      this.touch(url);
      return ok<image.PixelMap>(cached);
    }
    const path: string = this.diskPath(url);
    let buf: ArrayBuffer | undefined = undefined;
    if (this.exists(path)) {
      buf = this.readDisk(path);
    }
    if (buf === undefined) {
      const downloaded: Result<ArrayBuffer> = await this.download(url);
      const data: ArrayBuffer | undefined = downloaded.data;
      if (!downloaded.ok || data === undefined) {
        return fail<image.PixelMap>(this.downloadError(downloaded, url));
      }
      buf = data;
      this.writeDisk(path, buf);
    }
    const decoded: Result<image.PixelMap> = await this.decode(url, buf, targetWidth);
    if (decoded.ok && decoded.data !== undefined) {
      this.putMemory(url, decoded.data);
    }
    return decoded;
  }

  async clearMemory(): Promise<void> {
    this.memory.forEach((pm: image.PixelMap) => {
      pm.release();
    });
    this.memory.clear();
  }

  async clearDisk(): Promise<void> {
    const dir: string = this.cacheDir();
    if (!this.exists(dir)) {
      return;
    }
    try {
      const names = fileIo.listFileSync(dir);
      for (const name of names) {
        try {
          fileIo.unlinkSync(dir + '/' + name);
        } catch (error) {
          Logger.warn('ImageLoader', 'disk cache delete failed for %{public}s', name);
        }
      }
    } catch (error) {
      Logger.warn('ImageLoader', 'disk cache list failed for %{public}s', dir);
    }
  }

  private cacheDir(): string {
    return AppContext.require().cacheDir + '/covers';
  }

  private exists(path: string): boolean {
    try {
      return fileIo.accessSync(path);
    } catch (error) {
      return false;
    }
  }

  private diskPath(url: string): string {
    return this.cacheDir() + '/' + fnv1aHex(url) + '.img';
  }

  private downloadError(result: Result<ArrayBuffer>, url: string): AppError {
    if (result.error !== undefined) {
      return result.error;
    }
    return AppError.network('image download failed for ' + safeUrl(url));
  }

  private async download(url: string): Promise<Result<ArrayBuffer>> {
    const req: http.HttpRequest = http.createHttp();
    try {
      const header: Record<string, string> = { 'User-Agent': 'Komikku/0.1.0 (HarmonyOS)' };
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: header,
        connectTimeout: 15000,
        readTimeout: 20000,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      };
      const resp: http.HttpResponse = await req.request(url, options);
      if (resp.responseCode < 200 || resp.responseCode >= 300) {
        Logger.warn('ImageLoader', 'download http status %{public}d for %{public}s', resp.responseCode, safeUrl(url));
        return fail<ArrayBuffer>(
          AppError.network('image download failed: http status ' + resp.responseCode + ' for ' + safeUrl(url)));
      }
      const raw = resp.result;
      if (!(raw instanceof ArrayBuffer)) {
        Logger.warn('ImageLoader', 'unexpected response body for %{public}s', safeUrl(url));
        return fail<ArrayBuffer>(AppError.network('image download failed: unexpected response body for ' + safeUrl(url)));
      }
      return ok<ArrayBuffer>(raw);
    } catch (error) {
      const detail: string = error instanceof Error ? error.message : 'unknown';
      Logger.warn('ImageLoader', 'download failed for %{public}s: %{public}s', safeUrl(url), detail);
      return fail<ArrayBuffer>(AppError.network('image download failed for ' + safeUrl(url)));
    } finally {
      req.destroy();
    }
  }

  private async decode(url: string, buf: ArrayBuffer, targetWidth: number): Promise<Result<image.PixelMap>> {
    try {
      const source: image.ImageSource = image.createImageSource(buf);
      if (targetWidth <= 0) {
        const original: image.PixelMap = await source.createPixelMap();
        return ok<image.PixelMap>(original);
      }
      const info: image.ImageInfo = await source.getImageInfo();
      const w: number = info.size.width;
      const h: number = info.size.height;
      const opts: image.DecodingOptions = { desiredSize: { width: targetWidth, height: Math.round(h * targetWidth / w) } };
      const pm: image.PixelMap = await source.createPixelMap(opts);
      return ok<image.PixelMap>(pm);
    } catch (error) {
      const detail: string = error instanceof Error ? error.message : 'unknown';
      Logger.warn('ImageLoader', 'decode failed for %{public}s: %{public}s', safeUrl(url), detail);
      return fail<image.PixelMap>(AppError.parse('image decode failed for ' + safeUrl(url)));
    }
  }

  private readDisk(path: string): ArrayBuffer | undefined {
    try {
      const rf = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      const st = fileIo.statSync(path);
      const out: ArrayBuffer = new ArrayBuffer(st.size);
      fileIo.readSync(rf.fd, out);
      fileIo.closeSync(rf);
      return out;
    } catch (error) {
      Logger.warn('ImageLoader', 'disk cache read failed for %{public}s', path);
      return undefined;
    }
  }

  private writeDisk(path: string, buf: ArrayBuffer): void {
    try {
      const dir: string = this.cacheDir();
      if (!fileIo.accessSync(dir)) {
        fileIo.mkdirSync(dir);
      }
      const wf = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
      fileIo.writeSync(wf.fd, buf);
      fileIo.closeSync(wf);
    } catch (error) {
      Logger.warn('ImageLoader', 'disk cache write failed for %{public}s', path);
    }
  }

  private touch(key: string): void {
    const pm: image.PixelMap | undefined = this.memory.get(key);
    if (pm === undefined) {
      return;
    }
    this.memory.delete(key);
    this.memory.set(key, pm);
  }

  private putMemory(key: string, pm: image.PixelMap): void {
    const existing: image.PixelMap | undefined = this.memory.get(key);
    if (existing !== undefined) {
      existing.release();
    }
    this.memory.delete(key);
    this.memory.set(key, pm);
    while (this.memory.size > ImageLoader.MAX_MEMORY) {
      this.evictOldest();
    }
  }

  private evictOldest(): void {
    let oldest: string | undefined = undefined;
    this.memory.forEach((value: image.PixelMap, key: string) => {
      if (oldest === undefined) {
        oldest = key;
      }
    });
    if (oldest === undefined) {
      return;
    }
    const pm: image.PixelMap | undefined = this.memory.get(oldest);
    this.memory.delete(oldest);
    if (pm !== undefined) {
      pm.release();
    }
  }
}
