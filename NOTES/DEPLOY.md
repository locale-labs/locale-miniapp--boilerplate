# Deploy — `{{MINIAPP_ID}}`

- **`dev`** → cada push deploya al entorno dev (Supabase functions + storage del miniapp dev). No bumpea versión.
- **`main`** → semantic-release bumpea versión, genera CHANGELOG, crea release/tag, y deploya a prod.

La versión que ves en el modal del core sale de `package.json` + el SHA corto del commit deployado. El builder envía ambos al edge function `deploy_miniapp`, que los combina como semver build-metadata (`1.1.0+a1b2c3d`) y el core los re-formatea como `1.1.0 · a1b2c3d`.

> 🏷️ **Versionado beta (0.x).** La mini-app nace en `0.1.0`: `scripts/init-template.sh` crea el tag seed `v0.1.0` en el commit de init. `semantic-release` calcula la próxima versión desde el último git tag, **no** desde `package.json` — sin el seed, el primer release saltaría a `1.0.0`. Con el seed los releases avanzan `0.1.1` (`fix`) / `0.2.0` (`feat`) y se quedan en `0.x` hasta que un cambio breaking (o un bump manual) los lleve a `1.0.0`. El tag tiene que estar en el remoto antes del primer release a `main` (`git push --tags`, Paso 9 del [FIRST_STEPS.md](../FIRST_STEPS.md)).

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

# 3.1. Esperar a que termine la action del merge (bloquea hasta que termine,
# sale != 0 si falla). El sleep da tiempo a que el run se registre.
sleep 5 && gh run watch --repo locale-labs/locale-miniapp--boilerplate --exit-status \
  "$(gh run list --repo locale-labs/locale-miniapp--boilerplate --workflow release.yml --branch main --limit 1 --json databaseId --jq '.[0].databaseId')"

# 3.2. Sincronizar dev con main
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

## Auth setup (ES256 + JWK import) — paso manual, una vez por mini-app

> Esta parte hoy no está automatizada. Hay que hacerla una vez al crear la mini-app. Detalle paso a paso en [FIRST_STEPS.md Paso 6](./FIRST_STEPS.md).

1. **Generar keypair + registrar** desde `locale-core`:
   ```bash
   cd locale-core && bun run scripts/register-miniapp.ts --slug {{MINIAPP_ID}} --name "{{MINIAPP_NAME}}"
   ```
   Genera `.keys/{{MINIAPP_ID}}-private-{dev,prod}.pem` + `.keys/{{MINIAPP_ID}}-{dev,prod}.kid`, inserta en Core DEV Supabase, e imprime el resto.

2. **Setear Fly secrets** (output del script — `{{MINIAPP_ID_UPPER}}_ES256_{DEV,PROD}_{PRIVATE_KEY,KID}`).

3. **Importar JWK en el Supabase del miniapp** (dev y prod):
   - URL: `https://supabase.com/dashboard/project/<ref>/settings/jwt`
   - `Create Standby Key` → `Import` → pegar JWK privado (snippet Node en `FIRST_STEPS.md` 6.4)
   - Promover Standby → Current
   - ⚠️ Es JSON (JWK con `d`), no PEM ni JWKS URL.

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
