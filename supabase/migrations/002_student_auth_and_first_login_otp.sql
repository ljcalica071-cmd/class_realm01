-- Keep the existing teacher-owned subject rows while adding fields required
-- by the current teacher-subject and student-enrollment repositories.
alter table public.subjects
  add column if not exists teacher_id text references public.teacher_info(teacher_id),
  add column if not exists subject_name varchar(100),
  add column if not exists section_name varchar(50),
  add column if not exists school_year varchar(9),
  add column if not exists ww_weight numeric(5,2),
  add column if not exists pt_weight numeric(5,2),
  add column if not exists ex_weight numeric(5,2);

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'subjects' and column_name = 'name'
  ) then
    execute 'update public.subjects set subject_name = name where subject_name is null';
  end if;
end
$$;

create table if not exists public.student_enrollments (
  id uuid primary key default gen_random_uuid(),
  student_id text not null references public.student_info(student_id) on delete cascade,
  subject_id uuid not null references public.subjects(id) on delete restrict,
  status varchar(30) not null default 'Enrolled',
  created_at timestamptz not null default now()
);

create unique index if not exists student_enrollments_student_subject_unique
  on public.student_enrollments(student_id, subject_id);

create table if not exists public.first_login_otp_challenges (
  user_id text primary key references public.users(id) on delete cascade,
  code_hash text not null,
  expires_at timestamptz not null,
  last_sent_at timestamptz not null,
  resend_count integer not null default 0,
  failed_attempts integer not null default 0,
  locked_until timestamptz
);

create table if not exists public.first_login_otp_verifications (
  user_id text primary key references public.users(id) on delete cascade,
  verified_at timestamptz not null,
  expires_at timestamptz not null
);

revoke all on table public.first_login_otp_challenges from anon, authenticated;
revoke all on table public.first_login_otp_verifications from anon, authenticated;
grant all on table public.first_login_otp_challenges to service_role;
grant all on table public.first_login_otp_verifications to service_role;

create or replace function public.issue_first_login_otp(
  p_user_id text,
  p_code_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_challenge public.first_login_otp_challenges%rowtype;
  v_now timestamptz := now();
  v_next_resend_count integer;
begin
  select * into v_challenge
  from public.first_login_otp_challenges
  where user_id = p_user_id
  for update;

  if not found then
    insert into public.first_login_otp_challenges(
      user_id, code_hash, expires_at, last_sent_at
    ) values (
      p_user_id, p_code_hash, v_now + interval '60 seconds', v_now
    );
    return jsonb_build_object(
      'issued', true, 'expires_in', 60, 'resend_after', 90, 'resend_count', 0
    );
  end if;

  if v_challenge.locked_until is not null and v_challenge.locked_until > v_now then
    return jsonb_build_object(
      'issued', false,
      'reason', 'locked',
      'retry_after', ceil(extract(epoch from (v_challenge.locked_until - v_now)))::integer
    );
  end if;

  if v_challenge.last_sent_at > v_now - interval '90 seconds' then
    return jsonb_build_object(
      'issued', false,
      'reason', 'cooldown',
      'retry_after', ceil(extract(epoch from (v_challenge.last_sent_at + interval '90 seconds' - v_now)))::integer,
      'expires_in', greatest(0, ceil(extract(epoch from (v_challenge.expires_at - v_now)))::integer),
      'resend_count', v_challenge.resend_count
    );
  end if;

  if v_challenge.resend_count >= 3
     and v_challenge.last_sent_at > v_now - interval '15 minutes' then
    return jsonb_build_object(
      'issued', false, 'reason', 'resend_limit', 'retry_after', 900
    );
  end if;

  v_next_resend_count := case
    when v_challenge.last_sent_at <= v_now - interval '15 minutes' then 0
    else v_challenge.resend_count + 1
  end;

  update public.first_login_otp_challenges
  set code_hash = p_code_hash,
      expires_at = v_now + interval '60 seconds',
      last_sent_at = v_now,
      resend_count = v_next_resend_count,
      failed_attempts = 0,
      locked_until = null
  where user_id = p_user_id;

  return jsonb_build_object(
    'issued', true, 'expires_in', 60, 'resend_after', 90,
    'resend_count', v_next_resend_count
  );
end;
$$;

create or replace function public.verify_first_login_otp(
  p_user_id text,
  p_code_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_challenge public.first_login_otp_challenges%rowtype;
  v_attempts integer;
  v_now timestamptz := now();
begin
  select * into v_challenge
  from public.first_login_otp_challenges
  where user_id = p_user_id
  for update;

  if not found then
    return jsonb_build_object('verified', false, 'reason', 'missing');
  end if;

  if v_challenge.locked_until is not null and v_challenge.locked_until > v_now then
    return jsonb_build_object(
      'verified', false, 'reason', 'locked',
      'retry_after', ceil(extract(epoch from (v_challenge.locked_until - v_now)))::integer
    );
  end if;

  if v_challenge.expires_at <= v_now then
    return jsonb_build_object('verified', false, 'reason', 'expired');
  end if;

  if v_challenge.code_hash <> p_code_hash then
    v_attempts := v_challenge.failed_attempts + 1;
    update public.first_login_otp_challenges
    set failed_attempts = v_attempts,
        locked_until = case
          when v_attempts >= 5 then v_now + interval '15 minutes'
          else null
        end
    where user_id = p_user_id;

    return jsonb_build_object(
      'verified', false,
      'reason', case when v_attempts >= 5 then 'locked' else 'invalid' end,
      'attempts_remaining', greatest(0, 5 - v_attempts),
      'retry_after', case when v_attempts >= 5 then 900 else 0 end
    );
  end if;

  insert into public.first_login_otp_verifications(user_id, verified_at, expires_at)
  values (p_user_id, v_now, v_now + interval '10 minutes')
  on conflict (user_id) do update
    set verified_at = excluded.verified_at, expires_at = excluded.expires_at;
  delete from public.first_login_otp_challenges where user_id = p_user_id;
  return jsonb_build_object('verified', true);
end;
$$;

revoke all on function public.issue_first_login_otp(text, text) from public, anon, authenticated;
revoke all on function public.verify_first_login_otp(text, text) from public, anon, authenticated;
grant execute on function public.issue_first_login_otp(text, text) to service_role;
grant execute on function public.verify_first_login_otp(text, text) to service_role;
