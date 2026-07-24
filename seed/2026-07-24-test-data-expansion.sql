-- arke [matrix] — test-data expansion (dev org `dawlish`)
-- Applied 2026-07-24 to Supabase project `matrix` (tpxabhqsjngalilbznhz), org
-- c6e9cc3c-54d7-446a-895b-cf75ed0e93cd. All data is fictional (Stage C dev org).
--
-- WHAT THIS ADDS
--   * 17 new projects spanning the whole pipeline (lead → handed-over + lost),
--     created May 2024 → Jul 2026, mixing building-named schemes
--     (Kingfisher House, Fitzrovia Yard, Southbank Print House…) with
--     client-named ones (Meridian Capital, Voltaic Labs, Ashworth Legal…) and
--     retaining the "…HQ" nomenclature in a few (Halcyon Group HQ, Vantage
--     Aerospace HQ). Programme lengths vary from 14-week fast-tracks to
--     16-month HQ relocations.
--   * ~125 project key dates, weighted toward the pre-con period (Enquiry
--     Received, Site Survey, Tender Issued/Return, Mid/Post-Tender Interview,
--     Contract Award) plus construction milestones, completion state matched to
--     each project's stage and today's date.
--   * 16 historic closed meetings (design / technical / pre-con / pm / furniture)
--     spread Sep 2025 → Jul 2026, with attendee lists.
--   * 54 meeting entries (dept notes per project per meeting), incl. carried-
--     forward reviewed_fields.
--   * 24 actions with varied instigators, owners, priorities, due dates
--     (overdue / imminent / future) and completion notes; plus collaborators
--     and action queries.
--   * 9 flags (meeting_handoffs) — open (carried-forward) and acknowledged,
--     two converted into actions.
--
-- NOTES
--   * Foreign keys are resolved by natural key (app_users.initials,
--     projects.project_number, meetings.started_at) so no UUIDs are hard-coded.
--   * `SET LOCAL session_replication_role = replica` suppresses the notify/
--     touch/set_org triggers for a clean historic backfill (org_id is set
--     explicitly). It is transaction-scoped and reverts on COMMIT/ROLLBACK.
--   * This is a one-shot seed written against the Stage C baseline; it is NOT
--     idempotent (project_number / description are not unique-constrained).
--     Re-running against a DB that already contains this data will duplicate.

-- =====================================================================
-- Batch A — projects
-- =====================================================================
begin;
set local session_replication_role = replica;

insert into projects
(org_id, project_number, name, address, status, secured, site_manager, whole_building,
 site_area_m2, floor_level,
 owner_user_id, project_manager_user_id, pre_con_lead_user_id, designer_user_id, technical_designer_user_id, furniture_consultant_user_id,
 site_start_date, projected_completion_date, contracted_completion_date,
 secured_at, secured_by, secured_note,
 created_by, last_updated_by, created_at, updated_at)
select 'c6e9cc3c-54d7-446a-895b-cf75ed0e93cd'::uuid, v.pn, v.name, v.addr, v.status, v.secured, v.sm, v.whole,
 v.area, v.floor,
 uo.id, upm.id, upc.id, ude.id, ute.id, ufu.id,
 v.ss, v.pc, v.cc,
 v.sa, usec.id, v.snote,
 uo.id, uo.id, v.created, v.updated
