-- ============================================================
-- Motex Campus · INSTALACION COMPLETA (todo en uno)
-- Ejecuta este archivo entero en el SQL Editor de Supabase,
-- en el proyecto correcto (BotCarricoche). Es idempotente:
-- puedes ejecutarlo las veces que quieras sin romper nada.
-- Incluye: base + v2 (espacio privado) + v3 (seguridad) +
-- v4 (moderacion) + v5 (roles) + v6 (comunidad/foro).
-- ============================================================


-- ====================== schema.sql ======================

-- ============================================================
-- Motex Campus · esquema de base de datos (Supabase / PostgreSQL)
-- Ejecuta este archivo en el SQL Editor de Supabase.
--
-- Es independiente del esquema de StudyFlow: usa sus propias
-- tablas (campus_*) y un trigger propio sobre auth.users que solo
-- actua cuando el registro llega desde el campus, asi no interfiere
-- con otros productos que compartan el mismo proyecto de Supabase.
-- ============================================================

create extension if not exists "uuid-ossp";

-- ============================================================
-- 1. PERFILES DEL CAMPUS
-- ============================================================
create table if not exists public.campus_profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  username     text unique not null,
  email        text not null,
  first_name   text not null default '',
  last_name    text not null default '',
  address      text,
  city         text,
  country      text,
  postal_code  text,
  phone        text,
  gender       text,
  role         text not null default 'student' check (role in ('student','moderator','admin')),
  created_at   timestamptz not null default now()
);

create index if not exists campus_profiles_username_idx on public.campus_profiles(username);

alter table public.campus_profiles enable row level security;

-- ¿El usuario actual es parte del equipo (moderador/admin)?
create or replace function public.is_campus_staff()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.campus_profiles p
    where p.id = auth.uid() and p.role in ('moderator','admin')
  );
$$;

drop policy if exists "campus_profiles_select" on public.campus_profiles;
create policy "campus_profiles_select" on public.campus_profiles
  for select using (auth.uid() = id or public.is_campus_staff());

drop policy if exists "campus_profiles_insert_own" on public.campus_profiles;
create policy "campus_profiles_insert_own" on public.campus_profiles
  for insert with check (auth.uid() = id);

-- El usuario puede editar sus datos, pero NO puede cambiarse el rol.
drop policy if exists "campus_profiles_update_own" on public.campus_profiles;
create policy "campus_profiles_update_own" on public.campus_profiles
  for update using (auth.uid() = id)
  with check (auth.uid() = id and role = (select role from public.campus_profiles where id = auth.uid()));

-- Alta automatica del perfil cuando el registro llega desde el campus.
-- Solo se dispara si los metadatos traen 'campus_username', de modo que
-- los registros de otros productos del mismo proyecto no se ven afectados.
create or replace function public.handle_new_campus_user()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if (new.raw_user_meta_data ? 'campus_username') then
    insert into public.campus_profiles (
      id, email, username, first_name, last_name,
      address, city, country, postal_code, phone, gender
    )
    values (
      new.id,
      new.email,
      new.raw_user_meta_data->>'campus_username',
      coalesce(new.raw_user_meta_data->>'first_name', ''),
      coalesce(new.raw_user_meta_data->>'last_name', ''),
      new.raw_user_meta_data->>'address',
      new.raw_user_meta_data->>'city',
      new.raw_user_meta_data->>'country',
      new.raw_user_meta_data->>'postal_code',
      new.raw_user_meta_data->>'phone',
      new.raw_user_meta_data->>'gender'
    )
    on conflict (id) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_campus on auth.users;
create trigger on_auth_user_created_campus
  after insert on auth.users
  for each row execute function public.handle_new_campus_user();

-- Comprueba si un nombre de usuario ya esta cogido. Devuelve solo un
-- booleano (no expone correos), para validar el alta sin filtrar PII.
create or replace function public.campus_username_taken(p_username text)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from public.campus_profiles p where p.username = p_username);
$$;

grant execute on function public.campus_username_taken(text) to anon, authenticated;

-- Compatibilidad: si existia la version anterior que devolvia el email,
-- se elimina (era una via de enumeracion de correos).
drop function if exists public.campus_email_for_username(text);

