-- ============================================================
-- Motex Campus · esquema v3 (seguridad reforzada)
-- Ejecutar en el SQL Editor DESPUES de schema.sql y schema-v2.sql.
-- Idempotente.
--
-- Añade:
--  1. Datos personales INMUTABLES (solo avatar/bio editables).
--  2. Sesión única por cuenta (anti cuentas compartidas), salvo el
--     curso de empresas (el más caro), pensado para equipos.
--  3. Almacenamiento de avatares por usuario.
-- ============================================================

-- ============================================================
-- 1. BLOQUEO DE DATOS PERSONALES
-- ------------------------------------------------------------
-- El alumno NO puede modificar su identidad ni sus datos de
-- facturación una vez registrado. Solo el equipo (moderador/admin)
-- puede corregirlos. El alumno solo cambia avatar, bio y su token
-- de sesión.
-- ============================================================
create or replace function public.campus_lock_profile_fields()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  -- Permite cambios desde el SQL Editor / service role (sin sesión, auth.uid()
  -- nulo) y al equipo. Para el alumno corriente, los datos quedan bloqueados.
  if auth.uid() is null or public.is_campus_staff() then
    return new;
  end if;
  new.username    := old.username;
  new.email       := old.email;
  new.first_name  := old.first_name;
  new.last_name   := old.last_name;
  new.address     := old.address;
  new.city        := old.city;
  new.country     := old.country;
  new.postal_code := old.postal_code;
  new.gender      := old.gender;
  new.role        := old.role;
  new.created_at  := old.created_at;
  return new;  -- avatar_url, bio y active_session SÍ son editables
end;
$$;

drop trigger if exists campus_lock_profile on public.campus_profiles;
create trigger campus_lock_profile
  before update on public.campus_profiles
  for each row execute function public.campus_lock_profile_fields();

-- ============================================================
-- 2. SESIÓN ÚNICA POR CUENTA
-- ------------------------------------------------------------
-- Guardamos un token del dispositivo activo. Al iniciar sesión se
-- genera uno nuevo; los demás dispositivos quedan invalidados al
-- detectar que su token ya no coincide. Excepción: si la cuenta
-- tiene acceso al curso 'empresas', se permite uso en equipo.
-- ============================================================
alter table public.campus_profiles add column if not exists active_session uuid;

create or replace function public.campus_has_team_access()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1
    from public.enrollments e
    join public.courses c on c.id = e.course_id
    where e.user_id = auth.uid() and e.status = 'active' and c.slug = 'empresas'
  );
$$;
grant execute on function public.campus_has_team_access() to authenticated;

-- ============================================================
-- 3. ALMACENAMIENTO DE AVATARES
-- ------------------------------------------------------------
-- Bucket público (solo imágenes pequeñas de perfil). Cada usuario
-- escribe únicamente en su propia carpeta: campus-avatars/<uid>/...
-- ============================================================
insert into storage.buckets (id, name, public)
values ('campus-avatars', 'campus-avatars', true)
on conflict (id) do nothing;

drop policy if exists "avatars_read" on storage.objects;
create policy "avatars_read" on storage.objects
  for select using (bucket_id = 'campus-avatars');

drop policy if exists "avatars_insert_own" on storage.objects;
create policy "avatars_insert_own" on storage.objects
  for insert with check (bucket_id = 'campus-avatars' and auth.uid()::text = (storage.foldername(name))[1]);

drop policy if exists "avatars_update_own" on storage.objects;
create policy "avatars_update_own" on storage.objects
  for update using (bucket_id = 'campus-avatars' and auth.uid()::text = (storage.foldername(name))[1]);

drop policy if exists "avatars_delete_own" on storage.objects;
create policy "avatars_delete_own" on storage.objects
  for delete using (bucket_id = 'campus-avatars' and auth.uid()::text = (storage.foldername(name))[1]);
