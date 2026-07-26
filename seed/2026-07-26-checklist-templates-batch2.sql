-- Checklist module templates — batch 2 (7 further tabs from the workbook).
-- APPLIED to the live dev DB on 2026-07-26.
-- PM Checklist (workbook tab 22) is deliberately NOT here: it is a blank
-- per-project information-required register, not a fixed-question checklist,
-- so it belongs to the register module type rather than this component.

delete from public.module_template_items where module_key in ('designer','graphics','legal-kick-off','legal-process','wpb-kick-off','onsite-handover','accountant');

delete from public.module_templates where module_key in ('designer','graphics','legal-kick-off','legal-process','wpb-kick-off','onsite-handover','accountant');

insert into public.module_templates (org_id, module_key, label, tab, mode, status_set, config, sort_order) select id, 'designer', 'Designer Checklist', 'Designer', 'record', 'rag', '{"blurb":"The design checkpoints carried through the project — key risks up front, the weekly discipline, then every design gate that has to be closed before adjudication.","registerTitle":"Designer register","colItem":"Item","colInput":"Notes / evidence","colStatus":"Status","colMeta":"Last updated","inputPlaceholder":"Notes, drawing ref, who confirmed…","modeBadge":"Record","owner":"Priya Anand","ownerInitials":"PA","ownerRole":"Design Director","signOff":true,"signOffCaption":"Design Director sign-off marks the design complete and stamps it into the project audit trail.","flagOnAttention":true,"defaultTeam":"technical","requireDetail":true,"stage":"design development","expected":85,"routingNote":"Record tab — a design gate left as “further info required” is a warning for the technical team, so it prompts a flag onto that team’s next meeting. Anything owned by one person becomes an action instead.","progressLabel":"Design gates closed"}'::jsonb, 4 from public.organisations limit 1;

insert into public.module_template_items (org_id, module_key, section_index, section_title, row_index, text, who) select o.id, v.* from (select id from public.organisations limit 1) o, (values
  ('designer',0,'Key Risks',0,'Is the building an HRB?',null),
  ('designer',0,'Key Risks',1,'Have we received the fit-out guide and reviewed it?',null),
  ('designer',0,'Key Risks',2,'Have we received the fire strategy and cross-checked it against our design?',null),
  ('designer',1,'Weekly',0,'Check visuals and plan for updates; archive the previous revision',null),
  ('designer',1,'Weekly',1,'Engage with building control and carry out compliance reviews with the Technical Designer',null),
  ('designer',1,'Weekly',2,'Ensure CAD/Revit and PDF folders are tidy and hold current revisions only',null),
  ('designer',1,'Weekly',3,'Have a weekly catch-up with the Commercial Manager',null),
  ('designer',2,'Design Checklist',0,'Have the employer’s requirements been read and reflected in the design?',null),
  ('designer',2,'Design Checklist',1,'Has a site measured survey been completed?',null),
  ('designer',2,'Design Checklist',2,'Has a matterport survey been completed?',null),
  ('designer',2,'Design Checklist',3,'Has the drawing issue sheet been produced with dates defined with Precon & Technical Designer?',null),
  ('designer',2,'Design Checklist',4,'Has the GA been fixed?',null),
  ('designer',2,'Design Checklist',5,'Do you require building control consultancy / a fire engineer on this project?',null),
  ('designer',2,'Design Checklist',6,'Has the building control sign-off been completed?',null),
  ('designer',2,'Design Checklist',7,'Have the LTA comments been closed out?',null),
  ('designer',2,'Design Checklist',8,'Has the tenant occupancy been confirmed in line with the building’s fresh air requirements and fire strategy?',null),
  ('designer',2,'Design Checklist',9,'Has the fire strategy been considered and incorporated into the design?',null),
  ('designer',2,'Design Checklist',10,'Have the structural calculations been produced (by the Structural Engineer) and the design coordinated?',null),
  ('designer',2,'Design Checklist',11,'Has the furniture coordination meeting taken place and been considered in line with low-level power?',null),
  ('designer',2,'Design Checklist',12,'Has the AV been coordinated?',null),
  ('designer',2,'Design Checklist',13,'Has the RCP been coordinated and all clashes identified with design mitigations incorporated?',null),
  ('designer',2,'Design Checklist',14,'Have access panels been coordinated with building services to ensure accessibility?',null),
  ('designer',2,'Design Checklist',15,'Does the client require an access statement and have they been made aware of any mitigations?',null),
  ('designer',2,'Design Checklist',16,'Has the IRS been completed?',null),
  ('designer',2,'Design Checklist',17,'Has the finishes schedule been completed and populated?',null),
  ('designer',3,'Adjudication Checklist Items',0,'Have you reviewed the adjudication checklist?',null),
  ('designer',3,'Adjudication Checklist Items',1,'Have you read and confirmed the CPs for contract?',null),
  ('designer',3,'Adjudication Checklist Items',2,'Have you completed the Designer’s Risk Register?',null),
  ('designer',3,'Adjudication Checklist Items',3,'Have all finishes been sent to the client and agreed with sign-off?',null)
) as v(module_key, section_index, section_title, row_index, text, who);

