import { relationalStore } from '@kit.ArkData';
import { Chapter, Manga } from '../model/Manga';

class MangaRow {
  title: string;
  author: string;
  artist: string;
  description: string;
  unreadCount: number;

  constructor(title: string, author: string, artist: string, description: string, unreadCount: number) {
    this.title = title;
    this.author = author;
    this.artist = artist;
    this.description = description;
    this.unreadCount = unreadCount;
  }
}

/**
 * 首启种子数据。
 *
 * 目的：M1 阶段没有图源，书架先有内容可验证 UI 与滚动性能。
 * M2 接入 MangaDex 后，种子数据只保留在 debug 构建（后续用 buildProfile 区分）。
 */
export class Seed {
  private static readonly MANGA_ROWS: MangaRow[] = [
    new MangaRow('葬送的芙莉莲', '山田钟人', 'アベツカサ', '魔王讨伐结束后，精灵魔法使芙莉莲重走旅途的故事。', 3),
    new MangaRow('迷宫饭', '九井谅子', '九井谅子', '在地下城迷宫里把魔物做成料理的冒险。', 0),
    new MangaRow('辉夜大小姐想让我告白', '赤坂明', '赤坂明', '学生会的两位天才互相算计，只想让对方先告白。', 12),
    new MangaRow('孤独摇滚！', '滨路晶', '滨路晶', '社恐少女组建乐队的日常。', 1),
    new MangaRow('蓝色时期', '山口亮', '山口亮', '以东京艺术大学为目标的绘画青春物语。', 5),
    new MangaRow('关于我转生变成史莱姆这档事', '伏濑', '川上泰树', '转生为史莱姆，在异世界建立魔物之国。', 0),
  ];

  private static readonly MANGA_TITLES: string[] = [
    '葬送的芙莉莲', '迷宫饭', '辉夜大小姐想让我告白', '孤独摇滚！', '蓝色时期', '关于我转生变成史莱姆这档事',
  ];

  static async ensure(store: relationalStore.RdbStore): Promise<void> {
    const resultSet: relationalStore.ResultSet = await store.querySql('SELECT COUNT(*) AS c FROM mangas', []);
    let count: number = 0;
    if (resultSet.goToFirstRow()) {
      count = resultSet.getLong(resultSet.getColumnIndex('c'));
    }
    resultSet.close();
    if (count > 0) {
      return;
    }

    const now: number = Date.now();
    for (let i = 0; i < Seed.MANGA_ROWS.length; i++) {
      const row: MangaRow = Seed.MANGA_ROWS[i];
      const bucket: relationalStore.ValuesBucket = {
        source_id: 'seed',
        url: `seed://manga/${i + 1}`,
        title: row.title,
        author: row.author,
        artist: row.artist,
        description: row.description,
        genre: '[]',
        status: 0,
        thumbnail_url: '',
        favorite: 1,
        viewer: 0,
        date_added: now,
        last_update: now,
        notes: ''
      };
      const mangaId: number = await store.insert('mangas', bucket);
      await Seed.insertChapters(store, mangaId, row.unreadCount, now);
    }
  }

  private static async insertChapters(
    store: relationalStore.RdbStore,
    mangaId: number,
    unreadCount: number,
    now: number
  ): Promise<void> {
    const total: number = 20;
    for (let i = 1; i <= total; i++) {
      const read: boolean = i > unreadCount;
      const bucket: relationalStore.ValuesBucket = {
        manga_id: mangaId,
        url: `seed://manga/${mangaId}/chapter/${i}`,
        name: `第 ${i} 话`,
        scanlator: '汉化组',
        read: read ? 1 : 0,
        bookmark: i === 1 ? 1 : 0,
        last_page_read: 0,
        chapter_number: i,
        source_order: total - i,
        date_fetch: now,
        date_upload: now
      };
      await store.insert('chapters', bucket);
    }
  }
}