from (values
 ('2301','Kingfisher House',       '9 Kingfisher Court, London EC2A 4PH','handed-over',true ,'Dave Mullins',       false,1350,'Ground – 4th','CG','CG','JO','PA','MAB','GB','CG', date '2024-09-16', null,            date '2025-02-14', timestamptz '2024-07-10 09:00+00','Framework award — second phase.', timestamptz '2024-05-02 08:30+00', timestamptz '2025-02-20 16:00+00'),
 ('2302','Meridian Capital',       'Meridian Capital, 88 Leadenhall Street, London EC3A 3BP','handed-over',true ,'Paul Hendry',        false, 640,'11th','EW','EW','ZR','FD','TFS','TP','EW', date '2024-10-07', null,            date '2025-01-31', timestamptz '2024-08-01 10:00+00','Direct negotiation, repeat client.', timestamptz '2024-06-18 11:15+00', timestamptz '2025-02-05 12:00+00'),
 ('2303','Northwind Partners',     'Northwind Partners, 20 Farringdon Road, London EC1M 3HE','handed-over',true ,'Steve Antonopoulos', false, 920,'6th & 7th','KH','KH','JO','PA','MAB','GB','KH', date '2024-12-02', null,            date '2025-04-04', timestamptz '2024-10-01 09:30+00',null, timestamptz '2024-08-11 14:00+00', timestamptz '2025-04-10 10:30+00'),
 ('2304','Barbican Print Works',   'Barbican Print Works, 3 Golden Lane, London EC1Y 0TN','lost',       false,null,                 false,null,null,'PA',null,'JO',null,null,null,null,      null,              null,            null,              null,                          'Lost at final interview — client went with incumbent.', timestamptz '2024-09-20 13:00+00', timestamptz '2024-12-11 09:00+00'),
 ('2305','Halcyon Group HQ',       'Halcyon Group, 1 Bishops Square, London E1 6AD','on-site',    true ,'Dave Mullins',       true ,2600,null,'CG','CG','JO','PA','MAB','GB','CG', date '2026-03-16', date '2026-10-30', date '2026-10-30', timestamptz '2025-01-20 15:00+00','Large HQ relocation — long landlord/design lead-in.', timestamptz '2024-11-05 10:00+00', timestamptz '2026-07-18 17:20+00'),
 ('2306','Voltaic Labs',           'Voltaic Labs, 14 Hoxton Square, London N1 6NT','on-site',    true ,'Dave Mullins',       false, 780,'Basement & Ground','AA','AA','ZR','FD','MAB','TP','AA', date '2026-04-13', date '2026-08-21', date '2026-08-21', timestamptz '2025-06-02 09:00+00','Lab/office hybrid — specialist services.', timestamptz '2025-01-14 09:45+00', timestamptz '2026-07-15 08:40+00'),
 ('2307','Sable & Finch',          'Sable & Finch, 60 Chancery Lane, London WC2A 1AN','contract',   true ,null,                 false,1100,'3rd – 5th','RR','RR','JO','PA','TFS','GB','RR', date '2026-09-14', date '2027-01-22', date '2027-01-22', timestamptz '2026-05-15 11:00+00','Legal fit-out, high spec joinery.', timestamptz '2025-03-03 10:20+00', timestamptz '2026-07-10 13:10+00'),
 ('2308','Fitzrovia Yard',         'Fitzrovia Yard, 22 Cleveland Street, London W1T 4JD','on-site',    true ,'Paul Hendry',        false,1450,'Ground – 2nd','EW','EW','ZR','FD','MAB','GB','EW', date '2026-05-18', date '2026-09-25', date '2026-09-25', timestamptz '2025-11-03 09:00+00',null, timestamptz '2025-04-22 15:30+00', timestamptz '2026-07-21 11:00+00'),
 ('2309','Brightside Media',       'Brightside Media, 5 Kingsland Road, London E2 8AA','handed-over',true ,'Steve Antonopoulos', false, 560,'2nd','KH','KH','ZR','FD','MAB','TP','KH', date '2025-05-19', null,            date '2025-08-29', timestamptz '2025-03-20 10:00+00','Fast-track — 14 week programme.', timestamptz '2025-02-10 09:00+00', timestamptz '2025-09-04 16:45+00'),
 ('2310','Ashworth Legal',         'Ashworth Legal, 40 Grays Inn Road, London WC1X 8LR','won',        true ,null,                 false, 870,'7th','CG','CG','JO','PA','MAB','GB','CG', date '2026-08-10', date '2026-11-20', null,              timestamptz '2026-06-30 14:00+00','Awarded — contract in legals.', timestamptz '2025-09-08 11:30+00', timestamptz '2026-07-16 10:00+00'),
 ('2311','Paddington Exchange',    'Paddington Exchange, 4 Kingdom Street, London W2 6BD','tender',     false,null,                 false,null,null,'PA',null,'ZR',null,null,null,null,      date '2026-10-05', date '2027-02-12', null,              null,                          null, timestamptz '2025-11-19 09:15+00', timestamptz '2026-07-12 09:00+00'),
 ('2312','Kestrel & Co.',          'Kestrel & Co., 12 Marylebone Lane, London W1U 2NF','pitching',   false,null,                 false,null,null,'RR',null,'JO',null,null,null,null,      null,              null,            null,              null,                          null, timestamptz '2026-01-27 10:40+00', timestamptz '2026-07-09 15:20+00'),
 ('2414','Southbank Print House',  'Southbank Print House, 30 Stamford Street, London SE1 9LQ','contract',   true ,null,                 false,1320,'Ground – 2nd','AA','AA','JO','FD','MAB','GB','AA', date '2026-07-27', date '2026-11-13', date '2026-11-13', timestamptz '2026-06-01 09:00+00',null, timestamptz '2026-02-12 09:30+00', timestamptz '2026-07-22 12:00+00'),
 ('2415','Lumen Health',           'Lumen Health, 100 New Cavendish Street, London W1W 6XX','won',        true ,null,                 false, 990,'1st & 2nd','EW','EW','ZR','PA','TFS','TP','EW', date '2026-09-07', date '2026-12-18', null,              timestamptz '2026-07-01 16:00+00','Healthcare consultancy — CQC-aware layout.', timestamptz '2026-03-20 11:00+00', timestamptz '2026-07-19 09:30+00'),
 ('2416','Farringdon Vaults',      'Farringdon Vaults, 1 Turnmill Street, London EC1M 5QA','tender',     false,null,                 false,null,null,'KH',null,'JO',null,null,null,null,      date '2026-12-07', date '2027-04-16', null,              null,                          null, timestamptz '2026-05-06 10:15+00', timestamptz '2026-07-20 14:00+00'),
 ('2417','Orbit Digital',          'Orbit Digital, 7 Curtain Road, London EC2A 3LT','lead',       false,null,                 false,null,null,'PA',null,null,null,null,null,null,     null,              null,            null,              null,                          null, timestamptz '2026-06-30 09:00+00', timestamptz '2026-07-02 09:00+00'),
 ('2418','Vantage Aerospace HQ',   'Vantage Aerospace, 2 Kingsway, London WC2B 6NH','pitching',   false,null,                 true ,null,null,'CG',null,'JO',null,null,null,null,      null,              null,            null,              null,                          null, timestamptz '2026-07-08 13:30+00', timestamptz '2026-07-23 10:10+00')
) as v(pn,name,addr,status,secured,sm,whole,area,floor,owner,pm,precon,design,tech,furn,secby,ss,pc,cc,sa,snote,created,updated)
left join app_users uo  on uo.initials  = v.owner
left join app_users upm on upm.initials = v.pm
left join app_users upc on upc.initials = v.precon
left join app_users ude on ude.initials = v.design
left join app_users ute on ute.initials = v.tech
left join app_users ufu on ufu.initials = v.furn
left join app_users usec on usec.initials = v.secby;

commit;

-- =====================================================================
-- Batch B — project key dates (pre-con weighted + construction milestones)
-- =====================================================================
begin;
set local session_replication_role = replica;

insert into project_key_dates
(org_id, project_id, event_name, target_date, completed, completed_at, completed_by, completion_note, created_in_meeting_type, created_by, updated_by, created_at, updated_at)
select 'c6e9cc3c-54d7-446a-895b-cf75ed0e93cd'::uuid, p.id, v.event, v.target, v.done,
  case when v.done then (v.target::timestamptz + interval '17 hours') else null end,
  case when v.done then ub.id else null end,
  v.note, v.mt, ub.id, ub.id,
  (v.target::timestamptz - interval '18 days'),
  case when v.done then (v.target::timestamptz + interval '17 hours') else (v.target::timestamptz - interval '18 days') end
