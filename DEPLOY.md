# Deploy — `{{MINIAPP_ID}}`

- **`dev`** → cada push deploya al entorno dev (Supabase functions + storage del miniapp dev). No bumpea versión.
- **`main`** → semantic-release bumpea versión, genera CHANGELOG, crea release/tag, y deploya a prod.

La versión que ves en el modal del core sale de `package.json` + el SHA corto del commit deployado. El builder envía ambos al edge function `deploy_miniapp`, que los combina como semver build-metadata (`1.1.0+a1b2c3d`) y el core los re-formatea como `1.1.0 · a1b2c3d`.

## Flujo

```bash
# 1. Trabajo en dev
git checkout dev
git commit -m "feat: ..."   # conventional commits
git push                    # → deploy-dev.yml → make deploy-dev

# 2. Promover a prod
gh pr create --base main --head dev --title "release: ..."
gh pr merge <pr> --merge   # NO squash (semantic-release necesita los commits)
                           # → release.yml: semantic-release + make deploy-prod
                           #   solo si hubo bump real

# 3. Sincronizar dev con main
git checkout main && git pull
git checkout dev && git pull
git merge main && git push  # trae el chore(release): X.Y.Z y redeploya dev
```

> El commit de release no lleva `[skip ci]`; CI ignora pushes hechos con `GITHUB_TOKEN` para evitar loops.

## Conventional Commits

| Prefijo | Bump |
|---|---|
| `feat:` | minor |
| `fix:` / `perf:` | patch |
| `refactor:` / `chore:` / `docs:` / `style:` / `test:` / `build:` / `ci:` | patch |
| `feat!:` / `fix!:` / `BREAKING CHANGE:` en body | major |

## Verificar la versión deployada

En `locale.com.ar/{{MINIAPP_ID}}?mini-app-dev-mode=true` o `locale.com.ar/{{MINIAPP_ID}}`, abrir el modal de info muestra:

```
Versión de la mini-app actual: 0.1.0 · a1b2c3d
```

Para confirmar contra tu local:

```bash
git rev-parse --short HEAD
```

## Forzar deploy manual

```bash
gh workflow run deploy-dev.yml --ref dev
gh workflow run deploy-prod.yml --ref main   # sin pasar por semantic-release
```

## Auth setup (ES256 + JWKS) — paso manual, una vez por mini-app

> Esta parte hoy no está automatizada. Hay que hacerla una vez al crear la mini-app.

1. **Generar keypair ES256** (en `locale-core`, hay un script). Ejemplo manual con `openssl`:
   ```bash
   openssl ecparam -name prime256v1 -genkey -noout -out private.pem
   openssl ec -in private.pem -pubout -out public.pem
   ```
2. **Registrar el miniapp en `locale-core`**:
   - Agregar entry en la config con `id="{{MINIAPP_ID}}"`, public key (JWK).
   - Configurar env var `{{MINIAPP_ID_UPPER}}_ES256_ENV_PRIVATE_KEY` en Fly.io secrets del core.
   - Agregar `id="{{MINIAPP_ID}}"` al registry para que `/{{MINIAPP_ID}}/` rutee correctamente.
3. **Configurar JWKS en el Supabase del miniapp**:
   Settings → Auth → JWT Keys → Custom → apuntar al endpoint público del core que expone la public key.

Esto permite RLS nativo: `auth.uid() = sub` del JWT firmado por el kernel.

## Cómo se calcula la versión visible

```
deploy-dev.yml | release.yml
  └── exporta MINIAPP_GIT_SHA={github.sha}
       └── make deploy-* → bun run deploy
            └── @locale-labs/miniapp-builder (deploy.ts)
                 └── POST a deploy_miniapp { version, git_sha, html_content, env }
                      └── storage: builds/{version}/index.html
                          register_miniapp_version → core: "1.1.0+a1b2c3d"
                          core's routes/index.tsx reemplaza "+" por " · "
                          → modal: "1.1.0 · a1b2c3d"
```
