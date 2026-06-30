# CONVENTIONS — núcleo de las miniapps de Locale

> **Para la IA (Claude):** este documento es el *source of truth* de convenciones y
> mejoras acumuladas de todas las miniapps. Al crear o trabajar en una miniapp,
> **seguí estas reglas por defecto** salvo que el usuario pida otra cosa.
>
> **Regla meta — captura de mejoras:** cada vez que encuentres una mejora, patrón o
> buena práctica en una miniapp concreta que **todavía no esté en este documento**,
> **pausá y preguntá al usuario si querés agregarla acá**. Así el núcleo de futuras
> miniapps mejora solo mientras trabajamos. No la agregues sin confirmación; al
> agregarla, anotá de qué miniapp salió y la fecha.

Cada miniapp arranca como copia de este boilerplate. Lo que vive acá debería poder
nacer ya implementado en el template (idealmente), o al menos quedar documentado para
portarse a mano.

---

## 1. Estructura de archivos

```
src/
  alpine.ts                 # entry: instancia LocaleApp, define AppState, monta stores
  features/<feature>/
    index.ts                # store Alpine del feature (createXStore)
    types.ts                # tipos del feature
    api.ts                  # (opcional) llamadas REST del feature, si no usa utils/rest.ts genérico
  html/
    index.html              # SHELL únicamente: head + estados de acceso + header/menú/toast + <include>
    views/<feature>.html    # 1 pantalla por feature (espeja src/features/)
    components/<name>.html   # piezas reutilizables (toast, alerts, iconos)
  utils/                    # helpers transversales (ver sección 3)
  supabase-config-data.ts   # config Supabase mutable (kernel la inyecta en runtime)
```

**Reglas:**
- **HTML split obligatorio cuando `index.html` crece.** No dejar un monolito de cientos
  de líneas. El shell queda en `index.html` y monta cada pantalla con
  `<include src="views/<feature>.html">`. El builder (`@locale-labs/miniapp-builder`)
  resuelve `<include>` recursivo e inlinea todo → el output sigue siendo **un HTML único
  self-contained**. El scope Alpine (`x-data`) se preserva porque el include se reemplaza
  in-place. (Origen: mascotas-perdidas; aplicado a arquería 2026-06-20.)
- **Las views espejan los features.** `views/turnos.html` ↔ `features/turnos/`. Facilita
  encontrar el HTML de una pantalla y mantener lógica+UI alineadas.
- **Componentes reutilizables en `components/`** (ej. `toast.html`, `components/icons/*.html`).
- **Un feature = una carpeta.** Para CRUDs simples basta `index.ts` + `types.ts`. Para
  flujos complejos (wizards multi-step) subdividir: `api.ts`, `constants.ts`, `steps/`, etc.
  (patrón de mascotas `create_post/`).

## 2. Estado y stores (Alpine)

- `alpine.ts` define la interface `AppState` y la función factory (`miniApp()` / `<slug>App()`).
- Cada feature exporta un `create<Feature>Store()` y se compone en `AppState`.
- Métodos transversales viven en el root (`showToast`, `copyText`, `confirmRemove`, navegación).

## 3. Utils transversales (baseline recomendado)

Helpers que probaron ser útiles cross-miniapp. **Idealmente vivir en el boilerplate.**

- **`utils/fetch.ts` — `authenticatedFetch(url, token, options, apiKey)`** con
  **`cache: 'no-store'`** (en mobile/proxy los GET quedaban stale). _(arquería)_
- **`utils/rest.ts` — CRUD tipado sobre PostgREST + retry ante JWT vencido.**
  `restSelect/Insert/Update/Delete`. Detecta `401 PGRST303 "JWT expired"` y reintenta
  **una vez** con token fresco via `setTokenRefresher` (registrado en `alpine.ts` init
  con `app.getAuthToken()`). Necesario en cualquier app con sesión larga: el JWT del
  kernel se captura 1 vez en `init()` y caduca. _(arquería)_
- **`utils/num.ts` — `toIntOrNull(v)`.** Normaliza el `''` de `x-model.number` a `int | null`. _(arquería)_
- **`utils/access.ts` — gate de app PRIVADA via RPC `is_allowed()`.** Solo para apps
  privadas (staff). La seguridad real es el RLS; esto es UX (pantalla "pendiente"). _(arquería)_
- **`utils/logger.ts` — `logger/logError/logWarn`** con flag `MINIAPP_DEBUG`. _(boilerplate)_

## 4. UX / SDK

- **Confirmaciones y alertas: usar `app.alert()` del SDK, NO `confirm()`/`alert()` del browser.**
  Dentro del iframe sandboxed el diálogo nativo del browser puede salir feo o bloquearse.
  `app.alert(title, message?, buttons?, options?)` con botones `style: 'cancel'|'destructive'`
  y `onPress`. Envolver en helper `confirmRemove(message, onConfirm)` con fallback a
  `confirm()` en dev (sin SDK). _(patrón mascotas; helper de arquería)_
- **Toast** para feedback no bloqueante (`showToast(message, type)`), store global `toast`.
- Mobile-first: `max-w-3xl`, layout en columna, header fijo + área scrolleable.

## 5. Backend / seguridad

- **Output del build = un único HTML self-contained.** No agregar assets externos en runtime.
- **Toda lectura/escritura con RLS.** Patrón estándar `auth.uid() = owner_id`. El JWT del
  Core ya pone `sub = user.id`. Nunca confiar en datos del cliente para autorizar.
- **No modificar el Core.** Es black-box; API estable por `@locale-labs/protocol`.
- Migraciones: aplicar primero en dev, después prod.

## 6. Calidad de código

- **TypeScript estricto.** `bunx tsc --noEmit` y `bun run lint` deben pasar antes de commitear.
- **Verificar el build** tras refactors de HTML: `bun run build` + chequear que no queden
  `<include>` sin resolver y que el output sea equivalente al previo.
- Nombres y comentarios en el idioma del repo existente. Comentar el *por qué*, no el *qué*.
- No duplicar: si un patrón aparece 2+ veces, extraer a util/componente.

---

## Changelog de convenciones

Anotar acá cada mejora incorporada (qué, de qué miniapp, fecha).

- **2026-06-20** — Doc inicial. Consolidadas mejoras de `arqueriaflordeliz` (rest.ts con
  retry JWT, fetch `cache:no-store`, num.ts, access.ts, helper `confirmRemove`) y
  `mascotas-perdidas` (HTML split views/components, feature sub-split para wizards,
  `app.alert()` nativo).
