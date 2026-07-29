-- =============================================================================
-- Forced password reset for people added from the Organisation tab
-- Applied to tpxabhqsjngalilbznhz on 2026-07-29.
-- =============================================================================
-- Adding a person now creates their Supabase auth account there and then, with
-- a generated temporary password the senior passes on. This flag is what makes
-- them replace it: App renders the ForcePasswordReset screen instead of the
-- Dashboard while it is true, so the app is unreachable until they do.

alter table public.app_users
  add column must_reset_password boolean not null default false;

-- Deliberately NOT added to enforce_app_user_field_guard's protected list.
-- The person clearing this flag is exactly the person who has just reset their
-- own password, so they must be able to clear it themselves. It is an
-- onboarding prompt, not a security boundary — the boundary is the password.
--
-- How the account gets created, for the record: the app inserts an org_invites
-- row FIRST (the trg_handle_new_auth_user trigger on auth.users reads it to
-- build the app_users row and claim the invite), then calls auth.signUp on a
-- SECOND, non-persisting Supabase client. That second client matters — signUp
-- replaces the CURRENT session, so on the normal client a senior would be
-- signed out and signed back in as the person they had just added. The invite
-- is rolled back if the signup fails, so a retry does not trip the trigger twice.
