<!-- TEMPLATE_INIT_START -->
# locale-miniapp--boilerplate

Template para crear nuevas mini-apps de Locale. **No clones esto directo: usá "Use this template" desde GitHub.**

## Cómo usar este template

1. En GitHub: clickeá **"Use this template" → Create a new repository**. Nombre sugerido: `locale-miniapp--<id>` (ej. `locale-miniapp--eventos`).
2. Cloná el repo nuevo y entrá a la carpeta:
   ```bash
   git clone git@github.com:locale-labs/locale-miniapp--<id>.git
   cd locale-miniapp--<id>
   ```
3. Corré el script de inicialización:
   ```bash
   bash scripts/init-template.sh
   ```
   Te va a pedir id, nombre, descripción, slug y package name. Reemplaza placeholders en todos los archivos y se elimina solo.
4. `bun install`.
5. Seguí la sección **"Setup desde cero"** del README generado.

## Qué trae este boilerplate

- `src/` — Alpine.js + Tailwind, integración con `@locale-labs/miniapp-sdk`, una vista "home" con feature ejemplo `items` (CRUD básico contra la tabla del mismo nombre).
- `supabase/` — `config.toml`, edge function `deploy_miniapp` (registra versión en core), `_shared/` con CORS y helpers, migration `0001_init.sql` con tabla `items` + RLS.
- `.github/workflows/` — `deploy-dev.yml`, `deploy-prod.yml`, `release.yml` (semantic-release).
- `init-config/DEV_GATE.md` — patrón opcional de password gate para el proyecto Supabase de dev.
- `Makefile`, `tsconfig.json`, `tailwind`, `eslint`, `prettier`, `.releaserc.json`, husky hooks, etc.

## Qué NO trae (lo agregás vos)

- Migraciones de tu dominio (en `supabase/migrations/`).
- Edge functions específicas (`supabase/functions/<tu-funcion>/`).
- Vistas y features adicionales (en `src/features/` y `src/html/`).
- Keypair ES256 + registro en `locale-core` (paso manual, ver DEPLOY.md).

<!-- TEMPLATE_INIT_END -->

# {{MINIAPP_NAME}}

{{MINIAPP_DESCRIPTION}}

## Stack

- **UI:** Alpine.js + Tailwind
- **Bridge:** [`@locale-labs/miniapp-sdk`](https://www.npmjs.com/package/@locale-labs/miniapp-sdk)
- **Backend:** Supabase (Postgres + Edge Functions)
- **Build:** [`@locale-labs/miniapp-builder`](https://www.npmjs.com/package/@locale-labs/miniapp-builder) (esbuild + tailwind + inyección del SDK)

## Estructura

```
src/
  alpine.ts                    # entry: instancia LocaleApp e inicializa Alpine stores
  features/
    items/                     # feature ejemplo (Hello World) — reemplazá por las tuyas
  html/index.html              # plantilla principal
  utils/                       # logger + fetch autenticado
  supabase-config-data.ts      # config Supabase mutable (kernel inyecta en runtime)
supabase/
  migrations/0001_init.sql     # tabla `items` + RLS (ejemplo)
  functions/deploy_miniapp/    # edge function que registra versiones en el core
  functions/_shared/           # helpers CORS, errors, client
init-config/
  DEV_GATE.md                  # opcional: password gate para dev
```

## Quickstart

```bash
bun install
bun run dev          # html watch + esbuild + tailwind
bun run dev:local    # apunta al SDK linkeado en ../locale-miniapp-sdk/dist/sdk.js
```

## Build & deploy

```bash
bun run build          # genera build/index.html (single-file artifact)
make deploy-dev        # deploya supabase functions + sube el HTML al storage
make deploy-prod
```

`deploy` requiere `.env.dev` o `.env.prod` (copiar desde `.env.dev.example` / `.env.prod.example`).

GitHub Actions deploya automático: push a `dev` → dev, merge a `main` → semantic-release + prod. Ver [`DEPLOY.md`](./DEPLOY.md).

### Secrets de GitHub

| Secret | Para qué |
|---|---|
| `DEV_MINIAPP_SUPABASE_URL` / `PROD_...` | URL del Supabase del miniapp |
| `DEV_MINIAPP_SUPABASE_ANON_PUBLIC` / `PROD_...` | anon key |
| `DEV_MINIAPP_SUPABASE_PROJECT_ID` / `PROD_...` | project ref |
| `DEV_MINIAPP_DEPLOY_SECRET` / `PROD_...` | autoriza el deploy contra el kernel |
| `DEV_MINIAPP_API_KEY` / `PROD_...` | guardado en edge functions |
| `DEV_MINIAPP_SUPABASE_ACCESS_TOKEN` / `PROD_...` | CLI de Supabase |
| `CORE_DEV_SUPABASE_URL` / `CORE_PROD_...` | URL del core (compartido entre mini-apps) |
| `CORE_DEV_SUPABASE_ANON_PUBLIC` / `CORE_PROD_...` | anon key del core |
| `MINIAPP_SLUG` | slug del miniapp (igual que `miniApp.id` en `package.json`) |
| `MINIAPP_NAME` | nombre visible del miniapp |

## Setup desde cero

1. **Crear proyecto Supabase** dedicado para esta mini-app (dashboard de Supabase, org de Locale).
2. **Copiar credenciales** a `.env.dev` (URL, anon, project_id, access_token).
3. **Aplicar migrations**:
   ```bash
   bunx supabase link --project-ref $MINIAPP_SUPABASE_PROJECT_ID
   bunx supabase db push
   ```
4. **(Opcional) Aplicar [`init-config/DEV_GATE.md`](./init-config/DEV_GATE.md)** si querés password gate para dev.
5. **Generar keypair ES256** y registrar el miniapp en `locale-core` (ver DEPLOY.md sección "Auth setup").
6. **Configurar JWKS** en el Supabase del miniapp para validar tokens del core.
7. **Cargar secrets en GitHub Actions** (ver tabla arriba).
8. **Primer push a `dev`** → deploy automático → validar en `dev.locale.com.ar/{{MINIAPP_ID}}?mini-app-dev-mode=true`.