insert into public.module_templates (org_id, module_key, label, tab, mode, status_set, config, sort_order) select id, 'graphics', 'Graphics Checklist', 'Graphics', 'reference', 'yesno', '{"blurb":"Everything the graphics team needs lined up before a pitch deadline — sales and PM intel, the deadline shape, then the post-win and post-completion follow-ups. A reference, read at the stage.","registerTitle":"Graphics reference","colItem":"Item","colInput":"Answer","colStatus":"Covered","colMeta":"Last updated","inputPlaceholder":"What do we know…","modeBadge":"Reference","owner":"Felix Dubois","ownerInitials":"FD","ownerRole":"Designer","signOff":false,"flagOnAttention":false,"defaultTeam":"pre-con","requireDetail":false,"stage":"pitch preparation","expected":60,"routingNote":"Reference tab — nothing routes out of here by default. It exists so the team can ask “have we covered this yet before the deadline?” Raise a flag or action from a row only if you choose to.","progressLabel":"Items covered"}'::jsonb, 5 from public.organisations limit 1;

insert into public.module_template_items (org_id, module_key, section_index, section_title, row_index, text, who) select o.id, v.* from (select id from public.organisations limit 1) o, (values
  ('graphics',0,'Sales Intel',0,'Confirmed website address',null),
  ('graphics',0,'Sales Intel',1,'Confirmed building / site address',null),
  ('graphics',0,'Sales Intel',2,'Client hot button / key issues',null),
  ('graphics',0,'Sales Intel',3,'Do Arke have experience in the building?',null),
  ('graphics',0,'Sales Intel',4,'Important connections or background',null),
  ('graphics',1,'PM Intel',0,'Is there an external PM?',null),
  ('graphics',1,'PM Intel',1,'Is there a client-appointed architect?',null),
  ('graphics',2,'Deadline Overview',0,'Submission date and time',null),
  ('graphics',2,'Deadline Overview',1,'Who is submitting?',null),
  ('graphics',2,'Deadline Overview',2,'Who is on the team?',null),
  ('graphics',2,'Deadline Overview',3,'Are any of the team on holiday during the deadline week?',null),
  ('graphics',3,'Document Specifics',0,'Exec summary needed?',null),
  ('graphics',3,'Document Specifics',1,'Brief confirmed?',null),
  ('graphics',3,'Document Specifics',2,'Any particular doc style / guidance?',null),
  ('graphics',3,'Document Specifics',3,'Is a hard copy / printed version required?',null),
  ('graphics',4,'Key Meetings',0,'Kick-off meeting date',null),
  ('graphics',4,'Key Meetings',1,'Rehearsal date (24 hours before the deadline)',null),
  ('graphics',4,'Key Meetings',2,'Final presentation format / enhanced option required? (pre-pitch)',null),
  ('graphics',5,'Post Win',0,'Site signage / window signage',null),
  ('graphics',6,'Post Completion',0,'Photography',null),
  ('graphics',6,'Post Completion',1,'Testimonial requested',null),
  ('graphics',6,'Post Completion',2,'Has the designer provided a write-up?',null)
) as v(module_key, section_index, section_title, row_index, text, who);

