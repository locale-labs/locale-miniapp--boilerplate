import { authenticatedFetch } from '../../utils/fetch';
import { miniappConfig } from '../../supabase-config-data';
import type { Item } from './types';

const ITEMS_TABLE = 'items';

function restUrl(path: string): string {
  return `${miniappConfig.supabaseUrl}/rest/v1/${path}`;
}

export async function fetchItems(token: string | null, placeId?: string): Promise<Item[]> {
  const query = placeId ? `?place_id=eq.${encodeURIComponent(placeId)}&order=created_at.desc` : '?order=created_at.desc';
  const res = await authenticatedFetch(
    restUrl(`${ITEMS_TABLE}${query}`),
    token,
    { method: 'GET' },
    miniappConfig.supabaseAnonKey
  );
  if (!res.ok) throw new Error(`fetchItems failed: ${res.status}`);
  return res.json();
}

export async function createItem(
  token: string | null,
  payload: { owner_id: string; place_id: string; content: string }
): Promise<Item> {
  const res = await authenticatedFetch(
    restUrl(ITEMS_TABLE),
    token,
    {
      method: 'POST',
      headers: { Prefer: 'return=representation' },
      body: JSON.stringify(payload),
    },
    miniappConfig.supabaseAnonKey
  );
  if (!res.ok) throw new Error(`createItem failed: ${res.status} ${await res.text()}`);
  const rows = (await res.json()) as Item[];
  return rows[0];
}

export async function deleteItem(token: string | null, id: string): Promise<void> {
  const res = await authenticatedFetch(
    restUrl(`${ITEMS_TABLE}?id=eq.${encodeURIComponent(id)}`),
    token,
    { method: 'DELETE' },
    miniappConfig.supabaseAnonKey
  );
  if (!res.ok) throw new Error(`deleteItem failed: ${res.status}`);
}
