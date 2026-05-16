# Learnings — locale-miniapp--boilerplate

> Primera lectura para el agente antes de tocar este repo.
> Stack / estructura / quickstart / secrets / setup desde cero: [`../README.md`](../README.md) y [`../FIRST_STEPS.md`](../FIRST_STEPS.md).
> Panorama del ecosistema: [`../../NOTES/HOW_THINGS_ARE_CONNECTED.md`](../../NOTES/HOW_THINGS_ARE_CONNECTED.md) · Auth flow: [`../../NOTES/AUTH.md`](../../NOTES/AUTH.md) · Learnings cross-repo: [`../../NOTES/LEARNINGS.md`](../../NOTES/LEARNINGS.md).

## Qué es este repo

Template para crear miniapps nuevas. Un dev (típicamente externo al core-team) lo clona, corre `scripts/init-template.sh`, reemplaza placeholders y queda con un miniapp Alpine + Tailwind listo para extender. Funciona como referencia mínima: tabla `items` (Hello World) + edge function `deploy_miniapp` + workflows CI.

## Boundaries no negociables

- **Este miniapp solo accede a SU PROPIO Supabase.** Tiene 2 proyectos (dev + prod). Cero credenciales del Core en este repo. Si necesita algo del Core, lo pide al SDK por `postMessage`.
- **No modificar código del Core.** Estos miniapps los crean devs externos al core-team. El Core es black-box: API estable definida por `@locale-labs/protocol`.
- **La keypair ES256 del miniapp se la genera el core-team** corriendo `locale-core/scripts/register-miniapp.ts`. El dev externo recibe solo `MINIAPP_API_KEY` y `MINIAPP_DEPLOY_SECRET` (no la private key).
- **Toda escritura/lectura va con RLS.** Patrón estándar: `auth.uid() = owner_id`. El JWT que firma el Core ya pone `sub = user.id`, así que RLS funciona nativo.
- **Output del build = un único HTML self-contained.** No agregar assets externos en runtime.
- **Validación JWT en el Supabase del miniapp.** El Core firma con private ES256; el Supabase del miniapp valida porque tiene el mismo material importado a mano como JWK privado (`Settings → JWT → Create Standby Key → Import → JSON`, promover a Current). No fetchea JWKS externo — el endpoint `/.well-known/jwks/<slug>.json` del Core fue eliminado en mayo 2026. Detalle en workspace LEARNINGS.

## Stack y entrypoints

| Path | Para qué |
|---|---|
| `src/` | Alpine.js + Tailwind. Views, components, lógica del miniapp. |
| `scripts/init-template.sh` | Reemplaza placeholders y se borra a sí mismo. Primera corrida. |
| `supabase/functions/deploy_miniapp/` | Edge function que sube HTML a Storage + registra version en Core. |
| `supabase/functions/_shared/` | Helpers (CORS, errores, cliente Supabase). |
| `_shared/` | Helpers de cliente reutilizables. |
| `init-config/*.sql` | Bootstrap manual del Supabase del miniapp (correr en SQL Editor). |
| `.env.dev.example` / `.env.prod.example` | Templates de env vars. |
| `package.json` | Stack: SDK + builder pinned. |

## Cómo se conecta

- **Imports:** `@locale-labs/miniapp-sdk` (runtime, inline en el HTML), `@locale-labs/miniapp-builder` (dev-dep, empaqueta).
- **Runtime:** corre dentro de iframe sandboxed del Core. Habla con el kernel por postMessage. Habla con su Supabase con JWT firmado por el Core.

## Supabase / entornos

- **2 proyectos:** dev y prod.
- Dev env vars: `MINIAPP_SUPABASE_URL`, `MINIAPP_SUPABASE_ANON_PUBLIC`, `MINIAPP_SUPABASE_PROJECT_ID`, `MINIAPP_SUPABASE_ACCESS_TOKEN`, `MINIAPP_API_KEY`, `MINIAPP_DEPLOY_SECRET`.
- Prod env vars: mismas con prefijo `PROD_MINIAPP_*`.
- Tabla bootstrap: `items` (placeholder — el dev la reemplaza con el schema del dominio).
- Storage bucket: configurable según el miniapp.
- Edge function `deploy_miniapp` lleva la sube del HTML + el bump de versión.

**Secrets de GitHub Actions y pasos de setup detallados:** [`../README.md`](../README.md) y [`../FIRST_STEPS.md`](../FIRST_STEPS.md).

## Gotchas

- **`init-config/*.sql` se corren a mano** en Supabase SQL Editor. **No** son migrations de `supabase db push`.
- **Import del JWK en Supabase del miniapp** (`Settings → JWT → Create Standby Key → Import → JSON`, algoritmo ES256, mismo `kid` que el Core firma, promover Standby → Current). UI cambió mayo 2026: ya no es `Settings → API → JWT Keys`, y la UI **no acepta PEM** — exige JWK privado completo (con `d`). Snippet Node para generar el JWK desde la PEM en `FIRST_STEPS.md` paso 6.4. El JWT del Core no se valida vía JWKS fetch; se valida con el JWK importado en el dashboard.
- **No usar squash merge a `main`.** semantic-release necesita commits originales.
- **Workflows asumen GitHub secrets**: `MINIAPP_SUPABASE_*`, `MINIAPP_API_KEY`, `MINIAPP_DEPLOY_SECRET`, `PROD_*`. Si faltan, los releases fallan en silencio.
- **Conventional commits obligatorio** (`feat:`, `fix:`, `BREAKING CHANGE:`).

## Release / deploy

- Push a `dev` → workflow `deploy-dev.yml` (sin version bump).
- Merge PR a `main` (no-squash) → workflow `release.yml` (semantic-release bumpea + tagea + deploya a prod).
- Versión visible en Core: `{semver} · {git-sha}`.
- Detalle: [`../DEPLOY.md`](../DEPLOY.md) y guía paso a paso: [`../FIRST_STEPS.md`](../FIRST_STEPS.md).

## Docs del repo

- [`../FIRST_STEPS.md`](../FIRST_STEPS.md) — guía paso a paso (clonar → init → primer deploy).
- [`../DEPLOY.md`](../DEPLOY.md) — flujo de deploy, branches, troubleshooting.
- [`init-config/DEV_GATE.md`](init-config/DEV_GATE.md) — password gate opcional para el dev Supabase del miniapp.
