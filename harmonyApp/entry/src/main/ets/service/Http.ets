import { http } from '@kit.NetworkKit';
import { Result, AppError, ok, fail } from '../util/Result';
import { Logger } from '../util/Logger';

const TAG: string = 'http';
const DEFAULT_UA: string = 'Komikku/0.1.0 (HarmonyOS)';
const MAX_ATTEMPTS: number = 3;

export class Http {
  async request(method: string, url: string, headers?: Record<string, string>, body?: string): Promise<Result<string>> {
    if (method !== 'GET' && method !== 'POST') {
      Logger.warn(TAG, 'unsupported method');
      return fail<string>(AppError.network('unsupported method'));
    }

    const merged: Record<string, string> = Http.mergeHeaders(headers);
    let lastMessage: string = 'request failed';

    for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
      const client = http.createHttp();
      try {
        let resp: http.HttpResponse;
        if (method === 'GET') {
          resp = await client.request(url, {
            method: http.RequestMethod.GET,
            header: merged,
            connectTimeout: 15000,
            readTimeout: 15000,
            expectDataType: http.HttpDataType.STRING
          });
        } else {
          resp = await client.request(url, {
            method: http.RequestMethod.POST,
            header: merged,
            extraData: body ?? '',
            connectTimeout: 15000,
            readTimeout: 15000,
            expectDataType: http.HttpDataType.STRING
          });
        }
        const code: number = resp.responseCode;
        if (code >= 200 && code < 400) {
          Logger.info(TAG, 'request done, code=%{public}d', code);
          return ok<string>(resp.result as string);
        }
        if (code < 500) {
          Logger.warn(TAG, 'request failed, code=%{public}d', code);
          return fail<string>(AppError.network('HTTP ' + code));
        }
        lastMessage = 'HTTP ' + code;
        Logger.warn(TAG, 'server error, code=%{public}d attempt=%{public}d', code, attempt);
      } catch (error) {
        lastMessage = 'request failed';
        Logger.warn(TAG, 'request threw, attempt=%{public}d', attempt);
      } finally {
        client.destroy();
      }
      if (attempt < MAX_ATTEMPTS) {
        const waitMs: number = attempt === 1 ? 500 : 1000;
        await new Promise<void>((resolve: (value: void) => void) => {
          setTimeout(() => {
            resolve();
          }, waitMs);
        });
      }
    }
    return fail<string>(AppError.network(lastMessage));
  }

  private static mergeHeaders(headers?: Record<string, string>): Record<string, string> {
    const merged: Record<string, string> = { 'User-Agent': DEFAULT_UA };
    if (headers !== undefined) {
      const keys: Array<string> = Object.keys(headers);
      for (const key of keys) {
        if (key.toLowerCase() === 'user-agent') {
          merged['User-Agent'] = headers[key];
        } else {
          merged[key] = headers[key];
        }
      }
    }
    return merged;
  }
}