from (values
 ('2301','Enquiry Received',date '2024-05-06',true,'pre-con','JO',null),
 ('2301','Site Survey',date '2024-05-28',true,'pre-con','ZR',null),
 ('2301','Tender Return',date '2024-06-20',true,'pre-con','JO',null),
 ('2301','Post-Tender Interview',date '2024-07-02',true,'pre-con','JO',null),
 ('2301','Contract Award',date '2024-07-10',true,'pre-con','CG','Signed JCT D&B.'),
 ('2301','Design Freeze',date '2024-08-14',true,'design','PA',null),
 ('2301','Building Control Submission',date '2024-08-30',true,'technical','MAB',null),
 ('2301','Strip Out Complete',date '2024-10-04',true,null,'CG',null),
 ('2301','First Fix Complete',date '2024-11-15',true,null,'CG',null),
 ('2301','FF&E Install',date '2025-01-24',true,'furniture','GB',null),
 ('2301','Snagging Complete',date '2025-02-07',true,null,'CG',null),
 ('2301','Handover',date '2025-02-14',true,null,'CG','Handed over — zero defects at PC.'),
 ('2302','Enquiry Received',date '2024-06-20',true,'pre-con','ZR',null),
 ('2302','Site Survey',date '2024-07-05',true,'pre-con','ZR',null),
 ('2302','Tender Return',date '2024-07-24',true,'pre-con','ZR',null),
 ('2302','Contract Award',date '2024-08-01',true,'pre-con','EW',null),
 ('2302','Design Freeze',date '2024-09-06',true,'design','FD',null),
 ('2302','First Fix Complete',date '2024-11-22',true,null,'EW',null),
 ('2302','FF&E Install',date '2025-01-10',true,'furniture','TP',null),
 ('2302','Handover',date '2025-01-31',true,null,'EW','Client sign-off received.'),
 ('2303','Enquiry Received',date '2024-08-14',true,'pre-con','JO',null),
 ('2303','Site Survey',date '2024-09-02',true,'pre-con','JO',null),
 ('2303','Tender Return',date '2024-09-24',true,'pre-con','JO',null),
 ('2303','Contract Award',date '2024-10-01',true,'pre-con','KH',null),
 ('2303','Design Freeze',date '2024-11-08',true,'design','PA',null),
 ('2303','Building Control Submission',date '2024-11-25',true,'technical','MAB',null),
 ('2303','First Fix Complete',date '2025-01-31',true,null,'KH',null),
 ('2303','FF&E Install',date '2025-03-21',true,'furniture','GB',null),
 ('2303','Snagging Complete',date '2025-03-28',true,null,'KH',null),
 ('2303','Handover',date '2025-04-04',true,null,'KH',null),
 ('2304','Enquiry Received',date '2024-09-24',true,'pre-con','JO',null),
 ('2304','Site Survey',date '2024-10-10',true,'pre-con','JO',null),
 ('2304','Tender Return',date '2024-11-05',true,'pre-con','JO',null),
 ('2304','Post-Tender Interview',date '2024-12-10',true,'pre-con','PA','Unsuccessful — client retained incumbent. Feedback logged.'),
 ('2305','Enquiry Received',date '2024-11-08',true,'pre-con','JO',null),
 ('2305','Site Survey',date '2024-12-05',true,'pre-con','JO',null),
 ('2305','Tender Return',date '2025-01-10',true,'pre-con','JO',null),
 ('2305','Contract Award',date '2025-01-20',true,'pre-con','CG','Two-stage — PCSA then main contract.'),
 ('2305','Design Freeze',date '2026-01-30',true,'design','PA',null),
 ('2305','Building Control Submission',date '2026-02-20',true,'technical','MAB',null),
 ('2305','Strip Out Complete',date '2026-04-10',true,null,'CG',null),
 ('2305','First Fix Complete',date '2026-06-19',true,null,'CG',null),
 ('2305','M&E Install',date '2026-07-31',false,null,'MAB',null),
 ('2305','Second Fix Complete',date '2026-09-04',false,null,'CG',null),
 ('2305','FF&E Install',date '2026-10-02',false,'furniture','GB',null),
 ('2305','Snagging Start',date '2026-10-16',false,null,'CG',null),
 ('2305','Handover',date '2026-10-30',false,null,'CG',null),
 ('2306','Enquiry Received',date '2025-01-16',true,'pre-con','ZR',null),
 ('2306','Site Survey',date '2025-02-04',true,'pre-con','ZR',null),
 ('2306','Tender Return',date '2025-03-14',true,'pre-con','ZR',null),
 ('2306','Contract Award',date '2025-06-02',true,'pre-con','AA',null),
 ('2306','Design Freeze',date '2026-02-27',true,'design','FD',null),
 ('2306','Strip Out Complete',date '2026-04-24',true,null,'AA',null),
 ('2306','First Fix Complete',date '2026-06-05',true,null,'AA',null),
 ('2306','M&E Install',date '2026-07-17',true,null,'MAB',null),
 ('2306','FF&E Install',date '2026-08-07',false,'furniture','TP',null),
 ('2306','Snagging Start',date '2026-08-14',false,null,'AA',null),
 ('2306','Handover',date '2026-08-21',false,null,'AA',null),
 ('2307','Enquiry Received',date '2025-03-05',true,'pre-con','JO',null),
 ('2307','Site Survey',date '2025-04-01',true,'pre-con','JO',null),
 ('2307','Tender Return',date '2025-05-06',true,'pre-con','JO',null),
 ('2307','Contract Award',date '2026-05-15',true,'pre-con','RR','Contract executed.'),
 ('2307','Design Freeze',date '2026-08-14',false,'design','PA',null),
 ('2307','Building Control Submission',date '2026-08-28',false,'technical','TFS',null),
 ('2307','First Fix Complete',date '2026-11-06',false,null,'RR',null),
 ('2307','FF&E Install',date '2027-01-08',false,'furniture','GB',null),
 ('2307','Handover',date '2027-01-22',false,null,'RR',null),
 ('2308','Enquiry Received',date '2025-04-24',true,'pre-con','ZR',null),
 ('2308','Tender Return',date '2025-06-30',true,'pre-con','ZR',null),
 ('2308','Contract Award',date '2025-11-03',true,'pre-con','EW',null),
 ('2308','Design Freeze',date '2026-03-27',true,'design','FD',null),
 ('2308','Strip Out Complete',date '2026-05-29',true,null,'EW',null),
 ('2308','First Fix Complete',date '2026-07-10',true,null,'EW',null),
 ('2308','M&E Install',date '2026-08-14',false,null,'MAB',null),
 ('2308','FF&E Install',date '2026-09-11',false,'furniture','GB',null),
 ('2308','Snagging Start',date '2026-09-18',false,null,'EW',null),
 ('2308','Handover',date '2026-09-25',false,null,'EW',null),
 ('2309','Enquiry Received',date '2025-02-12',true,'pre-con','ZR',null),
 ('2309','Site Survey',date '2025-02-26',true,'pre-con','ZR',null),
 ('2309','Tender Return',date '2025-03-12',true,'pre-con','ZR',null),
 ('2309','Contract Award',date '2025-03-20',true,'pre-con','KH',null),
 ('2309','Design Freeze',date '2025-04-25',true,'design','FD',null),
 ('2309','First Fix Complete',date '2025-06-27',true,null,'KH',null),
 ('2309','FF&E Install',date '2025-08-15',true,'furniture','TP',null),
 ('2309','Handover',date '2025-08-29',true,null,'KH','Fast-track — delivered on time.'),
 ('2310','Enquiry Received',date '2025-09-10',true,'pre-con','JO',null),
 ('2310','Site Survey',date '2025-10-02',true,'pre-con','JO',null),
 ('2310','Tender Return',date '2026-05-20',true,'pre-con','JO',null),
 ('2310','Post-Tender Interview',date '2026-06-18',true,'pre-con','CG',null),
 ('2310','Contract Award',date '2026-06-30',true,'pre-con','CG','Verbal award — contract in drafting.'),
 ('2310','Design Freeze',date '2026-08-28',false,'design','PA',null),
 ('2310','Building Control Submission',date '2026-09-11',false,'technical','MAB',null),
 ('2310','First Fix Complete',date '2026-10-16',false,null,'CG',null),
 ('2310','Handover',date '2026-11-20',false,null,'CG',null),
 ('2311','Enquiry Received',date '2025-11-21',true,'pre-con','ZR',null),
 ('2311','Site Survey',date '2025-12-11',true,'pre-con','ZR',null),
 ('2311','Tender Issued',date '2026-06-05',true,'pre-con','ZR','ITT received from client PM.'),
 ('2311','Mid-Tender Interview',date '2026-07-18',true,'pre-con','PA',null),
 ('2311','Tender Return',date '2026-07-31',false,'pre-con','ZR',null),
 ('2312','Enquiry Received',date '2026-01-29',true,'pre-con','JO',null),
 ('2312','Site Survey',date '2026-03-10',true,'pre-con','JO',null),
 ('2312','Concept Presentation',date '2026-07-15',true,'design','RR','Pitch delivered — awaiting shortlist decision.'),
 ('2414','Enquiry Received',date '2026-02-14',true,'pre-con','JO',null),
 ('2414','Site Survey',date '2026-03-05',true,'pre-con','JO',null),
 ('2414','Tender Return',date '2026-05-08',true,'pre-con','JO',null),
 ('2414','Contract Award',date '2026-06-01',true,'pre-con','AA','Contract signed.'),
 ('2414','Design Freeze',date '2026-07-17',true,'design','FD',null),
 ('2414','Building Control Submission',date '2026-07-24',false,'technical','MAB',null),
 ('2414','First Fix Complete',date '2026-09-18',false,null,'AA',null),
 ('2414','FF&E Install',date '2026-10-30',false,'furniture','GB',null),
 ('2414','Handover',date '2026-11-13',false,null,'AA',null),
 ('2415','Enquiry Received',date '2026-03-22',true,'pre-con','ZR',null),
 ('2415','Site Survey',date '2026-04-15',true,'pre-con','ZR',null),
 ('2415','Tender Return',date '2026-06-10',true,'pre-con','ZR',null),
 ('2415','Contract Award',date '2026-07-01',true,'pre-con','EW',null),
 ('2415','Design Freeze',date '2026-08-21',false,'design','PA',null),
 ('2415','First Fix Complete',date '2026-10-23',false,null,'EW',null),
 ('2415','Handover',date '2026-12-18',false,null,'EW',null),
 ('2416','Enquiry Received',date '2026-05-08',true,'pre-con','JO',null),
 ('2416','Site Survey',date '2026-06-02',true,'pre-con','JO',null),
 ('2416','Tender Issued',date '2026-07-10',true,'pre-con','JO',null),
 ('2416','Tender Return',date '2026-08-14',false,'pre-con','JO',null),
 ('2417','Enquiry Received',date '2026-07-01',true,'pre-con','PA','Initial enquiry via website.'),
 ('2418','Enquiry Received',date '2026-07-09',true,'pre-con','JO',null),
 ('2418','Site Survey',date '2026-07-22',true,'pre-con','JO',null)
) as v(pn,event,target,done,mt,by,note)
join projects p on p.project_number = v.pn and p.org_id = 'c6e9cc3c-54d7-446a-895b-cf75ed0e93cd'::uuid
join app_users ub on ub.initials = v.by;

