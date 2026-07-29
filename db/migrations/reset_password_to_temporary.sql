-- =============================================================================
-- Senior-only "reset this person back to the temporary password"
-- Applied to tpxabhqsjngalilbznhz on 2026-07-29. Verification at the bottom.
-- =============================================================================
-- Lets a senior put a colleague's login back to the known temporary value so
-- they can be signed in as again. The practical need is fictional people during
-- build: the forced first-sign-in reset otherwise leaves each new person with a
-- password nobody recorded.
--
-- ⚠ This is an impersonation-capable primitive, so three things are deliberate:
--
--  1. The new password is FIXED SERVER-SIDE. The function takes no password
--     argument, so it can never be used to set an arbitrary one — it is "reset
--     to the known temporary value", not "set anyone's password".
--  2. The authorisation check is INSIDE the function, because it must be
--     EXECUTE-able by `authenticated` to be callable over RPC at all. Only an
--     active senior in the same organisation as the target gets through; anon
--     has no auth.uid() and fails immediately. Same accepted-exception pattern
--     as current_org_id() and user_can_see_project() — but it is the only one of
--     the three that grants a POWER rather than answering a question, hence the
--     internal check and the audit row.
--  3. It is AUDITED. Every use writes an org_audit_log row naming actor and
--     target, so it can never be done quietly.
--
-- BEFORE REAL PEOPLE: revisit. Either drop it, or keep it and be satisfied that
-- a senior being able to take over a colleague's login is acceptable and logged.

create or replace function public.reset_password_to_temporary(p_user uuid)
returns void language plpgsql security definer set search_path to 'public'
as $function$
declare
    v_actor uuid := auth.uid();
    v_org   uuid;
begin
    if v_actor is null then
        raise exception 'not signed in';
    end if;

    select t.org_id into v_org
      from public.app_users t
      join public.app_users me on me.id = v_actor
     where t.id = p_user
       and me.role = 'senior' and me.active
       and me.org_id = t.org_id;

    if v_org is null then
        raise exception 'only an active senior in the same organisation may reset a password';
    end if;

    update auth.users
       set encrypted_password = extensions.crypt('123123', extensions.gen_salt('bf')),
           updated_at = now()
     where id = p_user;

    update public.app_users set must_reset_password = true where id = p_user;

    insert into public.org_audit_log (org_id, actor_user_id, target_user_id, event, detail)
    values (v_org, v_actor, p_user, 'password-reset-to-temporary',
            jsonb_build_object('via', 'organisation chart'));
end;
$function$;

revoke execute on function public.reset_password_to_temporary(uuid) from public, anon;
grant execute on function public.reset_password_to_temporary(uuid) to authenticated;

-- =============================================================================
-- Verification recorded 2026-07-29 — behavioural, under real JWTs
-- =============================================================================
--   a contributor resetting someone else ....... blocked
--   a signed-out caller ........................ blocked
--   a senior's reset changed the stored hash ... t
--   the new hash verifies against '123123' ..... t   <- the password really works
--   forced-reset flag set on the target ........ t
--   audit rows written ......................... 1
--
-- Rolled back clean: 0 audit rows, 13 auth users / 13 app_users, nobody left
-- flagged for a forced reset.
--
-- Function ACL after: postgres | authenticated | service_role — no anon, no
-- PUBLIC, as intended.
--
-- Housekeeping done in the same batch, at Tom's request: the leftover test
-- person "Jeff Gold" (tom_staples@hotmail.com, active=false from an earlier
-- Add Person attempt) was deleted along with his invite and org_audit_log rows.
-- app_users cascades from auth.users, so removing the auth row was enough for
-- the profile. Back to 13 auth users / 13 app_users.
