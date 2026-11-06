import { Source, SManga } from '../source/Source';
import { SourceRegistry } from '../source/SourceRegistry';
import { AppError, fail, Result } from '../util/Result';

/** 用例：在内置源里按关键字搜索（分页）。 */
export class SearchManga {
  async execute(sourceId: string, query: string, page: number): Promise<Result<SManga[]>> {
    const source: Source | undefined = SourceRegistry.get(sourceId);
    if (source === undefined) {
      return fail<SManga[]>(AppError.network('图源不存在: ' + sourceId));
    }
    if (query.trim().length === 0) {
      return fail<SManga[]>(AppError.network('搜索关键字为空'));
    }
    return source.search(query.trim(), page);
  }
}