insert into public.module_templates (org_id, module_key, label, tab, mode, status_set, config, sort_order) select id, 'legal-kick-off', 'Legal Kick Off', 'Legal Kick Off', 'record', 'rag', '{"blurb":"The questions legal needs answered to review the contract — the client, the works, the property, the technical and financial position. Completed by MD/TD, then sent to compliance.","registerTitle":"Legal kick-off register","colItem":"Query","colInput":"MD / TD response","colStatus":"Status","colMeta":"Last updated","inputPlaceholder":"Response for legal…","modeBadge":"Record","owner":"Jen Okafor","ownerInitials":"JO","ownerRole":"Pre-Construction Manager","signOff":true,"signOffCaption":"Sign-off confirms the kick-off is complete and ready to send to compliance and legal.","flagOnAttention":true,"defaultTeam":"pre-con","requireDetail":true,"stage":"contract kick-off","expected":90,"routingNote":"Record tab — a query left as “further info required” is a warning for the pre-con team, so it prompts a flag onto that team’s next meeting. Anything owned by one person becomes an action instead.","progressLabel":"Queries answered"}'::jsonb, 6 from public.organisations limit 1;

insert into public.module_template_items (org_id, module_key, section_index, section_title, row_index, text, who) select o.id, v.* from (select id from public.organisations limit 1) o, (values
  ('legal-kick-off',0,'The Client',0,'Have we worked for this client before? If so, when and on what site?',null),
  ('legal-kick-off',0,'The Client',1,'Full name of the contracting entity and company registration number',null),
  ('legal-kick-off',0,'The Client',2,'Is there a professional team / EA acting for the client?',null),
  ('legal-kick-off',1,'The Works',0,'Describe the nature of the works: regular CAT B internal fit-out only, or any CAT A, groundworks or structural elements?',null),
  ('legal-kick-off',1,'The Works',1,'Estimated contract sum value if known (to nearest £m)',null),
  ('legal-kick-off',1,'The Works',2,'Timings: estimated length of works? Hard PC date? Anticipated start date?',null),
  ('legal-kick-off',1,'The Works',3,'Are there any structural elements to the existing structure?',null),
  ('legal-kick-off',1,'The Works',4,'Any cladding or fire related works?',null),
  ('legal-kick-off',1,'The Works',5,'Is the building high risk under the BSA?',null),
  ('legal-kick-off',1,'The Works',6,'Neighbours: is the site multi-tenanted? Will neighbouring properties be occupied? Noisy works?',null),
  ('legal-kick-off',1,'The Works',7,'Are we being asked to take responsibility for any previous design? If so, send the designer’s scope/quote',null),
  ('legal-kick-off',1,'The Works',8,'Will the client have their own appointed contractors we need to manage, or consultants novated to us?',null),
  ('legal-kick-off',1,'The Works',9,'Is furniture to be included in the scope, or procured separately?',null),
  ('legal-kick-off',1,'The Works',10,'Is Maris prepared to take responsibility for reviewing existing site conditions? If so, mitigated with a full survey?',null),
  ('legal-kick-off',1,'The Works',11,'Who is responsible for site security — shared, us, or the client’s?',null),
  ('legal-kick-off',1,'The Works',12,'Have we assumed all utilities will be provided by the client? Check.',null),
  ('legal-kick-off',1,'The Works',13,'Any particular risks associated with the works to bear in mind when reviewing the contract?',null),
  ('legal-kick-off',2,'The Property',0,'Who owns it? Freehold or leasehold — if leasehold, will there be a Licence to Alter?',null),
  ('legal-kick-off',2,'The Property',1,'What is the trigger for the move? Is the completion date a genuine hard long-stop?',null),
  ('legal-kick-off',2,'The Property',2,'What is the age of the building?',null),
  ('legal-kick-off',2,'The Property',3,'When was the building last renovated?',null),
  ('legal-kick-off',2,'The Property',4,'What is the full reinstatement value of the building?',null),
  ('legal-kick-off',2,'The Property',5,'Any site restrictions — access, times of work, other contractors on site — consider CDM F10',null),
  ('legal-kick-off',3,'Technical Requirements',0,'Do we have a brief / ERs / tender pack? Any performance specs? If so, send.',null),
  ('legal-kick-off',3,'Technical Requirements',1,'Do we anticipate accepting the ERs with a schedule of derogations, or making the Contractor’s Proposals the employer’s requirements?',null),
  ('legal-kick-off',3,'Technical Requirements',2,'Are there any third party agreements? (Fit-Out Guide? LTA? Lease? Local council requirements?)',null),
  ('legal-kick-off',4,'Financial Due Diligence & Security',0,'Client due diligence — have we run a credit check? What is the source of funds?',null),
  ('legal-kick-off',4,'Financial Due Diligence & Security',1,'Supply chain due diligence — are all subbies PQQ’d and on Samson? PII certificates for designers?',null),
  ('legal-kick-off',4,'Financial Due Diligence & Security',2,'Does Maris require an advanced payment? If so, what % of the contract sum?',null),
  ('legal-kick-off',4,'Financial Due Diligence & Security',3,'Does the client require a performance bond?',null),
  ('legal-kick-off',5,'Contract Procurement',0,'Form of contract?',null),
  ('legal-kick-off',5,'Contract Procurement',1,'Collateral warranties / third party rights?',null),
  ('legal-kick-off',5,'Contract Procurement',2,'Insurance?',null)
) as v(module_key, section_index, section_title, row_index, text, who);

