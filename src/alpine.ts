import Alpine from 'alpinejs';
import { createItemsStore } from './features/items';
import { logger, logError, logWarn } from './utils/logger';

import {
  LocaleApp,
  type UserPayload,
  type LocationPayload,
} from '@locale-labs/miniapp-sdk';
import { setMiniappConfig } from './supabase-config-data';

type LocaleUser = UserPayload;
type LocaleLocation = LocationPayload;

interface AppState {
  app: LocaleApp | null;
  isReady: boolean;

  toast: {
    show: boolean;
    message: string;
    type: 'info' | 'success' | 'warning' | 'error';
  };

  user: LocaleUser | null;
  location: LocaleLocation | null;
  token: string | null;

  items: ReturnType<typeof createItemsStore>;

  version: string;

  init(): Promise<void>;
  showToast(message: string, type?: 'info' | 'success' | 'warning' | 'error'): void;
  requireLogin(intendedView?: string): void;
}

declare global {
  interface Window {
    LocaleApp: typeof LocaleApp;
    miniApp: () => AppState;
  }
}

export function miniApp(): AppState {
  return {
    app: null,
    isReady: false,

    toast: {
      show: false,
      message: '',
      type: 'info',
    },

    user: null,
    location: null,
    token: null,

    items: createItemsStore(),

    version: process.env.MINIAPP_VERSION || 'dev',

    async init() {
      try {
        if (typeof window.LocaleApp !== 'function') {
          logWarn('⚠️ Locale SDK not found (Dev mode?)');
          this.isReady = true;
          return;
        }

        this.app = new window.LocaleApp();
        const { user, location, token, miniappConfig } = await this.app.init();

        if (miniappConfig?.supabaseUrl && miniappConfig?.supabaseAnonKey) {
          setMiniappConfig(miniappConfig.supabaseUrl, miniappConfig.supabaseAnonKey);
          logger('🔧 Runtime Supabase config from kernel applied');
        } else {
          logger('⚠️ No runtime Supabase config from kernel, using build-time fallback');
        }

        this.user = user;
        this.location = location;
        this.token = token;

        logger('🚀 MiniApp initialized:', {
          userId: user?.id,
          placeId: user?.place_id,
          hasToken: !!this.token,
        });

        this.isReady = true;

        this.items.load(this.token, this.user?.place_id);
      } catch (err) {
        logError('❌ Init error:', err);
        this.isReady = true;
      }
    },

    showToast(message: string, type: 'info' | 'success' | 'warning' | 'error' = 'info') {
      this.toast.message = message;
      this.toast.type = type;
      this.toast.show = true;
      setTimeout(() => {
        this.toast.show = false;
      }, 3000);
    },

    requireLogin(intendedView = 'home') {
      const isGuest = !this.user || this.user.id === 'guest';
      if (!isGuest) return;

      this.app?.login(intendedView).catch((err) => {
        logError('Login redirect failed:', err);
        this.showToast('Error al redirigir al login', 'error');
      });
    },
  };
}

window.miniApp = miniApp;
Alpine.start();
