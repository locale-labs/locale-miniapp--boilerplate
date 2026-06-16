<!-- TEMPLATE_INIT_START -->
# locale-miniapp--boilerplate

Template para crear nuevas mini-apps de Locale. **No clones esto directo: usá "Use this template" desde GitHub.**

## Cómo usar este template

> 👋 **¿Es tu primera mini-app de Locale?** Leé [`FIRST_STEPS.md`](./FIRST_STEPS.md) — guía paso a paso amigable, desde clonar hasta tener la app deployada en prod.

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
5. Seguí [`FIRST_STEPS.md`](./FIRST_STEPS.md) para terminar el setup.

## Qué trae este boilerplate

- `src/` — Alpine.js + Tailwind, integración con `@locale-labs/miniapp-sdk`, feature ejemplo `items` (CRUD básico).
- `supabase/` — `config.toml`, edge function `deploy_miniapp`, `_shared/` con CORS y helpers, migration `0001_init.sql` con tabla `items` + RLS.
- `.github/workflows/` — `deploy-dev.yml`, `deploy-prod.yml`, `release.yml` (semantic-release).
- `init-config/DEV_GATE.md` — patrón opcional de password gate para el proyecto Supabase de dev.
- `Makefile`, `tsconfig.json`, `tailwind`, `eslint`, `prettier`, `.releaserc.json`, husky hooks, etc.

<!-- TEMPLATE_INIT_END -->

# {{MINIAPP_NAME}}

{{MINIAPP_DESCRIPTION}}

> **Agente / contexto técnico:** [`NOTES/LEARNINGS.md`](./NOTES/LEARNINGS.md) — boundaries, gotchas, conexiones con otros repos, release flow.
> **Setup paso a paso para humanos:** [`FIRST_STEPS.md`](./FIRST_STEPS.md).

## Stack

- **UI:** Alpine.js + Tailwind
- **Bridge:** [`@locale-labs/miniapp-sdk`](https://www.npmjs.com/package/@locale-labs/miniapp-sdk)
- **Backend:** Supabase (Postgres + Edge Functions)
- **Build:** [`@locale-labs/miniapp-builder`](https://www.npmjs.com/package/@locale-labs/miniapp-builder)

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

## Probar local sin deployar (Local Preview)

Para iterar sin esperar un deploy, podés correr tu `build/index.html` local dentro
de Localé real (prod):

1. Dejá corriendo `bun run dev` (regenera `build/index.html` en cada guardado).
2. Logueado con un email habilitado, abrí **`https://locale.com.ar/miniapp-preview-dev`**.
3. Elegí tu mini-app y seleccioná tu `build/index.html` (corre contra el backend prod).
4. Editás → guardás → la preview se recarga sola.

> Requiere navegador con File System Access API (Chrome / Edge) y que tu email esté
> en la allowlist del Core. Pedí acceso al equipo de Localé. El archivo nunca se sube:
> lo lee el navegador y lo inyecta en el iframe (sandbox) del slug real.

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

> 👋 Si es tu primera mini-app, seguí [`FIRST_STEPS.md`](./FIRST_STEPS.md) en lugar de esta lista resumida.

1. **Crear proyecto Supabase** dedicado para esta mini-app (dashboard de Supabase, org de Locale).
2. **Copiar credenciales** a `.env.dev` (URL, anon, project_id, access_token).
3. **Aplicar migrations**:
   ```bash
   bunx supabase link --project-ref $MINIAPP_SUPABASE_PROJECT_ID
   bunx supabase db push
   ```
4. **(Opcional) Aplicar [`NOTES/init-config/DEV_GATE.md`](./NOTES/init-config/DEV_GATE.md)** si querés password gate para dev.
5. **Generar keypair ES256** y registrar el miniapp en `locale-core` (ver DEPLOY.md sección "Auth setup").
6. **Configurar JWKS** en el Supabase del miniapp para validar tokens del core.
7. **Cargar secrets en GitHub Actions** (ver tabla arriba).
8. **Primer push a `dev`** → deploy automático → validar en `dev.locale.com.ar/{{MINIAPP_ID}}?mini-app-dev-mode=true`.
