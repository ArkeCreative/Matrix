-- ============================================================
-- Seed — Project Directory contact history (dev org, fictional data)
-- APPLIED to the live dev DB on 2026-07-25.
-- ============================================================
-- Purpose: give the directory a realistic body of history so the company
-- auto-fill has something to work against. The shape that matters:
--   * a small pool of subcontractor firms RECURS across many projects
--   * the individual contact at that firm VARIES between projects
-- (e.g. Lineform Interiors appears on 14 projects across 3 different contacts).
-- Result: 143 subcontractor rows + 52 client-side rows over 19 projects.
--
-- org_id is set explicitly from the project (the set_org_id_on_insert trigger
-- relies on auth.uid(), which is absent when seeding out-of-band).

-- 1. Subcontractors & consultants — recurring firms, rotating people ---------
with proj as (
  select id, org_id, row_number() over (order by created_at) as n
  from public.projects
  where status in ('handed-over','on-site','contract','won')
),
firm as (
  select * from (values
    (1,'Electrical','Voltec Electrical Ltd','Unit 4 Ashford Trade Park, Slough SL1 4LN','01753 900900',
       array['Dev Patel|d.patel@voltec.co.uk','Marcus Reid|m.reid@voltec.co.uk','Nadia Okafor|n.okafor@voltec.co.uk']),
    (2,'Mechanical & Plumbing','AirFlow M&E Services','12 Hanworth Road, Feltham TW13 5AF','020 8890 4410',
       array['Rachel Owusu|r.owusu@airflowme.co.uk','Steve Bannerman|s.bannerman@airflowme.co.uk']),
    (3,'Partitions, Doors & Ceilings','Lineform Interiors','Bay 6 Crayford Industrial, Dartford DA1 4HF','01322 553100',
       array['Gary Whitfield|g.whitfield@lineform.co.uk','Amara Nwosu|a.nwosu@lineform.co.uk','Paul Deakin|p.deakin@lineform.co.uk']),
    (4,'Joinery','Havelock Joinery Co.','Chapel Works, Romford RM7 0BT','01708 442200',
       array['Tomasz Kaminski|t.kaminski@havelockjoinery.co.uk','Ellie Grant|e.grant@havelockjoinery.co.uk']),
    (5,'Flooring','Southbank Flooring','Arch 14, Bermondsey SE16 4DG','020 7231 8800',
       array['Liam Ferris|liam@southbankflooring.co.uk','Priya Shah|priya@southbankflooring.co.uk']),
    (6,'Data Cabling','Cablenet Solutions','Kestrel House, Watford WD18 8PH','01923 771400',
       array['Owen Blythe|o.blythe@cablenet.co.uk','Ruth Adeyemi|r.adeyemi@cablenet.co.uk']),
    (7,'Structural Engineer','Beam Consulting Engineers','3rd Floor, 40 Bowling Green Lane, EC1R 0NE','020 7253 6600',
       array['Hannah Vance|h.vance@beamconsulting.com','Ibrahim Sallah|i.sallah@beamconsulting.com']),
    (8,'Decorations','Pemberton Decorators','Yard 2, Enfield EN3 7XA','020 8804 5150',
       array['Kev Doyle|kev@pembertondec.co.uk','Sonia Marsh|sonia@pembertondec.co.uk']),
    (9,'Audio Visual','Northlight AV','Studio 9, Clerkenwell EC1V 4JD','020 7490 3300',
       array['Ben Hartley|b.hartley@northlightav.com','Zoe Chen|z.chen@northlightav.com']),
    (10,'Health and Safety','Sentinel Safety Consultants','Regent House, Croydon CR0 2AP','020 8680 7720',
       array['Alan Pryce|a.pryce@sentinelsafety.co.uk','Meera Joshi|m.joshi@sentinelsafety.co.uk'])
  ) as t(ord, role, company, address, tel, people)
),
picked as (
  select p.id as project_id, p.org_id, f.ord, f.role, f.company, f.address, f.tel,
         f.people[1 + ((p.n + f.ord) % cardinality(f.people))] as person
  from proj p cross join firm f
  where (p.n + f.ord) % 4 <> 0   -- not every firm on every project
)
insert into public.project_contacts (org_id, project_id, contact_group, role, company, address, tel, contact_name, email, sort_order)
select org_id, project_id, 'subcontractor', role, company, address, tel,
       split_part(person,'|',1), split_part(person,'|',2), ord
from picked;

-- 2. Client side — client per project; PM/building-manager firms also recur --
with proj as (
  select id, org_id, name, row_number() over (order by created_at) as n
  from public.projects
  where status in ('handed-over','on-site','contract','won')
),
pmfirm as (
  select * from (values
    (0,'Gardiner & Theobald','8 Bishopsgate, London EC2N 4BQ','020 7209 3000', array['Tom Hedges|t.hedges@gardiner.com','Claire Bassett|c.bassett@gardiner.com']),
    (1,'Gleeds Management','95 New Cavendish St, London W1W 6XF','020 7631 2727', array['Raj Sandhu|raj.sandhu@gleeds.co.uk','Fiona Clark|fiona.clark@gleeds.co.uk']),
    (2,'Quadrant Project Services','1 Fetter Lane, London EC4A 1BR','020 7936 4000', array['Nick Frayne|n.frayne@quadrantps.co.uk','Aisha Rahman|a.rahman@quadrantps.co.uk'])
  ) as t(slot, company, address, tel, people)
),
bm as (
  select * from (values
    (0,'CBRE Building Management','Henrietta House, London W1G 0NB','020 7182 2000', array['Dawn Ellery|dawn.ellery@cbre.com']),
    (1,'Savills Property Management','33 Margaret St, London W1G 0JD','020 7499 8644', array['Peter Nash|p.nash@savills.com'])
  ) as t(slot, company, address, tel, people)
)
insert into public.project_contacts (org_id, project_id, contact_group, role, company, address, tel, contact_name, email, sort_order)
select org_id, id, 'client', 'Client', name, null, null, null, null, 1 from proj
union all
select p.org_id, p.id, 'client', 'Client PM', f.company, f.address, f.tel,
       split_part(f.people[1 + (p.n % cardinality(f.people))],'|',1),
       split_part(f.people[1 + (p.n % cardinality(f.people))],'|',2), 2
from proj p join pmfirm f on f.slot = p.n % 3
union all
select p.org_id, p.id, 'client', 'Building Manager', b.company, b.address, b.tel,
       split_part(b.people[1],'|',1), split_part(b.people[1],'|',2), 3
from proj p join bm b on b.slot = p.n % 2
where p.n % 3 <> 0;
