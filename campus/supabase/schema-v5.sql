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
