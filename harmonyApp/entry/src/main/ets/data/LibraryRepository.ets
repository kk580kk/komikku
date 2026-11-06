import { Chapter, Manga } from '../model/Manga';

/**
 * 书架/章节的数据入口。
 *
 * 当前为内存 Mock，用于打通 UI 骨架；M2 起替换为 `@ohos.data.relationalStore` 实现，
 * 表结构与 Android 端 `data/src/main/sqldelight/tachiyomi/data/*.sq` 保持一致。
 */
export class LibraryRepository {
  private static readonly MANGA: Manga[] = [
    new Manga(1, '葬送的芙莉莲', '山田钟人', 'アベツカサ', '魔王讨伐结束后，精灵魔法使芙莉莲的旅程。',
      'MangaDex', '', 3, true),
    new Manga(2, '迷宫饭', '九井谅子', '九井谅子', '在地下城迷宫里煮魔物吃的冒险故事。',
      'MangaDex', '', 0, true),
    new Manga(3, '辉夜大小姐想让我告白', '赤坂明', '赤坂明', '学生会的两位天才互相算计让对方先告白。',
      'MangaDex', '', 12, true),
    new Manga(4, '孤独摇滚！', '滨路晶', '滨路晶', '社恐少女组建乐队的日常。',
      'MangaDex', '', 1, true),
    new Manga(5, '蓝色时期', '山口飞翔', '山口飞翔', '以东京艺术大学为目标的绘画青春物语。',
      'MangaDex', '', 5, true),
    new Manga(6, '关于我转生变成史莱姆这档事', '伏濑', '川上泰树', '转生为史莱姆，建立魔物之国。',
      'MangaDex', '', 0, true),
  ];

  static listLibrary(): Manga[] {
    return LibraryRepository.MANGA;
  }

  static findById(mangaId: number): Manga | undefined {
    return LibraryRepository.MANGA.find((item: Manga) => item.id === mangaId);
  }

  /** 章节列表同样先 Mock，后续由 source 层拉取后落库。 */
  static listChapters(mangaId: number): Chapter[] {
    const result: Chapter[] = [];
    for (let i = 1; i <= 12; i++) {
      result.push(new Chapter(mangaId * 100 + i, mangaId, `第 ${i} 话`, i, i <= 3, i === 1, '汉化组'));
    }
    return result;
  }
}
