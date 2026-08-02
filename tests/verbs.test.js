// Mock-PostgREST unit test for the Step 2.5 verbs. Extracts the REAL verb source
// from app.jsx (between --VERBS-BEGIN-- / --VERBS-END--) so there is no drift,
// evals it with a mock `sb` + recording `logItemEvent`, and asserts each verb's
// write shape, item_events, refusal-throws and return value.
const fs = require('fs');
const src = fs.readFileSync(process.argv[2], 'utf8');
const block = src.split('--VERBS-BEGIN--')[1].split('--VERBS-END--')[0];

let sbCalls = [];
let events = [];
let resolver = null;
function makeBuilder(table) {
  const ctx = { table, op: null, payload: null, sel: null, single: false };
  const b = {
    update(o) { ctx.op = 'update'; ctx.payload = o; return b; },
    insert(o) { ctx.op = 'insert'; ctx.payload = o; return b; },
    delete() { ctx.op = 'delete'; return b; },
    eq() { return b; },
    select(c) { ctx.sel = c || '*'; return b; },
    single() { ctx.single = true; return b; },
    then(res, rej) { sbCalls.push(Object.assign({}, ctx)); return Promise.resolve(resolver(ctx)).then(res, rej); },
  };
  return b;
}
const sb = { from: (t) => makeBuilder(t) };
async function logItemEvent(itemType, itemId, eventType, opts) { events.push({ itemType, itemId, eventType, opts }); }

const verbs = new Function('sb', 'logItemEvent', block +
  '\nreturn { completeAction, reopenAction, acknowledgeFlag, convertFlag, resolveQuery, answerQuery, escalateQuery, markDateMet, moveDate };')(sb, logItemEvent);

let pass = 0, fail = 0;
function ok(cond, msg) { if (cond) { pass++; } else { fail++; console.log('  ✗ ' + msg); } }
function reset(r) { sbCalls = []; events = []; resolver = r; }
const OK_ROWS = (ctx) => ({ data: ctx.single ? { id: 'new-id' } : [{ id: 'row-1' }], error: null });
const ZERO_ROWS = (ctx) => ({ data: ctx.single ? null : [], error: null });
const ERR = () => ({ data: null, error: { message: 'boom' } });

