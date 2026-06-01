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
