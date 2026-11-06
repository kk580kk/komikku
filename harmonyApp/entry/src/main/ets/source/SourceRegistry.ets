import { Source } from './Source';
import { MangaDexSource } from './mangadex/MangaDexSource';

/**
 * 内置源注册表。
 *
 * 鸿蒙端不支持安装扩展，所有源在编译期固定注册；后续新增源只需在这里加一行，
 * 并保证实现 `Source` 接口。
 */
export class SourceRegistry {
  private static sources: Source[] = [new MangaDexSource()];

  static all(): Source[] {
    return SourceRegistry.sources;
  }

  static get(id: string): Source | undefined {
    return SourceRegistry.sources.find((s: Source) => s.id === id);
  }
}
