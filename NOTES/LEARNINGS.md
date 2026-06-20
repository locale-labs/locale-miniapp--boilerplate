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

- **Bucket `miniapp-builds` hay que crearlo a mano** en el Supabase del miniapp **antes del primer deploy**. El edge function `deploy_miniapp` sube el HTML ahí, pero el call `.upload()` **no crea el bucket** — devuelve 500 con `{"error":"Bucket not found"}` y el workflow falla. Tiene que ser **público** (el kernel sirve el HTML a usuarios anónimos). SQL: `INSERT INTO storage.buckets (id, name, public) VALUES ('miniapp-builds', 'miniapp-builds', true);`. Detalle en `FIRST_STEPS.md` Paso 5.1. **Tech debt:** mover la creación a la migration `0001_init.sql` del boilerplate, o que el edge function lo cree on-demand.
- **`MINIAPP_DEPLOY_SECRET` es compartido entre TODOS los miniapps**, no per-miniapp. El core valida el header `x-deploy-secret` contra **una sola env var global** en `register_miniapp_version` ([locale-core/supabase/functions/register_miniapp_version/register_miniapp_version.ts](../../locale-core/supabase/functions/register_miniapp_version/register_miniapp_version.ts) líneas 48-57). Si un miniapp manda un valor random distinto, el core devuelve 401, la fila del miniapp en core queda con `dev_version/dev_url = NULL` y el browser tira 404. **Hay que pedir el valor global al admin del core y usarlo en todos los miniapps**. (Antes esto pasaba silencioso con CI verde; desde el fix de [deploy_miniapp.ts](../supabase/functions/deploy_miniapp/deploy_miniapp.ts) el edge fn devuelve 500 si el register a cualquier core falla, así que ahora el CI falla en rojo.) **Tech debt** ([locale-core/NOTES/tech_debt_deploy_secret.md](../../locale-core/NOTES/tech_debt_deploy_secret.md)): validar contra `miniapps.api_key` per-row. Hasta entonces el "generá `MINIAPP_DEPLOY_SECRET` con `openssl rand -hex 32`" del Paso 3 es engañoso.
- **`init-config/*.sql` se corren a mano** en Supabase SQL Editor. **No** son migrations de `supabase db push`.
- **Import del JWK en Supabase del miniapp** (`Settings → JWT → Create Standby Key → Import → JSON`, algoritmo ES256, mismo `kid` que el Core firma, promover Standby → Current). UI cambió mayo 2026: ya no es `Settings → API → JWT Keys`, y la UI **no acepta PEM** — exige JWK privado completo (con `d`). Snippet Node para generar el JWK desde la PEM en `FIRST_STEPS.md` paso 6.4. El JWT del Core no se valida vía JWKS fetch; se valida con el JWK importado en el dashboard.
- **No usar squash merge a `main`.** semantic-release necesita commits originales.
- **Workflows asumen GitHub secrets**: `MINIAPP_SUPABASE_*`, `MINIAPP_API_KEY`, `MINIAPP_DEPLOY_SECRET`, `PROD_*`. Si faltan, los releases fallan en silencio.
- **Conventional commits obligatorio** (`feat:`, `fix:`, `BREAKING CHANGE:`).

## Miniapp PRIVADA (allowlist de acceso)

> Patrón reutilizable cuando una miniapp **no** es de comunidad: solo usuarios logueados **y aprobados** pueden leer/escribir (vs. el default `select using(true)` = lectura pública con la anon key). Primera implementación de referencia: `locale-miniapp--arqueriaflordeliz` (migración `0008_private_access.sql`).

**Restricción clave:** el JWT que el Core firma para el miniapp **solo trae `sub` (uuid), NO el email** (ver [`../../NOTES/AUTH.md`](../../NOTES/AUTH.md)). El SDK expone `user.email` al cliente JS pero es **autoreportado / no confiable** para RLS. → El ancla de confianza es **`auth.uid()` (uuid)**, no el email. Un allowlist "por email puro" requeriría agregar el claim `email` al token en el Core (fuera del boundary del miniapp).

**Patrón (sin tocar el Core):**
1. Tabla `access_grants(user_id uuid pk, email text, allowed bool default false, created_at)`. `email` = solo label para que el admin reconozca a la persona; la PK real es el uuid.
2. RLS de `access_grants`:
   - select: `using (auth.uid() = user_id)` → el user ve su propio estado.
   - **sin policy de insert / update / delete** → escribir la tabla es **solo `service_role` (dashboard)**. Ni el dueño de la fila la puede crear/modificar. (En arqueria fue decisión explícita del cliente: el alta la hace solo el admin a mano.)
3. Helper `public.is_allowed()` `language sql stable security definer set search_path=public` → `exists(grant del caller con allowed=true)`. Necesita ser `security definer` para leerse desde las policies de las otras tablas (el WARN de advisors es esperado; solo devuelve un bool del propio caller).
4. Todas las tablas de dominio: cambiar `select using(true)` y los write `auth.role()='authenticated'` por `using (public.is_allowed())` / `with check (public.is_allowed())`.
5. Cliente: al iniciar consulta `rpc/is_allowed`. Si `false` → pantalla "acceso pendiente" que le muestra su **uuid + email** (botón copiar) para pasarle al admin, en vez de cargar la app. **El gate del front es solo UX; la seguridad es el RLS.**
6. Alta (admin): la persona se loguea 1 vez y pasa su uuid+email; el admin hace `insert into access_grants(user_id,email,allowed) values('<uuid>','...',true)` desde SQL editor (service_role). No hay claim de admin en el JWT → la gestión de admin va siempre por service_role.

   > Variante alternativa (más cómoda, menos estricta): permitir self-insert con `with check (auth.uid()=user_id and allowed=false)` para que el cliente auto-poble la lista de pendientes y el admin solo flipee `allowed=true`. Evita tener que copiar uuids a mano, a costa de que cualquier logueado pueda crear su fila (no aprobada). Elegir según cuánto querés cerrar la tabla.

**Al aplicar en prod:** apenas corre la migración nadie lee nada hasta que el admin cargue los grants (cada persona se loguea 1 vez → te pasa su uuid → la das de alta con `allowed=true`).

**Futuro (allowlist por email puro):** si el Core agrega el claim `email` al token, el RLS se simplifica a `lower(auth.jwt()->>'email') in (select ...)` y se puede pre-autorizar sin que la persona se loguee primero.

## Release / deploy

- Push a `dev` → workflow `deploy-dev.yml` (sin version bump).
- Merge PR a `main` (no-squash) → workflow `release.yml` (semantic-release bumpea + tagea + deploya a prod).
- Versión visible en Core: `{semver} · {git-sha}`.
- Detalle: [`../DEPLOY.md`](../DEPLOY.md) y guía paso a paso: [`../FIRST_STEPS.md`](../FIRST_STEPS.md).

## Docs del repo

- [`../FIRST_STEPS.md`](../FIRST_STEPS.md) — guía paso a paso (clonar → init → primer deploy).
- [`../DEPLOY.md`](../DEPLOY.md) — flujo de deploy, branches, troubleshooting.
- [`init-config/DEV_GATE.md`](init-config/DEV_GATE.md) — password gate opcional para el dev Supabase del miniapp.