-- ============================================================
-- 2. CURSOS
-- ============================================================
create table if not exists public.courses (
  id          uuid primary key default uuid_generate_v4(),
  slug        text unique not null,
  title       text not null,
  subtitle    text,
  description text,
  level       text,
  hours       int,
  price_cents int not null default 0,
  currency    text not null default 'EUR',
  sort_order  int not null default 0,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

alter table public.courses enable row level security;

-- Los cursos activos son visibles para todos (incluso sin sesion);
-- el equipo ve tambien los inactivos.
drop policy if exists "courses_select_public" on public.courses;
create policy "courses_select_public" on public.courses
  for select using (active or public.is_campus_staff());

drop policy if exists "courses_write_staff" on public.courses;
create policy "courses_write_staff" on public.courses
  for all using (public.is_campus_staff()) with check (public.is_campus_staff());

-- Tabla de matriculas (se define antes porque la politica de
-- 'lessons' la referencia; las politicas se anaden en la seccion 4).
create table if not exists public.enrollments (
  id         uuid primary key default uuid_generate_v4(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  course_id  uuid not null references public.courses(id) on delete cascade,
  status     text not null default 'active' check (status in ('active','pending','refunded')),
  created_at timestamptz not null default now(),
  unique (user_id, course_id)
);

-- ============================================================
-- 3. CLASES / LECCIONES
-- ============================================================
create table if not exists public.lessons (
  id           uuid primary key default uuid_generate_v4(),
  course_id    uuid not null references public.courses(id) on delete cascade,
  title        text not null,
  summary      text,
  content      text,
  video_url    text,
  duration_min int,
  is_free      boolean not null default false,
  sort_order   int not null default 0,
  created_at   timestamptz not null default now()
);

create index if not exists lessons_course_id_idx on public.lessons(course_id);

alter table public.lessons enable row level security;

-- Una clase es visible si: es la clase gratuita, el usuario ha comprado
-- el curso, o es parte del equipo.
drop policy if exists "lessons_select" on public.lessons;
create policy "lessons_select" on public.lessons
  for select using (
    is_free
    or public.is_campus_staff()
    or exists (
      select 1 from public.enrollments e
      where e.course_id = lessons.course_id
        and e.user_id = auth.uid()
        and e.status = 'active'
    )
  );

drop policy if exists "lessons_write_staff" on public.lessons;
create policy "lessons_write_staff" on public.lessons
  for all using (public.is_campus_staff()) with check (public.is_campus_staff());

-- Metadatos de las clases (titulo, si es gratis, orden y duracion) sin
-- exponer el contenido. Sirve para pintar el temario con candados.
create or replace view public.lessons_catalog as
  select id, course_id, title, summary, duration_min, is_free, sort_order
  from public.lessons;

grant select on public.lessons_catalog to anon, authenticated;

-- ============================================================
-- 4. MATRICULAS (acceso a un curso tras el pago)
-- ============================================================
create table if not exists public.enrollments (
  id         uuid primary key default uuid_generate_v4(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  course_id  uuid not null references public.courses(id) on delete cascade,
  status     text not null default 'active' check (status in ('active','pending','refunded')),
  created_at timestamptz not null default now(),
  unique (user_id, course_id)
);

create index if not exists enrollments_user_id_idx on public.enrollments(user_id);

alter table public.enrollments enable row level security;

-- El alumno ve sus matriculas; el equipo las ve todas.
drop policy if exists "enrollments_select" on public.enrollments;
create policy "enrollments_select" on public.enrollments
  for select using (auth.uid() = user_id or public.is_campus_staff());

-- Las altas de pago las hace la funcion de servidor (service role, que
-- ignora RLS). Desde el cliente solo el equipo puede matricular a mano.
drop policy if exists "enrollments_write_staff" on public.enrollments;
create policy "enrollments_write_staff" on public.enrollments
  for all using (public.is_campus_staff()) with check (public.is_campus_staff());

-- ============================================================
-- 5. PAGOS
-- ============================================================
create table if not exists public.payments (
  id           uuid primary key default uuid_generate_v4(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  course_id    uuid references public.courses(id) on delete set null,
  amount_cents int not null,
  currency     text not null default 'EUR',
  method       text,                    -- 'card' | 'paypal' | 'apple_pay'
  provider     text not null default 'stripe',
  provider_ref text,                     -- id de sesion/cobro del proveedor
  status       text not null default 'pending' check (status in ('pending','paid','failed','refunded')),
  created_at   timestamptz not null default now()
);

create index if not exists payments_user_id_idx on public.payments(user_id);

alter table public.payments enable row level security;

drop policy if exists "payments_select" on public.payments;
create policy "payments_select" on public.payments
  for select using (auth.uid() = user_id or public.is_campus_staff());

drop policy if exists "payments_write_staff" on public.payments;
create policy "payments_write_staff" on public.payments
  for all using (public.is_campus_staff()) with check (public.is_campus_staff());

-- ============================================================
-- 6. CONTENIDO INICIAL (los 3 cursos de la web)
-- ============================================================
insert into public.courses (slug, title, subtitle, description, level, hours, price_cents, currency, sort_order)
values
  ('iniciacion',
   'IA para PYMEs y autonomos',
   'Nivel iniciacion - 20 horas',
   'Aprende a usar la IA para redactar, responder, resumir, organizar tareas y ahorrar horas sin conocimientos tecnicos previos.',
   'Iniciacion', 20, 19700, 'EUR', 1),
  ('premium',
   'Automatiza tu negocio con n8n',
   'Premium - 45 horas',
   'Construye flujos reales para leads, correos, reservas, informes, documentos y avisos conectados con tus herramientas.',
   'Premium', 45, 39700, 'EUR', 2),
  ('empresas',
   'Formacion in-company',
   'Empresas - desde 60 horas',
   'Programa a medida para equipos. Creamos una plataforma formativa adaptada a vuestro sector, procesos y herramientas internas.',
   'Empresas', 60, 69000, 'EUR', 3)
on conflict (slug) do nothing;

-- Clases del curso de iniciacion. La primera es GRATIS para cualquier
-- alumno registrado; el resto requiere comprar el curso.
insert into public.lessons (course_id, title, summary, content, duration_min, is_free, sort_order)
select c.id, v.title, v.summary, v.content, v.duration_min, v.is_free, v.sort_order
from (values
  ('Bienvenida y primeros pasos con la IA',
   'Que es la IA generativa, que puede y que no puede hacer por tu negocio.',
   'Clase de bienvenida. En esta primera leccion gratuita veras como encaja la inteligencia artificial en el dia a dia de una PYME o un autonomo, con ejemplos reales y sin tecnicismos.',
   18, true, 1),
  ('Tu primer asistente de IA',
   'Configura una herramienta de IA y haz tus primeras consultas utiles.',
   'Contenido reservado a alumnos matriculados.', 24, false, 2),
  ('Prompts que ahorran horas',
   'La estructura de un buen prompt para correos, resumenes y textos.',
   'Contenido reservado a alumnos matriculados.', 31, false, 3),
  ('Organiza tareas y documentos con IA',
   'Resume reuniones, clasifica correos y ordena tu informacion.',
   'Contenido reservado a alumnos matriculados.', 27, false, 4),
  ('Buenas practicas y uso seguro',
   'Privacidad, verificacion de respuestas y limites a tener en cuenta.',
   'Contenido reservado a alumnos matriculados.', 22, false, 5)
) as v(title, summary, content, duration_min, is_free, sort_order)
cross join (select id from public.courses where slug = 'iniciacion') c
on conflict do nothing;

-- Clases del curso premium (todas de pago).
insert into public.lessons (course_id, title, summary, content, duration_min, is_free, sort_order)
select c.id, v.title, v.summary, 'Contenido reservado a alumnos matriculados.', v.duration_min, false, v.sort_order
from (values
  ('Introduccion a n8n', 'Que es n8n y como se conecta con tus herramientas.', 26, 1),
  ('Tu primer flujo automatico', 'Construye un flujo de captacion de leads de principio a fin.', 35, 2),
  ('Automatiza correos e informes', 'Genera y envia documentos e informes sin tocar una tecla.', 33, 3),
  ('Integraciones avanzadas', 'Conecta CRM, calendarios y bases de datos.', 40, 4)
) as v(title, summary, duration_min, sort_order)
cross join (select id from public.courses where slug = 'premium') c
on conflict do nothing;

-- Clases del curso de empresas (todas de pago).
insert into public.lessons (course_id, title, summary, content, duration_min, is_free, sort_order)
select c.id, v.title, v.summary, 'Contenido reservado a alumnos matriculados.', v.duration_min, false, v.sort_order
from (values
  ('Diagnostico del equipo', 'Mapa de procesos y oportunidades de automatizacion.', 30, 1),
  ('Ruta formativa a medida', 'Diseno del programa segun sector y herramientas internas.', 30, 2),
  ('Implantacion acompanada', 'Despliegue de los primeros casos reales en la empresa.', 45, 3)
) as v(title, summary, duration_min, sort_order)
cross join (select id from public.courses where slug = 'empresas') c
on conflict do nothing;

-- ============================================================
-- 7. PROMOCION DEL USUARIO MODERADOR
-- ------------------------------------------------------------
-- IMPORTANTE: por seguridad, las contrasenas NO se guardan aqui.
-- Registrate primero desde la propia web del campus
-- (https://aimotex.com/campus/registro/) con el usuario "Mesas".
-- Despues, ejecuta esta linea una sola vez para convertirte en
-- administrador del campus:
--
--   update public.campus_profiles set role = 'admin' where username = 'Mesas';
--
-- A partir de ahi podras crear mas moderadores con:
--   update public.campus_profiles set role = 'moderator' where username = '<usuario>';
-- ============================================================

-- ====================== schema-v2.sql ======================

-- ============================================================
-- Motex Campus · esquema v2 (espacio privado del alumno)
-- Ejecutar en el SQL Editor de Supabase DESPUES de schema.sql.
-- Todo es idempotente: se puede ejecutar varias veces sin romper nada.
-- Añade: progreso de clases, ejercicios y entregas, reserva de
-- mentoria, mensajes de contacto y campos extra de perfil.
-- ============================================================

-- ---- Campos extra de perfil ----
alter table public.campus_profiles add column if not exists avatar_url text;
alter table public.campus_profiles add column if not exists bio text;

-- ============================================================
-- PROGRESO DE CLASES
-- ============================================================
create table if not exists public.lesson_progress (
  user_id      uuid not null references auth.users(id) on delete cascade,
  lesson_id    uuid not null references public.lessons(id) on delete cascade,
  course_id    uuid references public.courses(id) on delete cascade,
  completed    boolean not null default true,
  completed_at timestamptz not null default now(),
  primary key (user_id, lesson_id)
);
create index if not exists lesson_progress_user_idx on public.lesson_progress(user_id);

alter table public.lesson_progress enable row level security;
drop policy if exists "lesson_progress_own" on public.lesson_progress;
create policy "lesson_progress_own" on public.lesson_progress
  for all using (auth.uid() = user_id or public.is_campus_staff())
  with check (auth.uid() = user_id);

-- ============================================================
-- EJERCICIOS (asociados a una clase) Y ENTREGAS
-- ============================================================
create table if not exists public.exercises (
  id         uuid primary key default uuid_generate_v4(),
  lesson_id  uuid references public.lessons(id) on delete cascade,
  course_id  uuid not null references public.courses(id) on delete cascade,
  title      text not null,
  prompt     text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists exercises_course_idx on public.exercises(course_id);

alter table public.exercises enable row level security;
-- Visible si la clase asociada es accesible (gratis / matriculado / equipo).
drop policy if exists "exercises_select" on public.exercises;
create policy "exercises_select" on public.exercises
  for select using (
    public.is_campus_staff()
    or exists (select 1 from public.lessons l where l.id = exercises.lesson_id and l.is_free)
    or exists (select 1 from public.enrollments e
               where e.course_id = exercises.course_id and e.user_id = auth.uid() and e.status = 'active')
  );
drop policy if exists "exercises_write_staff" on public.exercises;
create policy "exercises_write_staff" on public.exercises
  for all using (public.is_campus_staff()) with check (public.is_campus_staff());

create table if not exists public.exercise_submissions (
  id           uuid primary key default uuid_generate_v4(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  exercise_id  uuid not null references public.exercises(id) on delete cascade,
  answer       text not null,
  status       text not null default 'submitted' check (status in ('submitted','reviewed')),
  score        int,
  feedback     text,
  submitted_at timestamptz not null default now(),
  unique (user_id, exercise_id)
);
create index if not exists exercise_submissions_user_idx on public.exercise_submissions(user_id);

alter table public.exercise_submissions enable row level security;
drop policy if exists "exercise_submissions_own" on public.exercise_submissions;
create policy "exercise_submissions_own" on public.exercise_submissions
  for all using (auth.uid() = user_id or public.is_campus_staff())
  with check (auth.uid() = user_id);

-- ============================================================
-- RESERVAS DE MENTORIA
-- ============================================================
create table if not exists public.mentorship_bookings (
  id           uuid primary key default uuid_generate_v4(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  preferred_at timestamptz,
  topic        text,
  notes        text,
  status       text not null default 'pending' check (status in ('pending','confirmed','done','cancelled')),
  created_at   timestamptz not null default now()
);
create index if not exists mentorship_user_idx on public.mentorship_bookings(user_id);

alter table public.mentorship_bookings enable row level security;
drop policy if exists "mentorship_own" on public.mentorship_bookings;
create policy "mentorship_own" on public.mentorship_bookings
  for all using (auth.uid() = user_id or public.is_campus_staff())
  with check (auth.uid() = user_id);

-- ============================================================
-- MENSAJES DE CONTACTO
-- ============================================================
create table if not exists public.contact_messages (
  id         uuid primary key default uuid_generate_v4(),
  user_id    uuid references auth.users(id) on delete set null,
  subject    text,
  message    text not null,
  created_at timestamptz not null default now()
);

alter table public.contact_messages enable row level security;
drop policy if exists "contact_insert" on public.contact_messages;
create policy "contact_insert" on public.contact_messages
  for insert with check (auth.uid() = user_id);
drop policy if exists "contact_select" on public.contact_messages;
create policy "contact_select" on public.contact_messages
  for select using (auth.uid() = user_id or public.is_campus_staff());

-- ============================================================
-- EJERCICIO DE EJEMPLO (en la clase gratuita de iniciacion)
-- ============================================================
insert into public.exercises (lesson_id, course_id, title, prompt, sort_order)
select l.id, l.course_id,
       'Tu primer caso de uso',
       'Describe una tarea repetitiva de tu trabajo o negocio que te gustaria delegar en la IA. ¿Cuanto tiempo te llevaria a la semana?',
       1
from public.lessons l
join public.courses c on c.id = l.course_id
where c.slug = 'iniciacion' and l.sort_order = 1
  and not exists (select 1 from public.exercises e where e.lesson_id = l.id);

-- ====================== schema-v3.sql ======================

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

-- ====================== schema-v4.sql ======================

-- ============================================================
-- Motex Campus · esquema v4 (panel de moderación)
-- Ejecutar DESPUES de schema.sql, v2 y v3. Idempotente.
--
-- Permite al equipo (moderador/admin) GESTIONAR (no solo leer):
--  - el estado de las reservas de mentoría
--  - la revisión y puntuación de los ejercicios entregados
-- El resto de tablas ya eran legibles por el equipo (políticas
-- "*_select" con public.is_campus_staff()).
-- ============================================================

drop policy if exists "mentorship_staff_write" on public.mentorship_bookings;
create policy "mentorship_staff_write" on public.mentorship_bookings
  for update using (public.is_campus_staff()) with check (public.is_campus_staff());

drop policy if exists "exercise_submissions_staff_write" on public.exercise_submissions;
create policy "exercise_submissions_staff_write" on public.exercise_submissions
  for update using (public.is_campus_staff()) with check (public.is_campus_staff());

-- El cruce de pagos con el alumno se hace desde el cliente respetando RLS
-- (el equipo ve todo; un alumno solo lo suyo). No se crean vistas que
-- puedan saltarse las políticas de seguridad.

-- ====================== schema-v5.sql ======================

-- ============================================================
-- Motex Campus · esquema v5 (gestión desde el panel)
-- Ejecutar DESPUES de schema.sql, v2, v3 y v4. Idempotente.
--
--  1. Cambio de rol seguro: SOLO un 'admin' puede hacerlo (un
--     moderador no puede ascender a nadie ni ascenderse). Protege
--     contra quedarse sin ningún administrador.
--  2. El alta/baja de acceso a cursos (enrollments) ya la permite
--     el equipo por la política "enrollments_write_staff".
-- ============================================================

create or replace function public.campus_set_role(target_id uuid, new_role text)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  caller_role text;
  admins_left int;
begin
  select role into caller_role from public.campus_profiles where id = auth.uid();
  if caller_role is distinct from 'admin' then
    raise exception 'Solo un administrador puede cambiar roles';
  end if;
  if new_role not in ('student', 'moderator', 'admin') then
    raise exception 'Rol no válido';
  end if;
  -- No permitir quedarse sin ningún administrador.
  if new_role <> 'admin' then
    select count(*) into admins_left from public.campus_profiles where role = 'admin';
    if admins_left <= 1 and exists (select 1 from public.campus_profiles where id = target_id and role = 'admin') then
      raise exception 'Debe quedar al menos un administrador';
    end if;
  end if;
  update public.campus_profiles set role = new_role where id = target_id;
end;
$$;

grant execute on function public.campus_set_role(uuid, text) to authenticated;

-- ====================== schema-v6.sql ======================

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
