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

-- Permite iniciar sesion con nombre de usuario: resuelve el email
-- asociado a un username para que el cliente pueda autenticarse.
create or replace function public.campus_email_for_username(p_username text)
returns text
language sql stable security definer set search_path = public, auth
as $$
  select u.email
  from auth.users u
  join public.campus_profiles p on p.id = u.id
  where p.username = p_username
  limit 1;
$$;

grant execute on function public.campus_email_for_username(text) to anon, authenticated;

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
