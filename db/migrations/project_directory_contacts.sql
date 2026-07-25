-- ============================================================
-- Project Directory — external contacts per project (APPLIED to live DB)
-- ============================================================
-- Client-side (Client, Client PM, Building/Facilities Manager) and
-- Subcontractors/Consultants (Electrical, Joinery, M&P, Structural Engineer…).
-- Feeds module people-fields the way project info feeds every tab.
-- Mirrors the project_key_dates conventions (org-scoped RLS + set_org/touch triggers).

create table if not exists public.project_contacts (
    id           uuid primary key default gen_random_uuid(),
    org_id       uuid not null references public.organisations(id),
    project_id   uuid not null references public.projects(id) on delete cascade,
    contact_group text not null default 'subcontractor' check (contact_group in ('client', 'subcontractor')),
    role         text not null default '',   -- 'Client PM', 'Electrical', 'Structural Engineer', or custom
    company      text,
    contact_name text,
    address      text,
    tel          text,
    email        text,
    notes        text,
    sort_order   integer not null default 0,
    created_by   uuid references public.app_users(id),
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now()
);
create index if not exists project_contacts_project_idx on public.project_contacts (project_id, contact_group, sort_order);
alter table public.project_contacts enable row level security;

drop policy if exists "contacts scoped to org" on public.project_contacts;
create policy "contacts scoped to org" on public.project_contacts for select using (org_id = public.current_org_id());
drop policy if exists "members create contacts" on public.project_contacts;
create policy "members create contacts" on public.project_contacts for insert with check (org_id = public.current_org_id() or org_id is null);
drop policy if exists "members edit contacts" on public.project_contacts;
create policy "members edit contacts" on public.project_contacts for update using (org_id = public.current_org_id()) with check (org_id = public.current_org_id());
drop policy if exists "members delete contacts" on public.project_contacts;
create policy "members delete contacts" on public.project_contacts for delete using (org_id = public.current_org_id());

drop trigger if exists trg_project_contacts_set_org on public.project_contacts;
create trigger trg_project_contacts_set_org before insert on public.project_contacts for each row execute function public.set_org_id_on_insert();
drop trigger if exists trg_project_contacts_touch on public.project_contacts;
create trigger trg_project_contacts_touch before update on public.project_contacts for each row execute function public.touch_updated_at();
