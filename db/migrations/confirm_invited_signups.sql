-- =============================================================================
-- Invited sign-ups are confirmed without an email round-trip
-- Applied to tpxabhqsjngalilbznhz on 2026-07-29.
-- =============================================================================
-- ⚠ DEV-MODE DECISION, taken knowingly (Tom, 2026-07-29). Add Person creates a
-- Supabase auth account from the browser, but the project sends a confirmation
-- email whose link points at localhost, so the account could never be used —
-- and the people being created are fictional, with no reachable inbox.
--
-- This confirms an account **only** when it claims an unclaimed org_invites row.
-- The invite is the authorisation: a senior vouched for that address, and Add
-- Person consumes the invite inside the same request, so the window in which
-- anyone else could sign up against it is negligible.
--
-- It is deliberately narrower than the alternative — switching "Confirm email"
-- off for the whole project in the Supabase dashboard — because a self-service
-- sign-up with no invite still has to confirm normally.
--
-- BEFORE REAL PEOPLE, decide which way to go:
--   keep it   — an invited colleague never verifies their address. Reasonable
--               if invites only ever originate from a senior inside the app.
--   drop it   — instead fix Site URL + the redirect allow-list in the Supabase
--               dashboard so the confirmation link resolves to the live app.
--
-- The change is the single UPDATE marked below, inside the existing
-- handle_new_auth_user trigger function; everything else is as it was.

create or replace function public.handle_new_auth_user()
 returns trigger language plpgsql security definer set search_path to 'public'
as $function$
DECLARE
    inv  record;
    meta jsonb := COALESCE(NEW.raw_user_meta_data, '{}'::jsonb);
BEGIN
    BEGIN
        SELECT * INTO inv FROM public.org_invites
            WHERE lower(email) = lower(NEW.email) AND claimed_at IS NULL
            ORDER BY created_at LIMIT 1;

        IF FOUND THEN
            INSERT INTO public.app_users
                (id, org_id, email, display_name, initials, role, department, active)
            VALUES (
                NEW.id, inv.org_id, NEW.email,
                COALESCE(NULLIF(inv.display_name, ''), NULLIF(meta->>'display_name', ''), split_part(NEW.email, '@', 1)),
                COALESCE(NULLIF(inv.initials, ''), NULLIF(meta->>'initials', ''), upper(left(split_part(NEW.email, '@', 1), 2))),
                inv.role, inv.department, true
            );

            UPDATE public.org_invites
                SET claimed_at = now(), claimed_by = NEW.id WHERE id = inv.id;

            -- ⬇ THE DEV-MODE LINE. Safe as an UPDATE from an AFTER INSERT
            -- trigger: this fires on INSERT only, so it cannot re-enter itself.
            UPDATE auth.users
                SET email_confirmed_at = COALESCE(email_confirmed_at, now())
                WHERE id = NEW.id;

            INSERT INTO public.org_audit_log
                (org_id, actor_user_id, target_user_id, event, detail)
            VALUES (inv.org_id, NEW.id, NEW.id, 'user-joined',
                jsonb_build_object('via', 'invite', 'invited_by', inv.invited_by, 'role', inv.role));
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'handle_new_auth_user failed for %: %', NEW.email, SQLERRM;
    END;
    RETURN NEW;
END;
$function$;

revoke execute on function public.handle_new_auth_user() from public, anon, authenticated;

-- =============================================================================
-- Verification recorded 2026-07-29
-- =============================================================================
-- The signup HTTP endpoint is not reachable from the dev sandbox, so the
-- trigger was exercised directly: an org_invites row plus the exact auth.users
-- insert GoTrue performs, inside a self-aborting block.
--
--   auth account confirmed without an email ... t
--   app_users row created .................... t  (Probe Person, technical, contributor)
--   invite claimed ........................... t
--
-- Rolled back clean: 0 probe rows in auth.users, app_users or org_invites.
