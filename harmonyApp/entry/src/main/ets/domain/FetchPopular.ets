import { Source, SManga } from '../source/Source';
import { SourceRegistry } from '../source/SourceRegistry';
import { AppError, fail, Result } from '../util/Result';

/** 用例：拉取内置源的热门列表（分页）。 */
export class FetchPopular {
  async execute(sourceId: string, page: number): Promise<Result<SManga[]>> {
    const source: Source | undefined = SourceRegistry.get(sourceId);
    if (source === undefined) {
      return fail<SManga[]>(AppError.network('图源不存在: ' + sourceId));
    }
    return source.popular(page);
  }
}