insert into public.module_templates (org_id, module_key, label, tab, mode, status_set, config, sort_order) select id, 'legal-process', 'Legal Process', 'Legal Process', 'record', 'rag', '{"blurb":"The commercial manager’s running legal record — contracting entity, the documents in play, the contract risks, particulars and financial terms carried through to signing.","registerTitle":"Legal process register","colItem":"Item","colInput":"Response","colStatus":"Status","colMeta":"Last updated","inputPlaceholder":"Response…","modeBadge":"Record","owner":"Jen Okafor","ownerInitials":"JO","ownerRole":"Pre-Construction Manager","signOff":true,"signOffCaption":"Sign-off confirms the legal position is settled ahead of contract signing.","flagOnAttention":true,"defaultTeam":"pre-con","requireDetail":true,"stage":"contract","expected":90,"routingNote":"Record tab — an item left as “further info required” is a warning for the pre-con team, so it prompts a flag onto that team’s next meeting. Anything owned by one person becomes an action instead.","progressLabel":"Items resolved"}'::jsonb, 7 from public.organisations limit 1;

insert into public.module_template_items (org_id, module_key, section_index, section_title, row_index, text, who) select o.id, v.* from (select id from public.organisations limit 1) o, (values
  ('legal-process',0,'Contracting Entity',0,'Who is the legal contracting entity?',null),
  ('legal-process',0,'Contracting Entity',1,'Registered UK limited company',null),
  ('legal-process',0,'Contracting Entity',2,'Other',null),
  ('legal-process',0,'Contracting Entity',3,'Is a credit check required?',null),
  ('legal-process',0,'Contracting Entity',4,'Is external legal support required?',null),
  ('legal-process',0,'Contracting Entity',5,'Has anything been agreed at tender stage?',null),
  ('legal-process',0,'Contracting Entity',6,'Who is preparing the contract?',null),
  ('legal-process',1,'Contracting Documents',0,'Unamended JCT',null),
  ('legal-process',1,'Contracting Documents',1,'Arke short form contract',null),
  ('legal-process',1,'Contracting Documents',2,'JCT with SOA',null),
  ('legal-process',1,'Contracting Documents',3,'LOI',null),
  ('legal-process',1,'Contracting Documents',4,'PCSA',null),
  ('legal-process',1,'Contracting Documents',5,'Deviation schedule',null),
  ('legal-process',1,'Contracting Documents',6,'Visuals deviation',null),
  ('legal-process',2,'Additional Contract Risks',0,'Have warranties been requested?',null),
  ('legal-process',2,'Additional Contract Risks',1,'Are there any incumbent contractors?',null),
  ('legal-process',2,'Additional Contract Risks',2,'Is the project an HRB — how are the sign-off periods treated?',null),
  ('legal-process',2,'Additional Contract Risks',3,'Is furniture included within the contract?',null),
  ('legal-process',2,'Additional Contract Risks',4,'Is there any additional design risk, including any design novation?',null),
  ('legal-process',2,'Additional Contract Risks',5,'Have we checked third party agreements? (Please list)',null),
  ('legal-process',3,'Particulars',0,'Public liability insurance requirements',null),
  ('legal-process',3,'Particulars',1,'What insurance option is being requested?',null),
  ('legal-process',3,'Particulars',2,'What is the project start date?',null),
  ('legal-process',3,'Particulars',3,'How long is the project on site?',null),
  ('legal-process',3,'Particulars',4,'What is the practical completion date?',null),
  ('legal-process',3,'Particulars',5,'What are the liquidated damages?',null),
  ('legal-process',3,'Particulars',6,'Is there a deferment period?',null),
  ('legal-process',3,'Particulars',7,'What is the retention period?',null),
  ('legal-process',3,'Particulars',8,'What is the retention value?',null),
  ('legal-process',3,'Particulars',9,'Is a retention bond required?',null),
  ('legal-process',4,'Financial',0,'Is it valuations or payment schedule?',null),
  ('legal-process',4,'Financial',1,'What is the date for the first valuation?',null),
  ('legal-process',4,'Financial',2,'Project management review period?',null),
  ('legal-process',4,'Financial',3,'What are the proposed payment terms?',null),
  ('legal-process',5,'Furniture',0,'Does furniture form part of the contract?',null)
) as v(module_key, section_index, section_title, row_index, text, who);

