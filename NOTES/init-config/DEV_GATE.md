## Crear tabla para dev-gate (correr en proyecto dev)

```sql
-- Habilitar pgcrypto (para crypt/gen_salt)
create extension if not exists pgcrypto;

-- Tabla privada (no leíble por anon vía RLS deny)
create table if not exists public.dev_gate_config (
  id smallint primary key check (id = 1),
  password_hash text not null,
  updated_at timestamptz default now()
);

alter table public.dev_gate_config enable row level security;
-- (sin policies → ningún rol que no sea service_role puede leer/escribir)

-- RPC pública: compara password contra el hash sin exponerlo.
-- SECURITY DEFINER permite bypass de RLS dentro de la función.
-- IMPORTANT: include `extensions` in search_path because Supabase installs
-- pgcrypto (crypt/gen_salt) in the `extensions` schema, not `public`. With
-- SECURITY DEFINER + a hardcoded search_path, omitting it breaks crypt().
create or replace function public.dev_gate_verify(p text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  stored_hash text;
begin
  select password_hash into stored_hash from public.dev_gate_config where id = 1;
  if stored_hash is null then
    return false;
  end if;
  return crypt(p, stored_hash) = stored_hash;
end;
$$;

revoke all on function public.dev_gate_verify(text) from public;
grant execute on function public.dev_gate_verify(text) to anon, authenticated;
```

## Setear el password (correr una vez con un password real):

```sql
insert into public.dev_gate_config (id, password_hash)
values (1, crypt('TU_PASSWORD_AQUI', gen_salt('bf', 10)))
on conflict (id) do update
  set password_hash = excluded.password_hash,
      updated_at = now();
```