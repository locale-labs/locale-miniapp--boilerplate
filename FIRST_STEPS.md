# FIRST STEPS — Tu primera mini-app de Locale, paso a paso

> 👋 Esta guía te lleva de la mano desde "tengo el template" hasta "mi mini-app está deployada y funcionando en `locale.com.ar`". Si nunca hiciste una mini-app, leé en orden y no te saltees pasos.

---

## ✅ Antes de empezar — checklist de requisitos

Necesitás tener instalado y configurado:

- [ ] [**Bun**](https://bun.sh/) (`curl -fsSL https://bun.sh/install | bash`)
- [ ] [**GitHub CLI** (`gh`)](https://cli.github.com/) y haber corrido `gh auth login`
- [ ] [**Supabase CLI**](https://supabase.com/docs/guides/local-development/cli/getting-started) (`brew install supabase/tap/supabase` o `bunx supabase --help`)
Y necesitás acceso a:

> 💡 Si te falta cualquiera de estos accesos, pedíselo a quien administra Locale **antes** de empezar — varios pasos van a quedar bloqueados sin ellos.

---

## Paso 1 — Crear el repo desde el template

1. Abrí en el browser el repo del boilerplate: `https://github.com/locale-labs/locale-miniapp--boilerplate`.
2. Tocá el botón verde **"Use this template" → "Create a new repository"**.
3. Configurá:
   - **Repository name**: `locale-miniapp--<id>` — ejemplo: `locale-miniapp--eventos-de-la-zona`. La convención es siempre con doble guion.
   - **Visibility**: privado.
4. **Create repository**.

Ahora cloná el repo nuevo:

```bash
git clone git@github.com:locale-labs/locale-miniapp--<id>.git
cd locale-miniapp--<id>
```

---

## Paso 2 — Inicializar el código (reemplazar placeholders)

El template tiene placeholders tipo `{{MINIAPP_ID}}` en muchos archivos. Hay un script que te los reemplaza con tus valores:

```bash
bash scripts/init-template.sh
```

Te va a preguntar 5 cosas (todas con un default sensato — podés dar Enter):

| Campo | Ejemplo | Para qué |
|---|---|---|
| `MINIAPP_ID` | `eventos` | Slug corto. Se usa en URLs (`/eventos`) y env vars. |
| `MINIAPP_NAME` | `Eventos del barrio` | Nombre visible que va al modal del kernel. |
| `MINIAPP_DESCRIPTION` | `Descubrí eventos cerca tuyo` | Descripción corta del paquete y del README. |
| `MINIAPP_SLUG` | `locale-miniapp--eventos` | Igual al nombre del repo. Se usa como `project_id` en Supabase. |
| `MINIAPP_PACKAGE_NAME` | `locale-miniapp-eventos` | El `name` del `package.json`. |

Cuando termina, el script:

- Reemplaza todos los placeholders.
- Borra la sección "Cómo usar este template" del README.
- **Se elimina a sí mismo**.

Hacé un commit con esto:

```bash
git add -A
git commit -m "chore: init from template"
```

> 🚨 Todavía **no pushees**. Antes hace falta configurar Supabase (Paso 3) para que el primer push a `dev` no falle el workflow de deploy.

---

## Paso 3 — Crear y llenar `.env.dev`

```bash
cp .env.dev.example .env.dev
```

El archivo tiene 7 vars. 3 se completan en el Paso 4 (vienen del dashboard de Supabase). Las otras 4 las generás/conseguís ahora:

| Var | Cómo se obtiene |
|---|---|
| `MINIAPP_DEPLOY_SECRET` | **Pedírselo al admin del core** — es un valor **global compartido entre todos los miniapps**, no es per-miniapp. El core valida el header `x-deploy-secret` contra UNA env var global suya. Si generás uno random, el core devuelve 401 al register y **el deploy falla en rojo**: `deploy_miniapp` ahora devuelve 500 cuando el register a cualquier core falla (el HTML ya quedó en storage, pero la fila del core no se actualiza y `https://locale.com.ar/<slug>` tira 404). **Tech debt**: validar per-row contra `miniapps.api_key` ([`locale-core/NOTES/tech_debt_deploy_secret.md`](../locale-core/NOTES/tech_debt_deploy_secret.md)). |
| `MINIAPP_API_KEY` | `openssl rand -hex 32`. Es el **deploy token del propio miniapp** (no es del core, no es global). El `make deploy-supabase-functions-dev/prod` lo setea solo como secret del edge function `deploy_miniapp` de **este** miniapp (`supabase secrets set`). El builder lo manda en el header `x-miniapp-api-key` al deployar y `deploy_miniapp` valida que coincida. No hace falta el admin del core para esta key. |
| `MINIAPP_SUPABASE_ACCESS_TOKEN` | Supabase Dashboard → Account → Access Tokens → **New token** |
| `MINIAPP_DEV_PASS` | Elegí un password (3 palabras random con https://bip39.onekey.so/ o lo que prefieras). **Guardalo en plaintext acá**: el bcrypt se va a vivir en la DB del miniapp (Paso 5.2) y bcrypt es one-way — si no anotás el plaintext acá lo perdés. Sirve para destrabar el form que aparece al abrir `dev.locale.com.ar/<slug>?mini-app-dev-mode=true`. |

> 🔐 `.env.dev` está en `.gitignore`, no se va a commitear. Si dudás, corré `git status` y verificá que no aparezca.

---

## Paso 4 — Crear el proyecto Supabase

Cada mini-app tiene **su propio proyecto Supabase** (separado del core y del resto de mini-apps).

1. Andá a [supabase.com/dashboard](https://supabase.com/dashboard) → org de Locale → **"New project"**.
2. Configurá:
   - **Name**: convención = `locale-miniapp--<id>-dev` para el proyecto **dev**. Ejemplo (mascotas): `locale-miniapp--lost-pets-dev` (dev).
   - **Database password**: generá una y **guardala en 1Password** o donde corresponda. Después casi no la vas a necesitar, pero perderla es un dolor.
   - **Region**: elegí la más cercana a Argentina (`sa-east-1` o `us-east-1`).
   - **Pricing plan**: el que corresponda según el contexto.

> 💡 El nombre del proyecto en Supabase es **cosmético**: las conexiones usan `project_ref` (la cadena tipo `abcdefghijk` en la URL), que es inmutable. Renombrar después no rompe nada.
3. Esperá a que termine de provisionar (~2 minutos).
4. Una vez listo, andá a **Settings → Integrations -> Data API** y copiá:
   - **Api URL** (sacale el "/rest/v1/" del final) → pegala en el archivo .env.dev en `MINIAPP_SUPABASE_URL`
5. Andá a **Settings → Configuration -> API keys -> Legacy anon, ...** y copiá:
   - **anon public** → pegala en el archivo .env.dev en `MINIAPP_SUPABASE_ANON_PUBLIC`
6. **Settings → Configuration -> General → Project ID** → pegala en el archivo .env.dev en `MINIAPP_SUPABASE_PROJECT_ID` (cadena tipo `abcdefghijk`).

---

## Paso 5 — Aplicar la migración inicial

Linkeá tu repo local con el proyecto Supabase y aplicá las migrations:

- Tenes que estar con la terminal abierta en el path de este proyecto antes de correr el `link`

> suplanta $MINIAPP_SUPABASE_PROJECT_ID con el id que guardaste recien en el archivo .env.dev

```bash
bunx supabase login                                      # una sola vez, abre el browser
bunx supabase link --project-ref $MINIAPP_SUPABASE_PROJECT_ID
bunx supabase db push
```

Esto crea la tabla `items` con RLS. Verificalo en el dashboard de Supabase → **Table Editor** → debe aparecer `items`.

> 💡 La tabla `items` es solo un **Hello World**. Cuando arranques tu propia mini-app, vas a borrar la migration `0001_init.sql` o reemplazarla por la del schema real.

> 🤖 **Tip si usás Claude Code / AI tooling:** registrá el Supabase MCP server apuntando al org de tu mini-app para que el AI pueda aplicar migrations y queries sin que vos copies/pegues comandos CLI. Token va por env var (no flag) para que no quede en listings/output, y scope `user` para que sea visible desde cualquier directorio (no solo el del proyecto):
>
> ```bash
> printf 'Supabase PAT: ' >&2; read -rs TOKEN; echo
> claude mcp add -s user supabase-<id> --env SUPABASE_ACCESS_TOKEN="$TOKEN" -- npx -y @supabase/mcp-server-supabase@latest > /dev/null
> unset TOKEN
> claude mcp list | grep supabase-<id>
> ```
>
> Generá el PAT en `https://supabase.com/dashboard/account/tokens`. Notas:
> - Sin `-s user`, el MCP queda atado al cwd donde corriste el comando — invisible desde sesiones en otros dirs.
> - El token queda guardado plaintext en `~/.claude.json` — normal para MCP, inevitable.
> - **No** lo pongas como `--access-token` flag — ahí filtra a `claude mcp list` y `ps`.
> - Después de agregar, `/mcp` dentro de Claude Code refresca la lista (o reiniciar sesión).

### 5.1 Crear el bucket `miniapp-builds` en Storage

El edge function `deploy_miniapp` (que corre el workflow de CI en cada push a `dev`/`main`) sube el HTML bundleado a Supabase Storage en el bucket **`miniapp-builds`**. Si el bucket no existe, el deploy falla con `❌ Deployment failed (500): {"error":"Bucket not found"}`.

Crear el bucket — vía SQL (Dashboard → **SQL Editor**):

```sql
INSERT INTO storage.buckets (id, name, public)
VALUES ('miniapp-builds', 'miniapp-builds', true);
```

Verificación:

```sql
SELECT id, name, public FROM storage.buckets WHERE id = 'miniapp-builds';
-- debe devolver una fila con public = true
```

### 5.2 Crear el dev-gate per-miniapp (tabla + RPC + password) (solo miniapp-dev)

El core, cuando se abre `dev.locale.com.ar/<slug>?mini-app-dev-mode=true`, llama a la RPC `public.dev_gate_verify(p text)` en el **Supabase del miniapp** para validar la contraseña del gate. Si la RPC no existe el browser ve el form pero al submit el verify revienta (RPC missing).

Correr el SQL de [`NOTES/init-config/DEV_GATE.md`](./NOTES/init-config/DEV_GATE.md) contra el Supabase **dev** del miniapp (Dashboard → SQL Editor, o `bunx supabase db query`, o MCP). Crea `dev_gate_config`, la RPC, y hace el INSERT con el password hasheado con bcrypt.

> ⚠️ **Usá el mismo password que pusiste en `MINIAPP_DEV_PASS` del Paso 3.** bcrypt es one-way: si después perdés el `.env.dev`, no hay forma de leer el hash de la DB — tenés que rotar haciendo otro UPDATE con un password nuevo.

Verificación:

```sql
SELECT public.dev_gate_verify('<tu-password>') AS verify_ok;
-- debe devolver true
```

---

## Paso 6 — Auth: registro en el core (lo corre el equipo core)

El kernel firma JWTs con una clave privada ES256 propia de cada mini-app, y el Supabase del miniapp valida la firma contra la pública. Generar ese keypair, guardarlo cifrado en el core, registrar la fila e importar el JWK en tu Supabase lo hace **el equipo core** con un script (`scripts/register-miniapp.ts` en `locale-core`) — un solo comando, sin clicks en el dashboard de JWT.

**Vos (dev de la mini-app):** pedile al equipo core que registre tu slug. Pasale:

- `slug` y `name` → de `package.json` (`miniApp.id` / `miniApp.name`)
- `MINIAPP_SUPABASE_URL` + `MINIAPP_SUPABASE_ANON_PUBLIC` → de tu `.env.dev` (dev ahora; los `-prod` cuando tengas el Supabase prod)
- `MINIAPP_SUPABASE_ACCESS_TOKEN` → de tu `.env.dev`. **Imprescindible** para importar el JWK en tu Supabase: el Supabase de cada mini-app vive en su propia org, y el token del core no puede administrarla (`403`).

Cuando el core termina: tu fila queda creada, la signing-key importada y **activa** (current), y los GitHub secrets del repo seteados (si lo pediste). No tenés que tocar `Settings → JWT` a mano.

> 💡 Si más adelante ves `401 Unauthorized` al crear ítems: el `kid` del JWT que firma el kernel debe matchear el `kid` del JWK activo en tu Supabase, y el JWK debe estar como **current** (no standby). Diagnóstico en Troubleshooting.

> 🔧 **Equipo core:** el detalle completo (flags, flujo dev→prod, gh secrets, cómo funciona el import del JWK, troubleshooting) vive en [`locale-core/NOTES/REGISTER_MINIAPP.md`](../locale-core/NOTES/REGISTER_MINIAPP.md), al lado del script.

---

## Paso 7 — Probar localmente

```bash
bun install
bun run dev
```

Esto abre un dev server. **Pero atención**: corriendo en localhost no tenés el kernel inyectando user/location/token, así que vas a ver "Invitado" y no vas a poder crear ítems. Es esperado.

Para probar **todo el flujo end-to-end** necesitás deployar a `dev` y abrirla desde `locale.com.ar/<id>?mini-app-dev-mode=true` (Paso 9-10).

> 💡 Si tenés el repo `locale-core` clonado y corriéndolo localmente, podés usar `bun run dev:local` para apuntar al SDK local en vez del de npm. Útil si estás iterando sobre el SDK.

---

## Paso 8 — Configurar GitHub Secrets

Antes del primer push, agregá los secrets en **Settings → Secrets and variables → Actions** del repo.

> 💡 `gh secret set DEV_MINIAPP_SUPABASE_URL --body "xx_secret"` desde la terminal te ahorra ir al browser. `gh secret list` para ver lo que ya cargaste. Más abajo hay un script que setea los 12 de una pasada.

> 🔴 **OJO con el nombre de las `CORE_*`.** El nombre en `.env.dev.example` **no** coincide con el del secret: el orden de palabras está swapeado (solo en las `CORE_*`, las `MINIAPP_*` están bien). Los workflows leen la forma `CORE_{ENV}_SUPABASE_*`; el `.env` usa `CORE_SUPABASE_{ENV}_*`. Si seteás el secret copiando el nombre del `.env`, ningún workflow lo lee → el core no resuelve y el **deploy falla silencioso** (sin error claro). Mapeo:
>
> | Nombre en `.env.dev.example` | Nombre del GitHub Secret (lo que hay que setear) |
> |---|---|
> | `CORE_SUPABASE_DEV_URL` | `CORE_DEV_SUPABASE_URL` |
> | `CORE_SUPABASE_DEV_ANON_PUBLIC` | `CORE_DEV_SUPABASE_ANON_PUBLIC` |
> | `CORE_SUPABASE_PROD_URL` | `CORE_PROD_SUPABASE_URL` |
> | `CORE_SUPABASE_PROD_ANON_PUBLIC` | `CORE_PROD_SUPABASE_ANON_PUBLIC` |

### 8.1 — Setear ahora (los 12 que necesita el primer deploy a `dev`)

| Secret | De dónde sale |
|---|---|
| `DEV_MINIAPP_SUPABASE_URL` | Mismo valor que `.env.dev` (`MINIAPP_SUPABASE_URL`) |
| `DEV_MINIAPP_SUPABASE_ANON_PUBLIC` | `.env.dev` (`MINIAPP_SUPABASE_ANON_PUBLIC`) |
| `DEV_MINIAPP_SUPABASE_PROJECT_ID` | `.env.dev` (`MINIAPP_SUPABASE_PROJECT_ID`) |
| `DEV_MINIAPP_DEPLOY_SECRET` | `.env.dev` (`MINIAPP_DEPLOY_SECRET`) |
| `DEV_MINIAPP_API_KEY` | `.env.dev` (`MINIAPP_API_KEY`) |
| `DEV_MINIAPP_SUPABASE_ACCESS_TOKEN` | `.env.dev` (`MINIAPP_SUPABASE_ACCESS_TOKEN`) |
| `CORE_DEV_SUPABASE_URL` | **Ya viene en `.env.dev.example`** (`CORE_SUPABASE_DEV_URL`, valor compartido entre mini-apps). Si falta, pedíselo al admin del core. Ojo el nombre ↑ |
| `CORE_DEV_SUPABASE_ANON_PUBLIC` | Ya viene en `.env.dev.example` (`CORE_SUPABASE_DEV_ANON_PUBLIC`). Ojo el nombre ↑ |
| `CORE_PROD_SUPABASE_URL` | Ya viene en `.env.dev.example` (`CORE_SUPABASE_PROD_URL`). Ojo el nombre ↑ |
| `CORE_PROD_SUPABASE_ANON_PUBLIC` | Ya viene en `.env.dev.example` (`CORE_SUPABASE_PROD_ANON_PUBLIC`). Ojo el nombre ↑ |
| `MINIAPP_SLUG` | El slug de tu mini-app (`packageJson.miniApp.id`) |
| `MINIAPP_NAME` | Nombre visible (`packageJson.miniApp.name`) |

> 💡 Las 4 `CORE_*` ya vienen **pre-llenadas y commiteadas** en `.env.dev.example`, así que después del `cp` del Paso 3 ya las tenés en tu `.env.dev`. No hace falta pedírselas a nadie salvo que falten.

#### Script copy-paste (setea los 12 de una pasada)

Corré desde la raíz del repo del miniapp, con `.env.dev` ya completo:

```bash
# Setea los 12 secrets que se necesitan para el primer deploy a dev.
set -euo pipefail
set -a; source .env.dev; set +a

gh secret set DEV_MINIAPP_SUPABASE_URL            --body "$MINIAPP_SUPABASE_URL"
gh secret set DEV_MINIAPP_SUPABASE_ANON_PUBLIC    --body "$MINIAPP_SUPABASE_ANON_PUBLIC"
gh secret set DEV_MINIAPP_SUPABASE_PROJECT_ID     --body "$MINIAPP_SUPABASE_PROJECT_ID"
gh secret set DEV_MINIAPP_DEPLOY_SECRET           --body "$MINIAPP_DEPLOY_SECRET"
gh secret set DEV_MINIAPP_API_KEY                 --body "$MINIAPP_API_KEY"
gh secret set DEV_MINIAPP_SUPABASE_ACCESS_TOKEN   --body "$MINIAPP_SUPABASE_ACCESS_TOKEN"

# CORE_* — el nombre del secret está swapeado respecto del .env (ver tabla de mapeo arriba).
gh secret set CORE_DEV_SUPABASE_URL               --body "$CORE_SUPABASE_DEV_URL"
gh secret set CORE_DEV_SUPABASE_ANON_PUBLIC       --body "$CORE_SUPABASE_DEV_ANON_PUBLIC"
gh secret set CORE_PROD_SUPABASE_URL              --body "$CORE_SUPABASE_PROD_URL"
gh secret set CORE_PROD_SUPABASE_ANON_PUBLIC      --body "$CORE_SUPABASE_PROD_ANON_PUBLIC"

# Slug / name vienen de package.json (miniApp.id / miniApp.name)
gh secret set MINIAPP_SLUG --body "$(bun -e 'console.log(require(\"./package.json\").miniApp.id)')"
gh secret set MINIAPP_NAME --body "$(bun -e 'console.log(require(\"./package.json\").miniApp.name)')"

gh secret list
```

### 8.2 — Diferir a Paso 11 (los 6 `PROD_MINIAPP_*`)

| Secret | De dónde sale |
|---|---|
| `PROD_MINIAPP_SUPABASE_URL` | Del proyecto Supabase **prod** (se crea en el Paso 11) |
| `PROD_MINIAPP_SUPABASE_ANON_PUBLIC` | " |
| `PROD_MINIAPP_SUPABASE_PROJECT_ID` | " |
| `PROD_MINIAPP_DEPLOY_SECRET` | " |
| `PROD_MINIAPP_API_KEY` | " |
| `PROD_MINIAPP_SUPABASE_ACCESS_TOKEN` | " |

> ⏳ Estos requieren el proyecto Supabase de prod, que recién se crea en el **Paso 11**. Para el primer deploy a `dev` **no hacen falta** — los cargás cuando promuevas a producción.

---

## Paso 9 — Primer deploy a dev

Creá la branch `dev` y pusheala:

```bash
git checkout -b dev
git push -u origin dev
```

Esto dispara el workflow `deploy-dev.yml`. Mirá el progreso:

```bash
gh run watch
```

O en GitHub: **Actions → Deploy <id> (dev)**.

Si todo OK, deberías ver:

- ✅ `Deploying supabase functions to dev...`
- ✅ `Deploying miniapp to dev...`
- ✅ `Deployment to dev complete!`

---

## Paso 10 — Verificar que la mini-app vive

Abrí en el browser:

```
https://locale.com.ar/<id>?mini-app-dev-mode=true
```

(reemplazá `<id>` por tu `MINIAPP_ID`).

Deberías ver:

- 📋 Tu mini-app con header mostrando tu email y ciudad.
- 📝 El form para crear un ítem.
- 🆕 Si creás un ítem, aparece en la lista. **Si esto funciona, RLS + JWT + Supabase + edge function + core están todos OK.**
- 🏷️ Abriendo el modal de info del kernel, ves la versión: `0.1.0 · <git-sha>`.

🎉 **Si llegaste acá: tu mini-app está viva en dev.**

---

## Paso 11 — Promover a producción

1. **Repetí Paso 4** creando un segundo proyecto Supabase (`locale-miniapp--<id>` con sufijo `-prod` si querés diferenciarlo).
2. Aplicá las migrations al proyecto prod (Paso 5 con el nuevo project_ref).
3. Pedile al equipo core que **re-corra el registro con los flags `-prod`** (`--supabase-url-prod` / `--supabase-anon-key-prod`, más `--miniapp-access-token`). En una sola corrida importa y activa el JWK **prod** en tu Supabase prod y crea la fila CORE-PROD — sin tocar `Settings → JWT` ni SQL a mano. Ver Paso 6.
4. Cargá los 6 secrets `PROD_MINIAPP_*` en GitHub (Paso 8.2).
5. Confirmá con el core que el re-registro prod (punto 3) terminó OK.
6. Mergeá `dev → main` con un PR (NO uses squash — semantic-release necesita los commits originales):
   ```bash
   gh pr create --base main --head dev --title "release: initial deploy"
   gh pr merge <pr-number> --merge
   ```
7. El workflow `release.yml` corre, semantic-release bumpea versión y deploya a prod.
8. Verificá en `locale.com.ar/<id>` (sin `?mini-app-dev-mode=true`).

---

## 🐛 Troubleshooting rápido

| Síntoma | Probable causa |
|---|---|
| Veo "Cargando…" para siempre | El SDK no se inyectó / el HTML no llegó al kernel. Ver Network tab y consola. |
| "Invitado" en lugar de mi email | El kernel no devolvió un user válido. Probaste sin `?mini-app-dev-mode=true`? |
| `401 Unauthorized` al crear ítem (`PGRST301` "No suitable key was found to decode the JWT") | El JWT no está pasando RLS. Diagnóstico rápido: DevTools → Network → `sign-token` → Response → copiar `token`. Decodificá el header con `node -e "console.log(JSON.parse(Buffer.from('<TOKEN>'.split('.')[0],'base64')))"` y comparalo contra `curl -s https://<miniapp-ref>.supabase.co/auth/v1/.well-known/jwks.json \| jq '.keys[].kid'`. Si los `kid` no matchean → Fly desyncado del `.keys/` local; fix re-importando desde el PEM canónico (ver `<workspace>/NOTES/LEARNINGS.md → Fly secrets vs .keys/ desync`). Si matchean: (a) verificá que el JWK importado en Supabase fue promovido de Standby a Current, (b) la private del JWK matchea `<SLUG>_ES256_DEV_PRIVATE_KEY` de Fly (mismo material). |
| `404` cuando abro `/locale.com.ar/<id>` | El core no registró la ruta. Causas comunes: (a) la fila no existe en `miniapps`; (b) deploy llegó OK pero `dev_version`/`dev_url` quedaron NULL por mismatch de `MINIAPP_DEPLOY_SECRET`; (c) core viejo (anterior a mayo 2026) que skipea rutas si `url` (prod) está NULL aunque `dev_url` esté poblado — actualizar core. |
| Dev gate dice `"El gate no está configurado en el Supabase dev de la mini-app"` | `supabase_url_dev` o `supabase_anon_key_dev` está NULL en la fila del core. Pedile al core que re-corra `register-miniapp.ts` con `--supabase-url-dev` / `--supabase-anon-key-dev`. |
| Dev gate dice `"No se pudo verificar contra Supabase"` o submit del password tira error | Falta correr el SQL del Paso 5.2 contra el Supabase dev del miniapp — no existe la RPC `dev_gate_verify` ni la tabla `dev_gate_config`. |
| El password del dev-gate "no funciona" y no me acuerdo cuál puse | bcrypt es one-way, no se recupera. Si lo guardaste en `.env.dev` como `MINIAPP_DEV_PASS` (Paso 3), está ahí. Si no, rotalo: re-correr el INSERT/UPDATE del Paso 5.2 con un password nuevo, anotalo en `.env.dev` esta vez. |
| El modal del kernel no muestra la versión | El edge function `deploy_miniapp` falló. Mirá `bunx supabase functions logs deploy_miniapp`. |
| `bun run build` falla con "SDK no encontrado" | `bun install` no terminó OK. Borrá `node_modules` y reinstalá. |
| El push a `dev` falla en CI con "secret not found" | Faltan secrets de GitHub (Paso 8). |
| Deploy falla con `❌ Deployment failed (500): {"error":"Bucket not found"}` | Falta crear el bucket `miniapp-builds` en Storage del Supabase del miniapp. Ver Paso 5.1. |

---

## 🚀 ¿Y ahora qué?

- **Borrá la feature `items`** y reemplazala por las tuyas:
  - `src/features/<tu-feature>/` con `index.ts`, `api.ts`, `types.ts`.
  - Importala desde `src/alpine.ts`.
  - Agregá el HTML correspondiente en `src/html/index.html`.
- **Agregá nuevas migrations** a `supabase/migrations/` (numeradas: `0002_...sql`, `0003_...sql`).
- **Agregá edge functions** propias en `supabase/functions/<tu-funcion>/` y registralas en `supabase/config.toml`.
- **Storage buckets, cron jobs**: usá la mini-app de mascotas como referencia (`locale-miniapp--mascotas-perdidas/init-config/`). El dev-gate ya quedó cubierto en el Paso 5.2.

---

> ❓ ¿Trabaste en algún paso? Abrí un issue en este repo o pedí ayuda en el canal de Locale. Si encontraste algo confuso o desactualizado en esta guía, **mejorala** — es el camino más rápido para que la próxima persona no tropiece.