insert into public.module_templates (org_id, module_key, label, tab, mode, status_set, config, sort_order) select id, 'wpb-kick-off', 'WPB Kick Off', 'WPB Kick Off', 'signoff', 'complete', '{"blurb":"The workplace-build kick-off sequence: TD kicks it off, the budget comes back, detailed design follows within the CAT B / CAT A&B windows. Each step against the person responsible.","registerTitle":"WPB kick-off actions","colItem":"Action","colInput":"Comment","colStatus":"Status","colMeta":"Last updated","inputPlaceholder":"Comment…","modeBadge":"Sign-off","owner":"Marcus Bell","ownerInitials":"MB","ownerRole":"Technical Design Lead","signOff":true,"signOffCaption":"Sign-off confirms the workplace-build kick-off is complete and design is underway.","flagOnAttention":false,"defaultTeam":"technical","requireDetail":false,"stage":"kick-off","expected":100,"routingNote":"Sign-off tab — a blocked step becomes an action against the person responsible rather than a flag to a whole team.","progressLabel":"Steps complete"}'::jsonb, 8 from public.organisations limit 1;

insert into public.module_template_items (org_id, module_key, section_index, section_title, row_index, text, who) select o.id, v.* from (select id from public.organisations limit 1) o, (values
  ('wpb-kick-off',0,'Workplace Build Kick Off',0,'TD to kick off the project with WPB','TD'),
  ('wpb-kick-off',0,'Workplace Build Kick Off',1,'Operations Coordinator to book a meeting 72 hours later for WPB to come back to Maris with budget cost','OC'),
  ('wpb-kick-off',0,'Workplace Build Kick Off',2,'Budget agreed?',null),
  ('wpb-kick-off',0,'Workplace Build Kick Off',3,'Detailed design based on the agreed budget',null),
  ('wpb-kick-off',0,'Workplace Build Kick Off',4,'Detailed design to be issued to Maris no later than: CAT B – 1 week; CAT A & B – 2 weeks',null),
  ('wpb-kick-off',0,'Workplace Build Kick Off',5,'Operations Coordinator to book in the follow-up meeting accordingly','OC')
) as v(module_key, section_index, section_title, row_index, text, who);

