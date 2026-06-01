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
