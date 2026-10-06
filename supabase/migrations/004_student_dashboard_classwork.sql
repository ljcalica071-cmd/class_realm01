create table if not exists public.classwork_items (
  id uuid primary key default gen_random_uuid(),
  teacher_id text not null references public.teacher_info(teacher_id) on delete cascade,
  subject_id uuid not null references public.subjects(id) on delete cascade,
  classwork_type text not null check (
    classwork_type in ('activity', 'assignment', 'performance_task')
  ),
  title text not null,
  description text not null default '',
  instructions text not null default '',
  assigned_at timestamptz not null default now(),
  deadline timestamptz,
  max_score numeric(7, 2) not null default 0 check (max_score >= 0),
  submission_type text not null default 'file_and_text' check (
    submission_type in ('file', 'text', 'file_and_text', 'none')
  ),
  attachment_name text,
  attachment_url text,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists classwork_items_subject_published_deadline_idx
  on public.classwork_items(subject_id, is_published, deadline);

create table if not exists public.student_classwork_submissions (
  id uuid primary key default gen_random_uuid(),
  classwork_id uuid not null references public.classwork_items(id) on delete cascade,
  student_id text not null references public.student_info(student_id) on delete cascade,
  status text not null default 'pending' check (
    status in ('pending', 'submitted', 'graded', 'returned')
  ),
  submitted_at timestamptz,
  text_submission text,
  attachment_name text,
  attachment_url text,
  score numeric(7, 2) check (score is null or score >= 0),
  feedback text,
  graded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint student_classwork_submissions_item_student_unique
    unique (classwork_id, student_id)
);

create index if not exists student_classwork_submissions_student_status_idx
  on public.student_classwork_submissions(student_id, status);

alter table public.classwork_items enable row level security;
alter table public.student_classwork_submissions enable row level security;

revoke all on table public.classwork_items from anon, authenticated;
revoke all on table public.student_classwork_submissions from anon, authenticated;
grant all on table public.classwork_items to service_role;
grant all on table public.student_classwork_submissions to service_role;
