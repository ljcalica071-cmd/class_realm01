-- Enable required extensions
-- Note: uuid-ossp is no longer needed since we use gen_random_uuid()

-- ==========================================
-- CORE USERS TABLE (ID maps to Firebase Auth UID)
-- ==========================================
create table if not exists public.users (
  id text NOT NULL PRIMARY KEY,
  email varchar(100) NOT NULL UNIQUE,
  role varchar(10) NOT NULL CHECK (role in ('teacher', 'admin', 'student', 'parent')),
  created_at timestamptz default now()
);

-- ==========================================
-- TEACHER TABLES 
-- ==========================================
create table if not exists public.teacher_info (
  teacher_id text primary key references public.users(id) on delete cascade,
  contact varchar(11),
  status varchar(30) default 'pending',
  is_setup_complete boolean default false,
  created_at timestamptz default now()
);

create table if not exists public.teacher_profile (
  teacher_id text primary key references public.teacher_info(teacher_id) on delete cascade,
  firstname varchar(30) not null,
  middlename varchar(30),
  lastname varchar(30) not null,
  birthday date,
  gender varchar(6) check (gender in ('Male', 'Female'))
  -- Note: age is dynamically calculated in frontend
);

-- ==========================================
-- STUDENT TABLES 
-- ==========================================
create table if not exists public.student_info (
  student_id text primary key references public.users(id) on delete cascade,
  lrn varchar(12) not null unique,
  email varchar(100),
  status varchar(20) default 'PendingFirstLogin',
  created_at timestamptz default now()
);

create table if not exists public.student_profile (
  student_id text primary key references public.student_info(student_id) on delete cascade,
  firstname varchar(30) not null,
  middlename varchar(30),
  lastname varchar(30) not null,
  birthday date not null,
  gender varchar(6) check (gender in ('Male', 'Female'))
  -- Note: age is dynamically calculated in frontend
);

-- ==========================================
-- PARENT TABLES (Unified)
-- ==========================================
create table if not exists public.parent_profiles (
  id text primary key references public.users(id) on delete cascade,
  first_name varchar(30) not null,
  middle_name varchar(30),
  last_name varchar(30) not null,
  contact_number varchar(11) not null,
  created_at timestamptz default now()
);

create table if not exists public.parent_student_link (
  parent_id text not null references public.parent_profiles(id) on delete cascade,
  student_id text not null references public.student_info(student_id) on delete cascade,
  relationship varchar(20) not null,
  primary key (parent_id, student_id)
);

-- ==========================================
-- SUBJECTS & GRADING TEMPLATES (Normalized)
-- ==========================================
create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(),
  name varchar(100) not null,
  grade_level integer not null,
  category varchar(30) not null,
  cluster varchar(60) not null
);

create table if not exists public.subject_grading_templates (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid references public.subjects(id) on delete cascade,
  term_assigned integer default 0,
  no_terms_taught integer default 3,
  default_ww_weight numeric(5,2) default 20.00,
  default_pt_weight numeric(5,2) default 50.00,
  default_ex_weight numeric(5,2) default 30.00
);

-- ==========================================
-- ACADEMIC CLASSES & SCHEDULES
-- ==========================================
create table if not exists public.sections (
  id uuid primary key default gen_random_uuid(),
  name varchar(50) not null,
  grade_level integer not null check (grade_level in (11, 12)),
  curriculum_type varchar(30) check (curriculum_type in ('Strengthened SHS (New)', 'Old Curriculum')),
  adviser_id text references public.teacher_info(teacher_id) on delete set null,
  school_year varchar(9) not null
);

create table if not exists public.schedules (
  id uuid primary key default gen_random_uuid(),
  teacher_id text not null references public.teacher_info(teacher_id) on delete cascade,
  section_id uuid not null references public.sections(id) on delete cascade,
  subject_id uuid not null references public.subjects(id) on delete cascade,
  day_of_week integer check (day_of_week >= 1 and day_of_week <= 7),
  start_time time not null,
  end_time time not null,
  room varchar(30)
);

create table if not exists public.gradebook_settings (
  id uuid primary key default gen_random_uuid(),
  schedule_id uuid not null references public.schedules(id) on delete cascade,
  ww_weight numeric(5,2) not null,
  pt_weight numeric(5,2) not null,
  ex_weight numeric(5,2) not null
);
