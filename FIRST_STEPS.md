# FIRST STEPS — Tu primera mini-app de Locale, paso a paso

> 👋 Esta guía te lleva de la mano desde "tengo el template" hasta "mi mini-app está deployada y funcionando en `locale.com.ar`". Si nunca hiciste una mini-app, leé en orden y no te saltees pasos.

---

## ✅ Antes de empezar — checklist de requisitos

Necesitás tener instalado y configurado:

- [ ] [**Bun**](https://bun.sh/) (`curl -fsSL https://bun.sh/install | bash`)
- [ ] [**GitHub CLI** (`gh`)](https://cli.github.com/) y haber corrido `gh auth login`
- [ ] [**Supabase CLI**](https://supabase.com/docs/guides/local-development/cli/getting-started) (`brew install supabase/tap/supabase` o `bunx supabase --help`)
- [ ] [**OpenSSL**](https://www.openssl.org/) (viene preinstalado en macOS y Linux)

Y necesitás acceso a:

- [ ] La **org `locale-labs` en GitHub** (para crear el repo desde el template).
- [ ] La **org de Locale en Supabase** (para crear los proyectos de DB).
- [ ] Alguien con permisos en `locale-core` (para registrar tu mini-app y agregar secrets en Fly.io). Si sos vos, perfecto.

> 💡 Si te falta cualquiera de estos accesos, pedíselo a quien administra Locale **antes** de empezar — varios pasos van a quedar bloqueados sin ellos.

---

## Paso 1 — Crear el repo desde el template

1. Abrí en el browser el repo del boilerplate: `https://github.com/locale-labs/locale-miniapp--boilerplate`.
2. Tocá el botón verde **"Use this template" → "Create a new repository"**.
3. Configurá:
   - **Owner**: `locale-labs`
   - **Repository name**: `locale-miniapp--<id>` — ejemplo: `locale-miniapp--eventos`. La convención es siempre con doble guion.
   - **Visibility**: lo que corresponda (privado por defecto).
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

En el siguiente paso vamos a generar los valores que tenes que copiar y pegar en este archivo

> 🔐 `.env.dev` está en `.gitignore`, no se va a commitear. Si dudás, corré `git status` y verificá que no aparezca.

> 💡 `MINIAPP_API_KEY` es un token que generás vos (`openssl rand -hex 32`) y se usa para autorizar el `deploy_miniapp` edge function. Compartíselo al admin del core para que lo agregue a sus secrets.

---

## Paso 4 — Crear el proyecto Supabase

Cada mini-app tiene **su propio proyecto Supabase** (separado del core y del resto de mini-apps).

1. Andá a [supabase.com/dashboard](https://supabase.com/dashboard) → org de Locale → **"New project"**.
2. Configurá:
   - **Name**: `locale-miniapp--<id>` (mismo que el repo).
   - **Database password**: generá una y **guardala en 1Password** o donde corresponda. Después casi no la vas a necesitar, pero perderla es un dolor.
   - **Region**: elegí la más cercana a Argentina (`sa-east-1` o `us-east-1`).
   - **Pricing plan**: el que corresponda según el contexto.
3. Esperá a que termine de provisionar (~2 minutos).
4. Una vez listo, andá a **Settings → Integrations -> Data API** y copiá:
   - **Api URL** (sacale el "/rest/v1/" del final) → será `MINIAPP_SUPABASE_URL`
5. Andá a **Settings → Configuration -> API keys -> Legacy anon, ...** y copiá:
   - **anon public** → será `MINIAPP_SUPABASE_ANON_PUBLIC`
6. **Settings → Configuration -> General → Project ID** → será `MINIAPP_SUPABASE_PROJECT_ID` (cadena tipo `abcdefghijk`).

---

## Paso 5 — Aplicar la migración inicial

Linkeá tu repo local con el proyecto Supabase y aplicá las migrations:

```bash
bunx supabase login                                      # una sola vez, abre el browser
bunx supabase link --project-ref $MINIAPP_SUPABASE_PROJECT_ID
bunx supabase db push
```

Esto crea la tabla `items` con RLS. Verificalo en el dashboard de Supabase → **Table Editor** → debe aparecer `items`.

> 💡 La tabla `items` es solo un **Hello World**. Cuando arranques tu propia mini-app, vas a borrar la migration `0001_init.sql` o reemplazarla por la del schema real.

---

## Paso 6 — Auth: keypair ES256 + registro en core

**Este es el paso más manual y delicado.** El kernel firma JWTs con una clave privada ES256 propia de cada mini-app, y el Supabase del miniapp valida la firma contra la pública.

### 6.1 Generar la keypair

```bash
mkdir -p .keys && cd .keys
openssl ecparam -name prime256v1 -genkey -noout -out private.pem
openssl ec -in private.pem -pubout -out public.pem
cd ..
```

> 🔐 `.keys/` La privada va al core; la pública va al Supabase.

### 6.2 Mandar la public key al admin de `locale-core` --- ❗❗❗ CONTINUE FROM HERE

Compartí `.keys/public.pem` con quien administra el core. Tiene que:

- Agregar tu mini-app al registry del core (`id="<eventos>"`, name, etc).
- Subir la **private key** como secret de Fly.io: `fly secrets set EVENTOS_ES256_ENV_PRIVATE_KEY="$(cat .keys/private.pem)"` (con tu ID en upper-snake).
- Reiniciar el deploy del core.

### 6.3 Configurar JWKS en tu Supabase

En el Dashboard del Supabase del miniapp:

1. **Settings → Auth → JWT Keys → Custom signing keys** (o equivalente según versión).
2. Apuntar al **endpoint público** que expone el core con tu public key (formato JWK). El admin del core te debe dar la URL — algo como `https://core.locale.com.ar/.well-known/jwks/<id>.json`.

A partir de acá, cuando un usuario haga una request al Supabase del miniapp con el JWT del kernel, Supabase valida la firma contra la pública y resuelve `auth.uid() = sub` correctamente — habilitando RLS.

> 💡 Si más adelante ves errores `401 Unauthorized` al crear ítems, **siempre** verificá esto antes de tocar el código.

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

Antes del primer push, agregá los secrets en **Settings → Secrets and variables → Actions** del repo:

| Secret | De dónde sale |
|---|---|
| `DEV_MINIAPP_SUPABASE_URL` | Mismo valor que `.env.dev` |
| `DEV_MINIAPP_SUPABASE_ANON_PUBLIC` | " |
| `DEV_MINIAPP_SUPABASE_PROJECT_ID` | " |
| `DEV_MINIAPP_DEPLOY_SECRET` | " |
| `DEV_MINIAPP_API_KEY` | " |
| `DEV_MINIAPP_SUPABASE_ACCESS_TOKEN` | " |
| `CORE_DEV_SUPABASE_URL` | Te lo da el admin del core (compartido entre mini-apps) |
| `CORE_DEV_SUPABASE_ANON_PUBLIC` | " |
| `CORE_PROD_SUPABASE_URL` | " |
| `CORE_PROD_SUPABASE_ANON_PUBLIC` | " |
| `MINIAPP_SLUG` | El slug de tu mini-app (`<eventos>`) |
| `MINIAPP_NAME` | Nombre visible (`Eventos del barrio`) |

Los `PROD_*` los vas a llenar en el Paso 11.

> 💡 `gh secret set DEV_MINIAPP_SUPABASE_URL` desde la terminal te ahorra ir al browser. `gh secret list` para ver lo que ya cargaste.

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

1. **Repetí Paso 3** creando un segundo proyecto Supabase (`locale-miniapp--<id>` con sufijo `-prod` si querés diferenciarlo).
2. Aplicá las migrations al proyecto prod (Paso 5 con el nuevo project_ref).
3. Repetí Paso 6.3 (configurar JWKS en el Supabase de prod).
4. Cargá los secrets `PROD_MINIAPP_*` en GitHub (Paso 8).
5. Pedile al admin del core que también registre tu mini-app en el **core de prod**.
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
| `401 Unauthorized` al crear ítem | El JWT no está pasando RLS. Verificá Paso 6.3 (JWKS). |
| `404` cuando abro `/locale.com.ar/<id>` | El core no registró tu mini-app. Verificá con el admin. |
| El modal del kernel no muestra la versión | El edge function `deploy_miniapp` falló. Mirá `bunx supabase functions logs deploy_miniapp`. |
| `bun run build` falla con "SDK no encontrado" | `bun install` no terminó OK. Borrá `node_modules` y reinstalá. |
| El push a `dev` falla en CI con "secret not found" | Faltan secrets de GitHub (Paso 8). |

---

## 🚀 ¿Y ahora qué?

- **Borrá la feature `items`** y reemplazala por las tuyas:
  - `src/features/<tu-feature>/` con `index.ts`, `api.ts`, `types.ts`.
  - Importala desde `src/alpine.ts`.
  - Agregá el HTML correspondiente en `src/html/index.html`.
- **Agregá nuevas migrations** a `supabase/migrations/` (numeradas: `0002_...sql`, `0003_...sql`).
- **Agregá edge functions** propias en `supabase/functions/<tu-funcion>/` y registralas en `supabase/config.toml`.
- **Storage buckets, cron jobs, dev gates**: usá la mini-app de mascotas como referencia (`locale-miniapp--mascotas-perdidas/init-config/`).

---

> ❓ ¿Trabaste en algún paso? Abrí un issue en este repo o pedí ayuda en el canal de Locale. Si encontraste algo confuso o desactualizado en esta guía, **mejorala** — es el camino más rápido para que la próxima persona no tropiece.

<!-- TODO: specific steps for "prod" - create supabase proyect - prod .env -->