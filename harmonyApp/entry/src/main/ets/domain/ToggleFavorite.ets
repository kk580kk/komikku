import { MangaRepository } from '../data/MangaRepository';
import { Result } from '../util/Result';

/** 用例：加入/移出书架。 */
export class ToggleFavorite {
  private repo: MangaRepository = new MangaRepository();

  async execute(mangaId: number, favorite: boolean): Promise<Result<void>> {
    return this.repo.setFavorite(mangaId, favorite);
  }
}