commit;

-- =====================================================================
-- Batch C — historic meetings + attendees
-- =====================================================================
begin;
set local session_replication_role = replica;

insert into meetings (org_id, meeting_type, meeting_date, status, chair_user_id, created_by, started_at, created_at, updated_at)
select 'c6e9cc3c-54d7-446a-895b-cf75ed0e93cd'::uuid, v.mt, v.md, 'closed', uc.id, ucr.id, v.started, v.started, v.started + interval '2 hours'
from (values
 ('design',   date '2025-09-18','PA','PA', timestamptz '2025-09-18 13:30+00'),
 ('technical',date '2025-09-25','MAB','MAB',timestamptz '2025-09-25 10:00+00'),
 ('pre-con',  date '2025-10-09','JO','JO', timestamptz '2025-10-09 09:30+00'),
 ('pm',       date '2025-10-16','CG','CG', timestamptz '2025-10-16 11:00+00'),
 ('design',   date '2025-11-13','PA','FD', timestamptz '2025-11-13 13:30+00'),
 ('furniture',date '2025-11-20','GB','TP', timestamptz '2025-11-20 14:00+00'),
 ('pre-con',  date '2025-12-04','JO','ZR', timestamptz '2025-12-04 09:30+00'),
 ('pm',       date '2026-01-15','CG','AA', timestamptz '2026-01-15 11:00+00'),
 ('design',   date '2026-02-12','PA','PA', timestamptz '2026-02-12 13:30+00'),
 ('technical',date '2026-03-05','MAB','TFS',timestamptz '2026-03-05 10:00+00'),
 ('pre-con',  date '2026-04-02','JO','JO', timestamptz '2026-04-02 09:30+00'),
 ('pm',       date '2026-05-14','CG','EW', timestamptz '2026-05-14 11:00+00'),
 ('design',   date '2026-06-11','PA','FD', timestamptz '2026-06-11 13:30+00'),
 ('furniture',date '2026-06-18','GB','GB', timestamptz '2026-06-18 14:00+00'),
 ('technical',date '2026-07-02','MAB','MAB',timestamptz '2026-07-02 10:00+00'),
 ('pre-con',  date '2026-07-16','JO','JO', timestamptz '2026-07-16 09:30+00')
) as v(mt,md,chair,creator,started)
join app_users uc on uc.initials = v.chair
join app_users ucr on ucr.initials = v.creator;

