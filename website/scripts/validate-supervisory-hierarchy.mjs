import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "../..");
const read = (path) => readFileSync(resolve(root, path), "utf8");

function requireAll(source, fragments, label) {
  for (const fragment of fragments) {
    if (!source.includes(fragment)) {
      throw new Error(`${label} is missing: ${fragment}`);
    }
  }
}

const migration = read("website/supabase/migrations/20260714000500_p7_supervisory_hierarchy.sql");
requireAll(migration, [
  "CREATE TABLE IF NOT EXISTS public.supervisor_members",
  "role IN ('owner', 'admin', 'analyst')",
  "uq_supervisor_active_owner",
  "CREATE TABLE IF NOT EXISTS public.supervisor_center_invitations",
  "digest(raw_token, 'sha256')",
  "CREATE TABLE IF NOT EXISTS public.supervisor_member_invitations",
  "lower(invitation.email) <> account_email",
  "CREATE TABLE IF NOT EXISTS public.supervisor_audit_events",
  "current_user_can_access_supervisor",
  "current_user_can_manage_supervisor",
  "create_supervisor_center_invitation",
  "accept_supervisor_center_invitation",
  "create_supervisor_member_invitation",
  "accept_supervisor_member_invitation",
  "unlink_center_from_supervisor",
  "get_supervisor_dashboard",
  "p_end_date - p_start_date > 366",
  "FROM PUBLIC, anon, authenticated",
  "GRANT INSERT (name, address, type, owner_id)",
  "GRANT UPDATE (name, address, type)",
  "REVOKE INSERT, UPDATE, DELETE ON public.supervisors",
], "P7.3 migration");

const centerAdminStart = migration.indexOf(
  "CREATE OR REPLACE FUNCTION public.current_user_is_center_admin",
);
const centerAdminEnd = migration.indexOf(
  "CREATE OR REPLACE FUNCTION public.current_user_can_access_halaqa",
  centerAdminStart,
);
const centerAdminHelper = migration.slice(centerAdminStart, centerAdminEnd);
if (centerAdminHelper.includes("'analyst'")) {
  throw new Error("Analyst must not inherit center administrator write access.");
}

const store = read("website/src/store/useStore.ts");
requireAll(store, [
  ".rpc('get_my_supervisors')",
  ".rpc('create_supervisor_organization'",
  "'accept_supervisor_center_invitation'",
  "'accept_supervisor_member_invitation'",
], "Web store");
if (/Math\.random\(\).*HAL-|\.eq\(['"]code['"],\s*code\)/s.test(store)) {
  throw new Error("Legacy permanent or weak supervisory joining code is still active.");
}

const page = read("website/src/app/supervision/page.tsx");
requireAll(page, [
  "لوحة الجهة الإشرافية",
  "create_supervisor_center_invitation",
  "create_supervisor_member_invitation",
  "update_supervisor_member",
  "unlink_center_from_supervisor",
  "get_supervisor_dashboard",
  "طباعة / PDF",
  "أداء المراكز",
  "فريق الإشراف",
], "Supervisory dashboard");

const layout = read("website/src/components/DashboardLayout.tsx");
requireAll(layout, [
  'pathname.startsWith("/supervision")',
  'label: "لوحة الإشراف"',
], "Navigation layout");

console.log(
  "P7.3 supervisory hierarchy contract passed: scoped roles, one-time invitations, audit trail, aggregate dashboard, and RTL printing.",
);
