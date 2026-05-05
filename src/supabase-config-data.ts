// Config mutable — en runtime el kernel sobreescribe los valores bakeados
export const miniappConfig = {
  supabaseUrl: process.env.MINIAPP_SUPABASE_URL ?? '',
  supabaseAnonKey: process.env.MINIAPP_SUPABASE_ANON_PUBLIC ?? '',
};

/** Llamado por alpine.ts al recibir LOCALE_INIT del kernel */
export function setMiniappConfig(url: string, anonKey: string): void {
  miniappConfig.supabaseUrl = url;
  miniappConfig.supabaseAnonKey = anonKey;
}
