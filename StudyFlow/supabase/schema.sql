-- StudyFlow database schema
-- Run this in the Supabase SQL Editor

create extension if not exists "uuid-ossp";

-- =========================================
-- PROFILES
-- =========================================
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  display_name text,
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);

drop policy if exists "profiles_delete_own" on public.profiles;
create policy "profiles_delete_own" on public.profiles
  for delete using (auth.uid() = id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =========================================
-- TASKS
-- =========================================
create table if not exists public.tasks (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  description text,
  due_date date,
  due_time time,
  category text,
  completed boolean not null default false,
  routine_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists tasks_user_id_idx on public.tasks(user_id);
create index if not exists tasks_due_date_idx on public.tasks(due_date);
create index if not exists tasks_routine_id_idx on public.tasks(routine_id);

alter table public.tasks enable row level security;

drop policy if exists "tasks_select_own" on public.tasks;
create policy "tasks_select_own" on public.tasks for select using (auth.uid() = user_id);
drop policy if exists "tasks_insert_own" on public.tasks;
create policy "tasks_insert_own" on public.tasks for insert with check (auth.uid() = user_id);
drop policy if exists "tasks_update_own" on public.tasks;
create policy "tasks_update_own" on public.tasks for update using (auth.uid() = user_id);
drop policy if exists "tasks_delete_own" on public.tasks;
create policy "tasks_delete_own" on public.tasks for delete using (auth.uid() = user_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists tasks_set_updated_at on public.tasks;
create trigger tasks_set_updated_at
  before update on public.tasks
  for each row execute function public.set_updated_at();

-- =========================================
-- SCHEDULE_BLOCKS
-- =========================================
create table if not exists public.schedule_blocks (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject text not null,
  location text,
  teacher text,
  color text,
  day_of_week smallint not null check (day_of_week between 1 and 7),
  start_time time not null,
  end_time time not null,
  created_at timestamptz not null default now()
);

create index if not exists schedule_blocks_user_id_idx on public.schedule_blocks(user_id);
create index if not exists schedule_blocks_day_idx on public.schedule_blocks(day_of_week);

alter table public.schedule_blocks enable row level security;

drop policy if exists "schedule_select_own" on public.schedule_blocks;
create policy "schedule_select_own" on public.schedule_blocks for select using (auth.uid() = user_id);
drop policy if exists "schedule_insert_own" on public.schedule_blocks;
create policy "schedule_insert_own" on public.schedule_blocks for insert with check (auth.uid() = user_id);
drop policy if exists "schedule_update_own" on public.schedule_blocks;
create policy "schedule_update_own" on public.schedule_blocks for update using (auth.uid() = user_id);
drop policy if exists "schedule_delete_own" on public.schedule_blocks;
create policy "schedule_delete_own" on public.schedule_blocks for delete using (auth.uid() = user_id);

-- =========================================
-- ROUTINES
-- =========================================
create table if not exists public.routines (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null check (type in ('exams','work','sport','daily')),
  name text not null,
  config jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists routines_user_id_idx on public.routines(user_id);
create index if not exists routines_type_idx on public.routines(type);

alter table public.routines enable row level security;

drop policy if exists "routines_select_own" on public.routines;
create policy "routines_select_own" on public.routines for select using (auth.uid() = user_id);
drop policy if exists "routines_insert_own" on public.routines;
create policy "routines_insert_own" on public.routines for insert with check (auth.uid() = user_id);
drop policy if exists "routines_update_own" on public.routines;
create policy "routines_update_own" on public.routines for update using (auth.uid() = user_id);
drop policy if exists "routines_delete_own" on public.routines;
create policy "routines_delete_own" on public.routines for delete using (auth.uid() = user_id);

alter table public.tasks drop constraint if exists tasks_routine_id_fkey;
alter table public.tasks add constraint tasks_routine_id_fkey
  foreign key (routine_id) references public.routines(id) on delete set null;

-- =========================================
-- ROUTINE_ITEMS
-- =========================================
create table if not exists public.routine_items (
  id uuid primary key default uuid_generate_v4(),
  routine_id uuid not null references public.routines(id) on delete cascade,
  name text not null,
  metadata jsonb not null default '{}'::jsonb,
  due_date date,
  completed boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists routine_items_routine_id_idx on public.routine_items(routine_id);
create index if not exists routine_items_due_date_idx on public.routine_items(due_date);

alter table public.routine_items enable row level security;

drop policy if exists "routine_items_select_own" on public.routine_items;
create policy "routine_items_select_own" on public.routine_items
  for select using (exists (select 1 from public.routines r where r.id = routine_items.routine_id and r.user_id = auth.uid()));
drop policy if exists "routine_items_insert_own" on public.routine_items;
create policy "routine_items_insert_own" on public.routine_items
  for insert with check (exists (select 1 from public.routines r where r.id = routine_items.routine_id and r.user_id = auth.uid()));
drop policy if exists "routine_items_update_own" on public.routine_items;
create policy "routine_items_update_own" on public.routine_items
  for update using (exists (select 1 from public.routines r where r.id = routine_items.routine_id and r.user_id = auth.uid()));
drop policy if exists "routine_items_delete_own" on public.routine_items;
create policy "routine_items_delete_own" on public.routine_items
  for delete using (exists (select 1 from public.routines r where r.id = routine_items.routine_id and r.user_id = auth.uid()));

-- =========================================
-- NOTES_FILES
-- =========================================
create table if not exists public.notes_files (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  routine_id uuid references public.routines(id) on delete cascade,
  file_url text not null,
  file_type text,
  extracted_text text,
  created_at timestamptz not null default now()
);

create index if not exists notes_files_user_id_idx on public.notes_files(user_id);
create index if not exists notes_files_routine_id_idx on public.notes_files(routine_id);

alter table public.notes_files enable row level security;

drop policy if exists "notes_files_select_own" on public.notes_files;
create policy "notes_files_select_own" on public.notes_files for select using (auth.uid() = user_id);
drop policy if exists "notes_files_insert_own" on public.notes_files;
create policy "notes_files_insert_own" on public.notes_files for insert with check (auth.uid() = user_id);
drop policy if exists "notes_files_update_own" on public.notes_files;
create policy "notes_files_update_own" on public.notes_files for update using (auth.uid() = user_id);
drop policy if exists "notes_files_delete_own" on public.notes_files;
create policy "notes_files_delete_own" on public.notes_files for delete using (auth.uid() = user_id);

-- =========================================
-- STORAGE BUCKET
-- =========================================
insert into storage.buckets (id, name, public)
values ('notes', 'notes', false)
on conflict (id) do nothing;

drop policy if exists "notes_bucket_select_own" on storage.objects;
create policy "notes_bucket_select_own" on storage.objects
  for select using (bucket_id = 'notes' and auth.uid()::text = (storage.foldername(name))[1]);
drop policy if exists "notes_bucket_insert_own" on storage.objects;
create policy "notes_bucket_insert_own" on storage.objects
  for insert with check (bucket_id = 'notes' and auth.uid()::text = (storage.foldername(name))[1]);
drop policy if exists "notes_bucket_update_own" on storage.objects;
create policy "notes_bucket_update_own" on storage.objects
  for update using (bucket_id = 'notes' and auth.uid()::text = (storage.foldername(name))[1]);
drop policy if exists "notes_bucket_delete_own" on storage.objects;
create policy "notes_bucket_delete_own" on storage.objects
  for delete using (bucket_id = 'notes' and auth.uid()::text = (storage.foldername(name))[1]);

-- =========================================
-- REALTIME
-- =========================================
alter publication supabase_realtime add table public.tasks;
alter publication supabase_realtime add table public.schedule_blocks;
alter publication supabase_realtime add table public.routines;
alter publication supabase_realtime add table public.routine_items;

-- =========================================
-- USER_PROFILE_CONTEXT (StudyFlow v2 onboarding)
-- =========================================
create table if not exists public.user_profile_context (
  user_id uuid primary key references auth.users(id) on delete cascade,
  profile_type text not null check (profile_type in ('student','professional','mixed')),
  context jsonb not null default '{}'::jsonb,
  onboarding_completed boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.user_profile_context enable row level security;

drop policy if exists "user_profile_context_select_own" on public.user_profile_context;
create policy "user_profile_context_select_own" on public.user_profile_context
  for select using (auth.uid() = user_id);

drop policy if exists "user_profile_context_insert_own" on public.user_profile_context;
create policy "user_profile_context_insert_own" on public.user_profile_context
  for insert with check (auth.uid() = user_id);

drop policy if exists "user_profile_context_update_own" on public.user_profile_context;
create policy "user_profile_context_update_own" on public.user_profile_context
  for update using (auth.uid() = user_id);

drop policy if exists "user_profile_context_delete_own" on public.user_profile_context;
create policy "user_profile_context_delete_own" on public.user_profile_context
  for delete using (auth.uid() = user_id);

drop trigger if exists user_profile_context_set_updated_at on public.user_profile_context;
create trigger user_profile_context_set_updated_at
  before update on public.user_profile_context
  for each row execute function public.set_updated_at();

alter publication supabase_realtime add table public.user_profile_context;

-- =========================================
-- TUTOR CONVERSATIONS
-- =========================================
alter table public.notes_files
  add column if not exists subject text;

create index if not exists notes_files_subject_idx on public.notes_files(subject);

create table if not exists public.tutor_conversations (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject text not null,
  messages jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists tutor_conversations_user_id_idx on public.tutor_conversations(user_id);
create index if not exists tutor_conversations_subject_idx on public.tutor_conversations(subject);

alter table public.tutor_conversations enable row level security;

drop policy if exists "tutor_conversations_select_own" on public.tutor_conversations;
create policy "tutor_conversations_select_own" on public.tutor_conversations
  for select using (auth.uid() = user_id);

drop policy if exists "tutor_conversations_insert_own" on public.tutor_conversations;
create policy "tutor_conversations_insert_own" on public.tutor_conversations
  for insert with check (auth.uid() = user_id);

drop policy if exists "tutor_conversations_update_own" on public.tutor_conversations;
create policy "tutor_conversations_update_own" on public.tutor_conversations
  for update using (auth.uid() = user_id);

drop policy if exists "tutor_conversations_delete_own" on public.tutor_conversations;
create policy "tutor_conversations_delete_own" on public.tutor_conversations
  for delete using (auth.uid() = user_id);

drop trigger if exists tutor_conversations_set_updated_at on public.tutor_conversations;
create trigger tutor_conversations_set_updated_at
  before update on public.tutor_conversations
  for each row execute function public.set_updated_at();

alter publication supabase_realtime add table public.tutor_conversations;