insert into meeting_attendees (org_id, meeting_id, user_id, present, created_at)
select 'c6e9cc3c-54d7-446a-895b-cf75ed0e93cd'::uuid, m.id, ua.id, v.present, m.started_at
from (values
 (timestamptz '2025-09-18 13:30+00','PA',true),(timestamptz '2025-09-18 13:30+00','FD',true),(timestamptz '2025-09-18 13:30+00','MAB',true),(timestamptz '2025-09-18 13:30+00','GB',true),(timestamptz '2025-09-18 13:30+00','AA',false),
 (timestamptz '2025-09-25 10:00+00','MAB',true),(timestamptz '2025-09-25 10:00+00','TFS',true),(timestamptz '2025-09-25 10:00+00','FD',true),(timestamptz '2025-09-25 10:00+00','KH',true),
 (timestamptz '2025-10-09 09:30+00','JO',true),(timestamptz '2025-10-09 09:30+00','ZR',true),(timestamptz '2025-10-09 09:30+00','PA',true),(timestamptz '2025-10-09 09:30+00','CG',true),
 (timestamptz '2025-10-16 11:00+00','CG',true),(timestamptz '2025-10-16 11:00+00','AA',true),(timestamptz '2025-10-16 11:00+00','EW',true),(timestamptz '2025-10-16 11:00+00','KH',false),(timestamptz '2025-10-16 11:00+00','RR',true),
 (timestamptz '2025-11-13 13:30+00','PA',true),(timestamptz '2025-11-13 13:30+00','FD',true),(timestamptz '2025-11-13 13:30+00','MAB',true),(timestamptz '2025-11-13 13:30+00','GB',true),
 (timestamptz '2025-11-20 14:00+00','GB',true),(timestamptz '2025-11-20 14:00+00','TP',true),(timestamptz '2025-11-20 14:00+00','PA',true),
 (timestamptz '2025-12-04 09:30+00','JO',true),(timestamptz '2025-12-04 09:30+00','ZR',true),(timestamptz '2025-12-04 09:30+00','PA',false),(timestamptz '2025-12-04 09:30+00','CG',true),
 (timestamptz '2026-01-15 11:00+00','CG',true),(timestamptz '2026-01-15 11:00+00','AA',true),(timestamptz '2026-01-15 11:00+00','EW',true),(timestamptz '2026-01-15 11:00+00','KH',true),(timestamptz '2026-01-15 11:00+00','RR',true),
 (timestamptz '2026-02-12 13:30+00','PA',true),(timestamptz '2026-02-12 13:30+00','FD',true),(timestamptz '2026-02-12 13:30+00','MAB',true),(timestamptz '2026-02-12 13:30+00','GB',true),(timestamptz '2026-02-12 13:30+00','AA',true),
 (timestamptz '2026-03-05 10:00+00','MAB',true),(timestamptz '2026-03-05 10:00+00','TFS',true),(timestamptz '2026-03-05 10:00+00','FD',true),(timestamptz '2026-03-05 10:00+00','KH',true),
 (timestamptz '2026-04-02 09:30+00','JO',true),(timestamptz '2026-04-02 09:30+00','ZR',true),(timestamptz '2026-04-02 09:30+00','PA',true),(timestamptz '2026-04-02 09:30+00','CG',false),
 (timestamptz '2026-05-14 11:00+00','CG',true),(timestamptz '2026-05-14 11:00+00','AA',true),(timestamptz '2026-05-14 11:00+00','EW',true),(timestamptz '2026-05-14 11:00+00','KH',true),(timestamptz '2026-05-14 11:00+00','RR',false),
 (timestamptz '2026-06-11 13:30+00','PA',true),(timestamptz '2026-06-11 13:30+00','FD',true),(timestamptz '2026-06-11 13:30+00','MAB',true),(timestamptz '2026-06-11 13:30+00','GB',true),
 (timestamptz '2026-06-18 14:00+00','GB',true),(timestamptz '2026-06-18 14:00+00','TP',true),(timestamptz '2026-06-18 14:00+00','PA',true),(timestamptz '2026-06-18 14:00+00','EW',true),
 (timestamptz '2026-07-02 10:00+00','MAB',true),(timestamptz '2026-07-02 10:00+00','TFS',true),(timestamptz '2026-07-02 10:00+00','FD',true),(timestamptz '2026-07-02 10:00+00','KH',true),
 (timestamptz '2026-07-16 09:30+00','JO',true),(timestamptz '2026-07-16 09:30+00','ZR',true),(timestamptz '2026-07-16 09:30+00','PA',true),(timestamptz '2026-07-16 09:30+00','CG',true)
) as v(started,ini,present)
join meetings m on m.started_at = v.started and m.org_id='c6e9cc3c-54d7-446a-895b-cf75ed0e93cd'::uuid
join app_users ua on ua.initials = v.ini;

commit;

-- =====================================================================
-- Batch D — meeting entries (dept notes; note field routed by meeting type)
-- =====================================================================
begin;
set local session_replication_role = replica;

insert into meeting_entries
(org_id, meeting_id, project_id,
 pre_con_note, design_note, technical_note, furniture_note, graphic_note, ops_note, snag_note,
 last_updated_by, reviewed_fields, created_at, updated_at)