(async () => {
  // 1. completeAction — write shape + event
  reset(OK_ROWS);
  await verbs.completeAction({ id: 'a1' }, { actorId: 'u1', orgId: 'o1', note: 'done well' });
  ok(sbCalls.length === 1 && sbCalls[0].table === 'actions' && sbCalls[0].op === 'update', 'completeAction updates actions');
  ok(sbCalls[0].payload.status === 'closed', "completeAction writes status 'closed'");
  ok(sbCalls[0].payload.completed_by === 'u1' && sbCalls[0].payload.completed_note === 'done well' && !!sbCalls[0].payload.completed_at, 'completeAction sets completed_by/note/at');
  ok(sbCalls[0].sel === 'id', 'completeAction selects id (refusal check)');
  ok(events.length === 1 && events[0].eventType === 'complete' && events[0].itemType === 'action', 'completeAction logs action/complete event');

  // 2. completeAction — refusal (zero rows) throws, no event
  reset(ZERO_ROWS);
  let threw = false; try { await verbs.completeAction({ id: 'a1' }, { actorId: 'u1', orgId: 'o1' }); } catch (e) { threw = true; }
  ok(threw, 'completeAction throws on zero-row (policy) refusal');
  ok(events.length === 0, 'completeAction logs no event on refusal');

  // 3. completeAction — DB error throws
  reset(ERR);
  threw = false; try { await verbs.completeAction({ id: 'a1' }, { actorId: 'u1', orgId: 'o1' }); } catch (e) { threw = true; }
  ok(threw, 'completeAction throws on DB error');

  // 4. reopenAction
  reset(OK_ROWS);
  await verbs.reopenAction({ id: 'a1' }, { actorId: 'u1', orgId: 'o1' });
  ok(sbCalls[0].payload.status === 'open' && sbCalls[0].payload.completed_at === null && sbCalls[0].payload.completed_by === null, 'reopenAction clears completion');
  ok(events[0].eventType === 'reopen', 'reopenAction logs reopen');

  // 5. acknowledgeFlag
  reset(OK_ROWS);
  await verbs.acknowledgeFlag({ id: 'f1', to_department: 'design' }, { actorId: 'u1', orgId: 'o1', note: 'seen' });
  ok(sbCalls[0].table === 'meeting_handoffs' && sbCalls[0].payload.status === 'acknowledged', "acknowledgeFlag writes 'acknowledged'");
  ok(sbCalls[0].payload.acknowledged_note === 'seen' && sbCalls[0].payload.acknowledged_by === 'u1', 'acknowledgeFlag sets note/by');
  ok(events[0].itemType === 'flag' && events[0].eventType === 'acknowledge', 'acknowledgeFlag logs flag/acknowledge');

  // 6. acknowledgeFlag refusal throws
  reset(ZERO_ROWS);
  threw = false; try { await verbs.acknowledgeFlag({ id: 'f1', to_department: 'design' }, { actorId: 'u1', orgId: 'o1' }); } catch (e) { threw = true; }
  ok(threw, 'acknowledgeFlag throws on refusal');

  // 7. convertFlag — creates action, links, canonical 'converted'
  reset(OK_ROWS);
  const rid = await verbs.convertFlag({ id: 'f1', project_id: 'p1', to_department: 'design' }, { actorId: 'u1', orgId: 'o1', action: { description: 'do it', owner_user_id: 'u2' }, ownerId: 'u2', ownerName: 'Zed' });
  ok(sbCalls[0].table === 'actions' && sbCalls[0].op === 'insert', 'convertFlag inserts the action first');
  ok(sbCalls[0].payload.status === 'open' && sbCalls[0].payload.source_type === 'flag' && sbCalls[0].payload.source_ref === 'f1' && sbCalls[0].payload.description === 'do it', 'convertFlag action carries source + fields');
  ok(sbCalls[1].table === 'meeting_handoffs' && sbCalls[1].payload.status === 'converted' && sbCalls[1].payload.resulting_action_id === 'new-id', "convertFlag settles flag 'converted' + links action");
  ok(rid === 'new-id', 'convertFlag returns the action id');
  ok(events.some(e => e.itemType === 'action' && e.eventType === 'raised') && events.some(e => e.itemType === 'flag' && e.eventType === 'convert'), 'convertFlag logs action/raised + flag/convert');

  // 8. convertFlag — link a pre-created action (meeting AddActionModal flow): no insert
  reset(OK_ROWS);
  await verbs.convertFlag({ id: 'f1', to_department: 'design' }, { actorId: 'u1', orgId: 'o1', resultingActionId: 'A9' });
  ok(!sbCalls.some(c => c.op === 'insert'), 'convertFlag(resultingActionId) does not insert a new action');
  ok(sbCalls[0].table === 'meeting_handoffs' && sbCalls[0].payload.resulting_action_id === 'A9', 'convertFlag links the given action id');
  ok(!events.some(e => e.eventType === 'raised') && events.some(e => e.eventType === 'convert'), 'convertFlag(link) logs convert only');

  // 9. resolveQuery — parent action gets an unblock event
  reset(OK_ROWS);
  await verbs.resolveQuery({ id: 'q1', parent_type: 'action', parent_id: 'a1' }, { actorId: 'u1', orgId: 'o1', note: 'answered' });
  ok(sbCalls[0].table === 'queries' && sbCalls[0].payload.status === 'resolved', "resolveQuery writes 'resolved'");
  ok(events.some(e => e.itemType === 'query' && e.eventType === 'resolve') && events.some(e => e.itemType === 'action' && e.eventType === 'resolve'), 'resolveQuery logs query + parent-action resolve');

  // 10. answerQuery — message + event
  reset(OK_ROWS);
  await verbs.answerQuery({ id: 'q1' }, { actorId: 'u1', orgId: 'o1', body: 'here you go', isAnswer: true, returnTo: 'u2', returnToName: 'Ana' });
  ok(sbCalls[0].table === 'query_messages' && sbCalls[0].op === 'insert' && sbCalls[0].payload.body === 'here you go', 'answerQuery inserts the message');
  ok(events[0].eventType === 'answer', 'answerQuery logs answer');

  // 11. escalateQuery
  reset(OK_ROWS);
  await verbs.escalateQuery({ id: 'q1' }, { actorId: 'u1', orgId: 'o1', target: 'u3', targetName: 'Lead', ballName: 'Ana' });
  ok(sbCalls[0].table === 'queries' && sbCalls[0].payload.escalated_to === 'u3', 'escalateQuery sets escalated_to');
  ok(events[0].eventType === 'escalate', 'escalateQuery logs escalate');

  // 12. markDateMet
  reset(OK_ROWS);
  await verbs.markDateMet({ id: 'd1' }, { actorId: 'u1', orgId: 'o1', note: 'submitted' });
  ok(sbCalls[0].table === 'project_key_dates' && sbCalls[0].payload.completed === true && sbCalls[0].payload.completion_note === 'submitted', 'markDateMet sets completed + note');
  ok(events[0].itemType === 'date' && events[0].eventType === 'met', 'markDateMet logs date/met');

  // 13. moveDate — writes change_* context, NO item_event (programme_revisions is the audit)
  reset(OK_ROWS);
  await verbs.moveDate({ id: 'd1' }, { actorId: 'u1', orgId: 'o1', toDate: '2026-09-01', reason: 'slip', meetingId: 'm1', causeFlagId: 'f2' });
  ok(sbCalls[0].payload.target_date === '2026-09-01' && sbCalls[0].payload.change_reason === 'slip' && sbCalls[0].payload.change_meeting_id === 'm1' && sbCalls[0].payload.change_cause_flag_id === 'f2', 'moveDate carries target + change_* context');
  ok(sbCalls[0].payload.change_cause_action_id === null, 'moveDate nulls unset cause');
  ok(events.length === 0, 'moveDate logs no item_event (revision trigger is the audit)');

  // 14. moveDate refusal throws
  reset(ZERO_ROWS);
  threw = false; try { await verbs.moveDate({ id: 'd1' }, { actorId: 'u1', orgId: 'o1', toDate: '2026-09-01' }); } catch (e) { threw = true; }
  ok(threw, 'moveDate throws on refusal');

  console.log((fail === 0 ? 'ALL PASS' : 'FAILURES') + ' — ' + pass + ' passed, ' + fail + ' failed');
  process.exit(fail === 0 ? 0 : 1);
})();
