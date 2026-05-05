import { logger, logError } from '../../utils/logger';
import { fetchItems, createItem, deleteItem } from './api';
import type { Item } from './types';

export function createItemsStore() {
  return {
    list: [] as Item[],
    isLoading: false,
    draft: '',

    async load(token: string | null, placeId?: string) {
      this.isLoading = true;
      try {
        this.list = await fetchItems(token, placeId);
        logger('📦 Loaded items:', this.list.length);
      } catch (err) {
        logError('Failed to load items:', err);
        this.list = [];
      } finally {
        this.isLoading = false;
      }
    },

    async submit(token: string | null, ownerId: string, placeId: string) {
      const content = this.draft.trim();
      if (!content) return;
      try {
        const created = await createItem(token, { owner_id: ownerId, place_id: placeId, content });
        this.list = [created, ...this.list];
        this.draft = '';
      } catch (err) {
        logError('Failed to create item:', err);
        throw err;
      }
    },

    async remove(token: string | null, id: string) {
      try {
        await deleteItem(token, id);
        this.list = this.list.filter((it) => it.id !== id);
      } catch (err) {
        logError('Failed to delete item:', err);
        throw err;
      }
    },
  };
}
