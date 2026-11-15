-- Medical records foundation for Cuidar a Distancia
-- Draft only: do not apply to production until reviewed and tested.
-- Existing care_reports remain unchanged and continue powering the daily-care history.

create table if not exists public.medical_events (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  caregiver_id uuid null references public.caregivers(id) on delete set null,
  created_by uuid null references auth.users(id) on delete set null default auth.uid(),
  event_type text not null check (event_type in ('symptom','incident','diagnosis','other')),
  title text not null check (char_length(btrim(title)) between 1 and 180),
  description text null,
  severity text null check (severity is null or severity in ('low','moderate','high','urgent')),
  occurred_at timestamptz not null default now(),
  source text not null default 'family' check (source in ('family','caregiver','clinician')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.medical_measurements (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  caregiver_id uuid null references public.caregivers(id) on delete set null,
  created_by uuid null references auth.users(id) on delete set null default auth.uid(),
  measurement_type text not null check (measurement_type in ('blood_pressure','temperature','weight','blood_glucose','oxygen_saturation','pulse','other')),
  value numeric null,
  unit text null,
  systolic integer null,
  diastolic integer null,
  pulse integer null,
  notes text null,
  measured_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint medical_measurements_bp_pair check (
    (measurement_type <> 'blood_pressure') or
    (systolic is not null and diastolic is not null)
  )
);

create table if not exists public.medication_records (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  caregiver_id uuid null references public.caregivers(id) on delete set null,
  created_by uuid null references auth.users(id) on delete set null default auth.uid(),
  medication_name text not null check (char_length(btrim(medication_name)) between 1 and 180),
  dose text null,
  status text not null check (status in ('administered','missed','refused','held','unknown')),
  administered_at timestamptz not null default now(),
  notes text null,
  created_at timestamptz not null default now()
);

create table if not exists public.medical_appointments (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  created_by uuid null references auth.users(id) on delete set null default auth.uid(),
  appointment_at timestamptz not null,
  clinician_name text null,
  specialty text null,
  reason text null,
  outcome_notes text null,
  follow_up_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.medical_examinations (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  created_by uuid null references auth.users(id) on delete set null default auth.uid(),
  examination_at date not null,
  examination_type text not null check (char_length(btrim(examination_type)) between 1 and 180),
  provider_name text null,
  result_summary text null,
  storage_path text null,
  created_at timestamptz not null default now()
);

create index if not exists medical_events_household_occurred_idx on public.medical_events (household_id, occurred_at desc);
create index if not exists medical_measurements_household_measured_idx on public.medical_measurements (household_id, measured_at desc);
create index if not exists medication_records_household_administered_idx on public.medication_records (household_id, administered_at desc);
create index if not exists medical_appointments_household_date_idx on public.medical_appointments (household_id, appointment_at desc);
create index if not exists medical_examinations_household_date_idx on public.medical_examinations (household_id, examination_at desc);

alter table public.medical_events enable row level security;
alter table public.medical_measurements enable row level security;
alter table public.medication_records enable row level security;
alter table public.medical_appointments enable row level security;
alter table public.medical_examinations enable row level security;

-- Restrict this feature to households explicitly entitled to the Médico app.
create or replace function public.has_household_app_access(p_household uuid, p_app_key text)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $function$
  select exists (
    select 1
    from public.household_app_access haa
    join public.app_catalog ac on ac.app_key = haa.app_key
    where haa.household_id = p_household
      and haa.app_key = p_app_key
      and haa.is_enabled = true
      and ac.is_active = true
  );
$function$;

revoke all on function public.has_household_app_access(uuid, text) from public, anon;
grant execute on function public.has_household_app_access(uuid, text) to authenticated;

-- Household members may read their own household's medical records.
create policy medical_events_select_member on public.medical_events
  for select to authenticated using (public.is_household_member(household_id) and public.has_app_access(household_id) and public.has_household_app_access(household_id, 'medico'));
create policy medical_measurements_select_member on public.medical_measurements
  for select to authenticated using (public.is_household_member(household_id) and public.has_app_access(household_id) and public.has_household_app_access(household_id, 'medico'));
create policy medication_records_select_member on public.medication_records
  for select to authenticated using (public.is_household_member(household_id) and public.has_app_access(household_id) and public.has_household_app_access(household_id, 'medico'));
create policy medical_appointments_select_member on public.medical_appointments
  for select to authenticated using (public.is_household_member(household_id) and public.has_app_access(household_id) and public.has_household_app_access(household_id, 'medico'));
create policy medical_examinations_select_member on public.medical_examinations
  for select to authenticated using (public.is_household_member(household_id) and public.has_app_access(household_id) and public.has_household_app_access(household_id, 'medico'));

-- Only household owners with medical-app entitlement may add or change medical records.
create policy medical_events_insert_owner on public.medical_events
  for insert to authenticated with check (
    public.is_household_owner(household_id) and public.has_app_access(household_id) and public.has_household_app_access(household_id, 'medico')
    and created_by = (select auth.uid())
  );
create policy medical_events_update_owner on public.medical_events
  for update to authenticated using (
    public.is_household_owner(household_id) and public.has_app_access(household_id) and public.has_household_app_access(household_id, 'medico')
  ) with check (
    public.is_household_owner(household_id) and public.has_app_access(household_id) and public.has_household_app_access(household_id, 'medico')
  );
create policy medical_events_delete_owner on public.medical_events
  for delete to authenticated using (
    public.is_household_owner(household_id) and public.has_app_access(household_id) and public.has_household_app_access(household_id, 'medico')
  );

create policy medical_measurements_insert_owner on public.medical_measurements
  for insert to authenticated with check (
    public.is_household_owner(household_id) and public.has_app_access(household_id) and public.has_household_app_access(household_id, 'medico')
    and created_by = (select auth.uid())
  );
create policy medical_measurements_update_owner on public.medical_measurements
  for update to authenticated using (
    public.is_household_owner(household_id) and public.has_app_access(household_id) and public.has_household_app_access(household_id, 'medico')
  ) with check (
    public.is_household_owner(household_id) and public.has_app_access(household_id) and public.has_household_app_access(household_id, 'medico')
  );
create policy medical_measurements_delete_owner on public.medical_measurements
  for delete to authenticated using (
    public.is_household_owner(household_id) and public.has_app_access(household_id) and public.has_household_app_access(household_id, 'medico')
  );

create policy medication_records_insert_owner on public.medication_records
  for insert to authenticated with check (
    public.is_household_owner(household_id) and public.has_app_access(household_id) and public.has_household_app_access(household_id, 'medico')
    and created_by = (select auth.uid())
  );
create policy medication_records_update_owner on public.medication_records
  for update to authenticated using (
    public.is_household_owner(household_id) and public.has_app_access(household_id) and public.has_household_app_access(household_id, 'medico')
  ) with check (
    public.is_household_owner(household_id) and public.has_app_access(household_id) and public.has_household_app_access(household_id, 'medico')
  );
create policy medication_records_delete_owner on public.medication_records
  for delete to authenticated using (
    public.is_household_owner(household_id) and public.has_app_access(household_id) and public.has_household_app_access(household_id, 'medico')
  );

create policy medical_appointments_insert_owner on public.medical_appointments
  for insert to authenticated with check (
    public.is_household_owner(household_id) and public.has_app_access(household_id) and public.has_household_app_access(household_id, 'medico')
    and created_by = (select auth.uid())
  );
create policy medical_appointments_update_owner on public.medical_appointments
  for update to authenticated using (
    public.is_household_owner(household_id) and public.has_app_access(household_id) and public.has_household_app_access(household_id, 'medico')
  ) with check (
    public.is_household_owner(household_id) and public.has_app_access(household_id) and public.has_household_app_access(household_id, 'medico')
  );
create policy medical_appointments_delete_owner on public.medical_appointments
  for delete to authenticated using (
    public.is_household_owner(household_id) and public.has_app_access(household_id) and public.has_household_app_access(household_id, 'medico')
  );

create policy medical_examinations_insert_owner on public.medical_examinations
  for insert to authenticated with check (
    public.is_household_owner(household_id) and public.has_app_access(household_id) and public.has_household_app_access(household_id, 'medico')
    and created_by = (select auth.uid())
  );
create policy medical_examinations_update_owner on public.medical_examinations
  for update to authenticated using (
    public.is_household_owner(household_id) and public.has_app_access(household_id) and public.has_household_app_access(household_id, 'medico')
  ) with check (
    public.is_household_owner(household_id) and public.has_app_access(household_id) and public.has_household_app_access(household_id, 'medico')
  );
create policy medical_examinations_delete_owner on public.medical_examinations
  for delete to authenticated using (
    public.is_household_owner(household_id) and public.has_app_access(household_id) and public.has_household_app_access(household_id, 'medico')
  );

grant select, insert, update, delete on public.medical_events to authenticated;
grant select, insert, update, delete on public.medical_measurements to authenticated;
grant select, insert, update, delete on public.medication_records to authenticated;
grant select, insert, update, delete on public.medical_appointments to authenticated;
grant select, insert, update, delete on public.medical_examinations to authenticated;