insert into public.module_templates (org_id, module_key, label, tab, mode, status_set, config, sort_order) select id, 'onsite-handover', 'Onsite Handover', 'Onsite Handover', 'signoff', 'complete', '{"blurb":"The Week -4 onsite handover preparation — visuals, drawings and access lined up before the meeting, then the follow-up handover booked. Each item against the person responsible.","registerTitle":"Handover preparation","colItem":"Action","colInput":"Comment","colStatus":"Status","colMeta":"Last updated","inputPlaceholder":"Comment…","modeBadge":"Sign-off","owner":"Carlos Garcia","ownerInitials":"CG","ownerRole":"Senior Project Manager","signOff":true,"signOffCaption":"Sign-off confirms the site is ready for the handover meeting.","flagOnAttention":false,"defaultTeam":"pre-con","requireDetail":false,"stage":"week -4","expected":100,"routingNote":"Sign-off tab — a blocked item becomes an action against the person responsible rather than a flag to a whole team.","progressLabel":"Preparation complete"}'::jsonb, 9 from public.organisations limit 1;

insert into public.module_template_items (org_id, module_key, section_index, section_title, row_index, text, who) select o.id, v.* from (select id from public.organisations limit 1) o, (values
  ('onsite-handover',0,'Handover Preparation (Week -4)',0,'Visuals, finishes schedule and drawing issue pack printed and displayed on site one hour before the meeting','DD'),
  ('onsite-handover',0,'Handover Preparation (Week -4)',1,'Access to be arranged in advance','OC'),
  ('onsite-handover',0,'Handover Preparation (Week -4)',2,'Drawings printed and available on site','DD'),
  ('onsite-handover',0,'Handover Preparation (Week -4)',3,'Follow-up handover in the office arranged','OC')
) as v(module_key, section_index, section_title, row_index, text, who);

insert into public.module_templates (org_id, module_key, label, tab, mode, status_set, config, sort_order) select id, 'accountant', 'Accountant On Site', 'Accountant On Site', 'signoff', 'complete', '{"blurb":"The accountant’s on-site responsibilities running through the project — valuations and invoices on time, timesheets, payment tracking and the 7-day letters.","registerTitle":"Accounts responsibilities","colItem":"Responsibility","colInput":"Comment","colStatus":"Status","colMeta":"Last updated","inputPlaceholder":"Comment…","modeBadge":"Sign-off","owner":"Zara Reid","ownerInitials":"ZR","ownerRole":"Accounts","signOff":true,"signOffCaption":"Sign-off confirms the accounts responsibilities are being run for this project.","flagOnAttention":false,"defaultTeam":"pre-con","requireDetail":false,"stage":"on site","expected":100,"routingNote":"Sign-off tab — a blocked responsibility becomes an action against the person responsible rather than a flag to a whole team.","progressLabel":"Responsibilities running"}'::jsonb, 10 from public.organisations limit 1;

insert into public.module_template_items (org_id, module_key, section_index, section_title, row_index, text, who) select o.id, v.* from (select id from public.organisations limit 1) o, (values
  ('accountant',0,'Accounts',0,'Ensure valuations / invoices are submitted on time as per the JCT',null),
  ('accountant',0,'Accounts',1,'Timesheets',null),
  ('accountant',0,'Accounts',2,'Keep track of client due dates and payments and report any late payments',null),
  ('accountant',0,'Accounts',3,'Issue 7-day letters',null)
) as v(module_key, section_index, section_title, row_index, text, who);

