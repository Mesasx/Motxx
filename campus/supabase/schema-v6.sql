-- ============================================================
-- Motex Campus · esquema v6 (Comunidad / foro)
-- Ejecutar DESPUES de schema.sql, v2, v3, v4 y v5. Idempotente.
--
-- Tablón de la comunidad: publicaciones con PDF adjunto opcional
-- e ideas, más comentarios. Visible para cualquier alumno con la
-- cuenta verificada. El equipo puede moderar (borrar cualquier cosa).
-- ============================================================

-- ---- Publicaciones ----
create table if not exists public.community_posts (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  author_name text,
  title       text not null,
  body        text,
  file_url    text,
  file_name   text,
  created_at  timestamptz not null default now()
);
alter table public.community_posts add column if not exists author_name text;
create index if not exists community_posts_created_idx on public.community_posts(created_at desc);

alter table public.community_posts enable row level security;

drop policy if exists "community_posts_select" on public.community_posts;
create policy "community_posts_select" on public.community_posts
  for select using (auth.uid() is not null);

drop policy if exists "community_posts_insert_own" on public.community_posts;
create policy "community_posts_insert_own" on public.community_posts
  for insert with check (auth.uid() = user_id);

drop policy if exists "community_posts_update_own" on public.community_posts;
create policy "community_posts_update_own" on public.community_posts
  for update using (auth.uid() = user_id or public.is_campus_staff());

drop policy if exists "community_posts_delete_own" on public.community_posts;
create policy "community_posts_delete_own" on public.community_posts
  for delete using (auth.uid() = user_id or public.is_campus_staff());

-- ---- Comentarios ----
create table if not exists public.community_comments (
  id          uuid primary key default uuid_generate_v4(),
  post_id     uuid not null references public.community_posts(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  author_name text,
  body        text not null,
  created_at  timestamptz not null default now()
);
alter table public.community_comments add column if not exists author_name text;
create index if not exists community_comments_post_idx on public.community_comments(post_id);

alter table public.community_comments enable row level security;

drop policy if exists "community_comments_select" on public.community_comments;
create policy "community_comments_select" on public.community_comments
  for select using (auth.uid() is not null);

drop policy if exists "community_comments_insert_own" on public.community_comments;
create policy "community_comments_insert_own" on public.community_comments
  for insert with check (auth.uid() = user_id);

drop policy if exists "community_comments_delete_own" on public.community_comments;
create policy "community_comments_delete_own" on public.community_comments
  for delete using (auth.uid() = user_id or public.is_campus_staff());

-- ---- Almacenamiento de archivos compartidos (PDF) ----
insert into storage.buckets (id, name, public)
values ('campus-files', 'campus-files', true)
on conflict (id) do nothing;

drop policy if exists "files_read" on storage.objects;
create policy "files_read" on storage.objects
  for select using (bucket_id = 'campus-files');

drop policy if exists "files_insert_own" on storage.objects;
create policy "files_insert_own" on storage.objects
  for insert with check (bucket_id = 'campus-files' and auth.uid()::text = (storage.foldername(name))[1]);

drop policy if exists "files_delete_own" on storage.objects;
create policy "files_delete_own" on storage.objects
  for delete using (bucket_id = 'campus-files' and auth.uid()::text = (storage.foldername(name))[1]);
