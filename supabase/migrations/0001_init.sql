-- Boilerplate: Hello World feature.
-- Crea una tabla `items` con RLS para que el SDK + JWT del kernel funcione end-to-end.
-- Reemplazá esta migration por las propias del dominio cuando empieces a construir tu mini-app.

create extension if not exists "pgcrypto";

create table if not exists public.items (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null,
  place_id text not null,
  content text not null,
  created_at timestamptz not null default now()
);

create index if not exists items_place_id_idx on public.items (place_id);
create index if not exists items_owner_id_idx on public.items (owner_id);

alter table public.items enable row level security;

create policy "items_select_all" on public.items
  for select
  using (true);

create policy "items_insert_authenticated" on public.items
  for insert
  with check (auth.uid() = owner_id);

create policy "items_update_own" on public.items
  for update
  using (auth.uid() = owner_id);

create policy "items_delete_own" on public.items
  for delete
  using (auth.uid() = owner_id);
