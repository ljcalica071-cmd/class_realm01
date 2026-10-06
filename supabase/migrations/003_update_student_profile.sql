create or replace function public.update_student_profile(
  p_student_id text,
  p_lrn text,
  p_email text,
  p_first_name text,
  p_middle_name text,
  p_last_name text,
  p_gender text,
  p_birthday date
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_lrn !~ '^[0-9]{12}$' then
    raise exception 'LRN must be exactly 12 digits.';
  end if;
  if p_gender not in ('Male', 'Female') then
    raise exception 'Gender must be Male or Female.';
  end if;
  if btrim(coalesce(p_first_name, '')) = ''
     or btrim(coalesce(p_last_name, '')) = '' then
    raise exception 'Student first and last name are required.';
  end if;

  update public.users
  set email = p_email
  where id = p_student_id;

  update public.student_info
  set lrn = p_lrn,
      email = p_email
  where student_id = p_student_id;

  if not found then
    raise exception 'Student account was not found.';
  end if;

  update public.student_profile
  set firstname = btrim(p_first_name),
      middlename = nullif(btrim(coalesce(p_middle_name, '')), ''),
      lastname = btrim(p_last_name),
      gender = p_gender,
      birthday = p_birthday
  where student_id = p_student_id;

  if not found then
    raise exception 'Student profile was not found.';
  end if;
end;
$$;

revoke all on function public.update_student_profile(
  text, text, text, text, text, text, text, date
) from public, anon, authenticated;
grant execute on function public.update_student_profile(
  text, text, text, text, text, text, text, date
) to service_role;