select 'c6e9cc3c-54d7-446a-895b-cf75ed0e93cd'::uuid, m.id, p.id,
 case when v.field='pre_con_note'  then v.note end,
 case when v.field='design_note'   then v.note end,
 case when v.field='technical_note'then v.note end,
 case when v.field='furniture_note'then v.note end,
 case when v.field='graphic_note'  then v.note end,
 case when v.field='ops_note'      then v.note end,
 v.snag,
 ub.id,
 case when v.carried is not null
      then jsonb_build_object(v.field, jsonb_build_object('at', (m.started_at + interval '30 min'), 'by', ub.id, 'carried_from', v.carried))
      else '{}'::jsonb end,
 m.started_at, m.started_at + interval '90 min'
from (values
 (timestamptz '2025-09-18 13:30+00','2305','design_note','Space plan v2 issued. Client reviewing reception + town-hall stair concept.','PA',null,null),
 (timestamptz '2025-09-18 13:30+00','2306','design_note','Lab adjacencies agreed with client scientists. Wet/dry zoning locked.','FD',null,null),
 (timestamptz '2025-09-18 13:30+00','2307','design_note','Concept mood boards approved. Moving to spatial layouts.','PA',null,null),
 (timestamptz '2025-09-18 13:30+00','2308','design_note','Awaiting measured survey before layout can progress.','FD',null,null),
 (timestamptz '2025-09-25 10:00+00','2305','technical_note','Structural check on stair opening requested from engineer.','MAB',null,null),
 (timestamptz '2025-09-25 10:00+00','2306','technical_note','Specialist extract + gas detection spec under review with M&E.','TFS',null,null),
 (timestamptz '2025-09-25 10:00+00','2308','technical_note','Landlord to confirm riser capacity for additional comms.','MAB',null,null),
 (timestamptz '2025-10-09 09:30+00','2310','pre_con_note','Enquiry qualified. Site survey booked, awaiting NDA return.','JO',null,null),
 (timestamptz '2025-10-09 09:30+00','2307','pre_con_note','Budget costed at concept. Client indicated Q1 start.','ZR',null,null),
 (timestamptz '2025-10-09 09:30+00','2306','pre_con_note','Contract signed. Handing to delivery — long-lead extract plant flagged.','JO',null,'Long-lead plant order to be placed early.'),
 (timestamptz '2025-10-16 11:00+00','2305','ops_note','Pre-construction phase. Mobilisation plan being drafted for spring start.','CG',null,null),
 (timestamptz '2025-10-16 11:00+00','2306','ops_note','Programme agreed. Procuring principal packages.','AA',null,null),
 (timestamptz '2025-10-16 11:00+00','2308','ops_note','Tender queries with client, awaiting award.','EW',null,null),
 (timestamptz '2025-11-13 13:30+00','2305','design_note','Space plan v2 issued. Client reviewing reception + town-hall stair concept.','PA','2025-09-18',null),
 (timestamptz '2025-11-13 13:30+00','2306','design_note','Detailed design 60% complete. FF&E palette with furniture team.','FD',null,null),
 (timestamptz '2025-11-13 13:30+00','2307','design_note','Layouts signed off. Developing joinery details for reception.','PA',null,null),
 (timestamptz '2025-11-13 13:30+00','2308','design_note','Survey received; test-fit issued to client for comment.','FD',null,null),
 (timestamptz '2025-11-20 14:00+00','2305','furniture_note','Workstation benchmarking with three suppliers. Lead times 10-12 wks.','GB',null,null),
 (timestamptz '2025-11-20 14:00+00','2306','furniture_note','Lab stools + write-up desks specified. Sample chairs requested.','TP',null,null),
 (timestamptz '2025-11-20 14:00+00','2308','furniture_note','Awaiting design freeze before FF&E schedule.','GB',null,null),
 (timestamptz '2025-12-04 09:30+00','2310','pre_con_note','Survey complete. Preparing budget cost plan for client.','JO',null,null),
 (timestamptz '2025-12-04 09:30+00','2311','pre_con_note','New enquiry logged. Awaiting floor plans from landlord agent.','ZR',null,null),
 (timestamptz '2026-01-15 11:00+00','2305','ops_note','Client value-engineering exercise ongoing; start date holding.','CG',null,null),
 (timestamptz '2026-01-15 11:00+00','2306','ops_note','Site set-up scheduled April. Building control pre-app booked.','AA',null,null),
 (timestamptz '2026-01-15 11:00+00','2308','ops_note','Awarded. Contract in legals, mobilising for May start.','EW',null,null),
 (timestamptz '2026-02-12 13:30+00','2305','design_note','Design freeze imminent — final client comments on stair balustrade.','PA','2025-11-13',null),
 (timestamptz '2026-02-12 13:30+00','2306','design_note','Design frozen. Issued for construction.','FD',null,null),
 (timestamptz '2026-02-12 13:30+00','2307','design_note','On hold pending client fit-out budget re-approval.','PA',null,null),
 (timestamptz '2026-02-12 13:30+00','2308','design_note','Design freeze targeted end March.','FD',null,null),
 (timestamptz '2026-03-05 10:00+00','2305','technical_note','Building control package submitted. Awaiting comments.','MAB',null,null),
 (timestamptz '2026-03-05 10:00+00','2306','technical_note','As-built survey of existing services complete. IFC drawings issued.','TFS',null,null),
 (timestamptz '2026-03-05 10:00+00','2308','technical_note','Party wall award received. Structural openings coordinated.','MAB',null,null),
 (timestamptz '2026-04-02 09:30+00','2310','pre_con_note','Cost plan issued. Client indicated award subject to board sign-off.','JO',null,null),
 (timestamptz '2026-04-02 09:30+00','2311','pre_con_note','ITT expected June. Building the tender team.','ZR',null,null),
 (timestamptz '2026-04-02 09:30+00','2415','pre_con_note','Enquiry received. Healthcare client — CQC layout considerations noted.','JO',null,null),
 (timestamptz '2026-05-14 11:00+00','2305','ops_note','Strip-out complete. First fix underway across all floors.','CG',null,null),
 (timestamptz '2026-05-14 11:00+00','2306','ops_note','First fix progressing. M&E install starting July.','AA',null,null),
 (timestamptz '2026-05-14 11:00+00','2308','ops_note','Site started on programme. Strip-out complete.','EW',null,null),
 (timestamptz '2026-05-14 11:00+00','2414','ops_note','Contract signed. Pre-start meeting scheduled ahead of July start.','AA',null,null),
 (timestamptz '2026-06-11 13:30+00','2305','design_note','FF&E and signage packages being finalised for install.','PA',null,null),
 (timestamptz '2026-06-11 13:30+00','2307','design_note','Budget re-approved. Restarting detailed design.','FD',null,null),
 (timestamptz '2026-06-11 13:30+00','2414','design_note','Detailed design progressing to freeze mid-July.','FD',null,null),
 (timestamptz '2026-06-11 13:30+00','2415','design_note','Test-fit issued. Client workshops booked.','PA',null,null),
 (timestamptz '2026-06-18 14:00+00','2305','furniture_note','FF&E ordered. Delivery + install sequenced for October.','GB',null,null),
 (timestamptz '2026-06-18 14:00+00','2308','furniture_note','FF&E schedule signed off. Placing orders this week.','GB',null,null),
 (timestamptz '2026-06-18 14:00+00','2414','furniture_note','Budget furniture proposal with client for review.','TP',null,null),
 (timestamptz '2026-07-02 10:00+00','2305','technical_note','M&E commissioning plan agreed. Snag pre-check next month.','MAB',null,null),
 (timestamptz '2026-07-02 10:00+00','2307','technical_note','Building control strategy drafted for design freeze.','TFS',null,null),
 (timestamptz '2026-07-02 10:00+00','2414','technical_note','Building control package to submit at design freeze.','MAB',null,null),
 (timestamptz '2026-07-02 10:00+00','2415','technical_note','Existing services survey commissioned.','TFS',null,null),
 (timestamptz '2026-07-16 09:30+00','2311','pre_con_note','Mid-tender interview held. Return due end July.','JO','2026-04-02',null),
 (timestamptz '2026-07-16 09:30+00','2416','pre_con_note','ITT issued. Estimating team pricing structural + M&E.','JO',null,null),
 (timestamptz '2026-07-16 09:30+00','2415','pre_con_note','Contract awarded. Handing to delivery team.','JO',null,null),
 (timestamptz '2026-07-16 09:30+00','2418','pre_con_note','Pitch enquiry qualified. Whole-building HQ — survey underway.','ZR',null,null)
) as v(started,pn,field,note,by,carried,snag)
join meetings m on m.started_at = v.started and m.org_id='c6e9cc3c-54d7-446a-895b-cf75ed0e93cd'::uuid
join projects p on p.project_number = v.pn and p.org_id='c6e9cc3c-54d7-446a-895b-cf75ed0e93cd'::uuid
join app_users ub on ub.initials = v.by;

