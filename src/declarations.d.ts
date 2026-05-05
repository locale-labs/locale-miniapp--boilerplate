declare module 'alpinejs';

declare const process: {
  env: {
    MINIAPP_VERSION: string;
    MINIAPP_SUPABASE_URL: string;
    MINIAPP_SUPABASE_ANON_PUBLIC: string;
  };
};