commit;

-- =====================================================================
-- Batch E — actions + collaborators + queries
-- =====================================================================
begin;
set local session_replication_role = replica;

insert into actions
(org_id, project_id, meeting_id, description, owner_user_id, due_date, status, priority,
 completed_note, completed_at, completed_by, created_by, created_at, updated_at)
select 'c6e9cc3c-54d7-446a-895b-cf75ed0e93cd'::uuid, p.id, m.id, v.descr, uo.id, v.due, v.status, v.priority,
 v.note,
 case when v.status='closed' then (v.due::timestamptz + interval '1 day') else null end,
 case when v.status='closed' then uo.id else null end,
 ucr.id,
 coalesce(m.started_at, v.due::timestamptz - interval '20 days'),
 case when v.status='closed' then (v.due::timestamptz + interval '1 day') else coalesce(m.started_at, v.due::timestamptz - interval '20 days') end
from (values
 ('Issue structural feasibility report for the feature stair','2305',timestamptz '2025-09-25 10:00+00','MAB','PA', date '2025-10-10','closed','high','Engineer confirmed feasible with a new goalpost frame.'),
 ('Place long-lead order for the lab extract plant','2306',timestamptz '2025-10-09 09:30+00','AA','JO', date '2025-10-31','closed','high','Ordered — 12 week lead time confirmed.'),
 ('Benchmark workstation suppliers and report lead times','2305',timestamptz '2025-11-20 14:00+00','GB','GB', date '2025-12-05','closed','normal','Three suppliers benchmarked; report circulated.'),
 ('Prepare the budget cost plan for the client','2310',timestamptz '2025-12-04 09:30+00','ZR','JO', date '2026-01-09','closed','high','Cost plan issued to client.'),
 ('Submit the building control package','2305',timestamptz '2026-03-05 10:00+00','MAB','MAB', date '2026-03-20','closed','normal','Submitted; awaiting officer comments.'),
 ('Coordinate structural openings with the party wall award','2308',timestamptz '2026-03-05 10:00+00','TFS','MAB', date '2026-03-27','closed','normal','Coordinated and issued to site.'),
 ('Confirm board sign-off and issue the contract','2310',timestamptz '2026-04-02 09:30+00','CG','JO', date '2026-05-30','closed','high','Verbal award received 30 Jun; contract drafting.'),
 ('Build the tender team for the Paddington ITT','2311',timestamptz '2026-04-02 09:30+00','ZR','ZR', date '2026-05-15','open','normal',null),
 ('Order FF&E for reception and the workspace','2305',timestamptz '2026-06-18 14:00+00','GB','GB', date '2026-07-03','closed','high','Orders placed; delivery scheduled October.'),
 ('Issue the FF&E schedule for sign-off','2308',timestamptz '2026-06-18 14:00+00','GB','EW', date '2026-07-10','closed','normal','Signed off; orders placed.'),
 ('Submit building control at design freeze','2414',timestamptz '2026-07-02 10:00+00','MAB','MAB', date '2026-08-07','open','normal',null),
 ('Commission the existing services survey','2415',timestamptz '2026-07-02 10:00+00','TFS','TFS', date '2026-07-20','open','normal',null),
 ('Price structural and M&E for the Farringdon tender','2416',timestamptz '2026-07-16 09:30+00','ZR','JO', date '2026-08-08','open','high',null),
 ('Arrange the whole-building survey','2418',timestamptz '2026-07-16 09:30+00','JO','ZR', date '2026-07-28','open','normal',null),
 ('Chase M&E commissioning dates with the subcontractor','2305',null,'CG','CG', date '2026-07-22','open','high',null),
 ('Prepare the pre-start meeting pack','2414',null,'AA','AA', date '2026-07-18','closed','normal','Pack issued to team and client.'),
 ('Snag pre-check the top two floors','2308',null,'EW','EW', date '2026-08-20','open','normal',null),
 ('Re-approve the fit-out budget with client finance','2307',null,'RR','PA', date '2026-06-05','closed','high','Budget re-approved 10 Jun.'),
 ('Confirm CQC-compliant layout assumptions','2415',null,'PA','EW', date '2026-08-14','open','normal',null),
 ('Return the post-project feedback report','2304',null,'PA','PA', date '2024-12-20','closed','low','Feedback logged for future bids.'),
 ('Book the client discovery workshop','2417',null,'PA','PA', date '2026-07-14','open','low',null),
 ('Issue the design and access statement to the client','2414',null,'FD','AA', date '2026-07-31','open','normal',null),
 ('Confirm the furniture budget proposal approval','2414',null,'TP','GB', date '2026-07-25','open','low',null),
 ('Coordinate handover documentation (O&M manuals)','2306',null,'AA','AA', date '2026-08-18','open','high',null)
) as v(descr,pn,mstart,owner,creator,due,status,priority,note)
join projects p on p.project_number=v.pn and p.org_id='c6e9cc3c-54d7-446a-895b-cf75ed0e93cd'::uuid
join app_users uo on uo.initials=v.owner
join app_users ucr on ucr.initials=v.creator
left join meetings m on m.started_at=v.mstart and m.org_id='c6e9cc3c-54d7-446a-895b-cf75ed0e93cd'::uuid;

insert into action_assignees (org_id, action_id, user_id, created_at)
select 'c6e9cc3c-54d7-446a-895b-cf75ed0e93cd'::uuid, a.id, u.id, a.created_at
from (values
 ('Issue structural feasibility report for the feature stair','TFS'),
 ('Issue structural feasibility report for the feature stair','FD'),
 ('Price structural and M&E for the Farringdon tender','MAB'),
 ('Coordinate handover documentation (O&M manuals)','KH')
) as v(descr,ini)
join actions a on a.description=v.descr and a.org_id='c6e9cc3c-54d7-446a-895b-cf75ed0e93cd'::uuid
join app_users u on u.initials=v.ini;

insert into action_queries (org_id, action_id, raised_by, target_user_id, query_text, raised_at, answered_by, answer_text, answered_at)
select 'c6e9cc3c-54d7-446a-895b-cf75ed0e93cd'::uuid, a.id, rb.id, tu.id, v.q, a.created_at + interval '1 day',
 ab.id, v.ans, case when v.ans is not null then a.created_at + interval '2 day' else null end
from (values
 ('Chase M&E commissioning dates with the subcontractor','CG','MAB','Do we have commissioning dates back from the M&E subbie yet?',null,null),
 ('Submit building control at design freeze','AA','MAB','Confirm the building control route — full plans or building notice?','MAB','Full plans — submitting at the design freeze.')
) as v(descr,rbi,tui,q,abi,ans)
join actions a on a.description=v.descr and a.org_id='c6e9cc3c-54d7-446a-895b-cf75ed0e93cd'::uuid
join app_users rb on rb.initials=v.rbi
join app_users tu on tu.initials=v.tui
left join app_users ab on ab.initials=v.abi;

commit;

-- =====================================================================
-- Batch F — flags (meeting_handoffs); open + acknowledged, 2 converted
-- =====================================================================
begin;
set local session_replication_role = replica;

insert into meeting_handoffs
(org_id, project_id, from_meeting_id, from_meeting_type, to_department, note, created_by,
 acknowledged_by, acknowledged_at, status, resulting_action_id, created_at)
select 'c6e9cc3c-54d7-446a-895b-cf75ed0e93cd'::uuid, p.id, m.id, v.fmt, v.todept, v.note, ucr.id,
 uack.id,
 case when v.status='acknowledged' then m.started_at + interval '5 days' else null end,
 v.status,
 act.id,
 m.started_at + interval '10 min'
from (values
 ('2305',timestamptz '2025-09-18 13:30+00','design','technical','Feature stair needs structural sign-off before we can freeze the design.','FD','MAB','acknowledged','Issue structural feasibility report for the feature stair'),
 ('2306',timestamptz '2025-10-09 09:30+00','pre-con','pm','Long-lead extract plant — delivery team to place the order early.','JO','AA','acknowledged','Place long-lead order for the lab extract plant'),
 ('2308',timestamptz '2026-03-05 10:00+00','technical','design','Riser capacity is limited — design to confirm comms routing.','MAB',null,'open',null),
 ('2305',timestamptz '2026-05-14 11:00+00','pm','furniture','FF&E install must sequence around M&E commissioning in October.','CG','GB','acknowledged',null),
 ('2414',timestamptz '2026-06-11 13:30+00','design','technical','Design freeze mid-July — building control package needs to follow straight after.','FD','MAB','acknowledged',null),
 ('2415',timestamptz '2026-04-02 09:30+00','pre-con','design','New healthcare enquiry — early CQC layout input needed.','JO',null,'open',null),
 ('2307',timestamptz '2026-02-12 13:30+00','design','pm','Project on hold — PM to confirm the client budget position.','PA','RR','acknowledged',null),
 ('2311',timestamptz '2026-07-16 09:30+00','pre-con','pm','Tender return end July — need PM input on programme assumptions.','JO',null,'open',null),
 ('2416',timestamptz '2026-07-16 09:30+00','pre-con','technical','Structural survey required to price the vaults conversion.','JO',null,'open',null)
) as v(pn,mstart,fmt,todept,note,creator,acker,status,act_descr)
join projects p on p.project_number=v.pn and p.org_id='c6e9cc3c-54d7-446a-895b-cf75ed0e93cd'::uuid
join meetings m on m.started_at=v.mstart and m.org_id='c6e9cc3c-54d7-446a-895b-cf75ed0e93cd'::uuid
join app_users ucr on ucr.initials=v.creator
left join app_users uack on uack.initials=v.acker
left join actions act on act.description=v.act_descr and act.org_id='c6e9cc3c-54d7-446a-895b-cf75ed0e93cd'::uuid;

commit;
