-- P1.21: consent-based automatic guardian reports.
-- Run after 20260727000100_p1_20_portal_supervision.sql.

BEGIN;

CREATE TABLE IF NOT EXISTS public.guardian_report_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL UNIQUE
    REFERENCES public.families(id) ON DELETE CASCADE,
  center_id UUID NOT NULL REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID NOT NULL REFERENCES public.halaqat(id) ON DELETE CASCADE,
  frequency TEXT NOT NULL DEFAULT 'monthly'
    CHECK (frequency IN ('weekly', 'monthly')),
  delivery_channel TEXT NOT NULL DEFAULT 'portal'
    CHECK (delivery_channel IN ('portal', 'webhook')),
  enabled BOOLEAN NOT NULL DEFAULT true,
  consent_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  next_run_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.guardian_report_deliveries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID NOT NULL
    REFERENCES public.guardian_report_subscriptions(id) ON DELETE CASCADE,
  family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
  center_id UUID NOT NULL REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID NOT NULL REFERENCES public.halaqat(id) ON DELETE CASCADE,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  frequency TEXT NOT NULL CHECK (frequency IN ('weekly', 'monthly')),
  delivery_channel TEXT NOT NULL
    CHECK (delivery_channel IN ('portal', 'webhook')),
  report_payload JSONB NOT NULL,
  published_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  external_status TEXT NOT NULL DEFAULT 'not_requested'
    CHECK (external_status IN (
      'not_requested', 'pending', 'sending', 'sent', 'failed'
    )),
  attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  next_attempt_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  provider_reference TEXT,
  failure_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (period_end >= period_start),
  UNIQUE (subscription_id, period_start, period_end)
);

CREATE INDEX IF NOT EXISTS idx_guardian_report_subscriptions_due
  ON public.guardian_report_subscriptions(next_run_at)
  WHERE enabled;
CREATE INDEX IF NOT EXISTS idx_guardian_report_deliveries_family
  ON public.guardian_report_deliveries(family_id, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_guardian_report_deliveries_external
  ON public.guardian_report_deliveries(external_status, next_attempt_at)
  WHERE external_status IN ('pending', 'sending', 'failed');

CREATE OR REPLACE FUNCTION public.validate_guardian_report_subscription()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  target_family public.families%ROWTYPE;
BEGIN
  SELECT * INTO target_family
  FROM public.families
  WHERE id = NEW.family_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'family_not_found';
  END IF;

  NEW.center_id := target_family.center_id;
  NEW.halaqa_id := target_family.halaqa_id;
  NEW.updated_at := now();
  IF TG_OP = 'INSERT' THEN
    NEW.created_by := auth.uid();
  END IF;
  IF NEW.enabled AND NOT EXISTS (
    SELECT 1
    FROM public.students AS student
    WHERE student.family_id = NEW.family_id
      AND student.status = 'active'
  ) THEN
    RAISE EXCEPTION 'family_has_no_active_students';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS validate_guardian_report_subscription
  ON public.guardian_report_subscriptions;
CREATE TRIGGER validate_guardian_report_subscription
  BEFORE INSERT OR UPDATE ON public.guardian_report_subscriptions
  FOR EACH ROW EXECUTE FUNCTION public.validate_guardian_report_subscription();

ALTER TABLE public.guardian_report_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guardian_report_deliveries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS guardian_report_subscriptions_select
  ON public.guardian_report_subscriptions;
CREATE POLICY guardian_report_subscriptions_select
  ON public.guardian_report_subscriptions FOR SELECT TO authenticated
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id));

DROP POLICY IF EXISTS guardian_report_subscriptions_insert
  ON public.guardian_report_subscriptions;
CREATE POLICY guardian_report_subscriptions_insert
  ON public.guardian_report_subscriptions FOR INSERT TO authenticated
  WITH CHECK (
    created_by = auth.uid()
    AND public.current_user_can_access_halaqa(center_id, halaqa_id)
  );

DROP POLICY IF EXISTS guardian_report_subscriptions_update
  ON public.guardian_report_subscriptions;
CREATE POLICY guardian_report_subscriptions_update
  ON public.guardian_report_subscriptions FOR UPDATE TO authenticated
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id))
  WITH CHECK (public.current_user_can_access_halaqa(center_id, halaqa_id));

DROP POLICY IF EXISTS guardian_report_subscriptions_delete
  ON public.guardian_report_subscriptions;
CREATE POLICY guardian_report_subscriptions_delete
  ON public.guardian_report_subscriptions FOR DELETE TO authenticated
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id));

DROP POLICY IF EXISTS guardian_report_deliveries_select
  ON public.guardian_report_deliveries;
CREATE POLICY guardian_report_deliveries_select
  ON public.guardian_report_deliveries FOR SELECT TO authenticated
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id));

REVOKE ALL ON public.guardian_report_subscriptions
  FROM PUBLIC, anon;
REVOKE ALL ON public.guardian_report_deliveries
  FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.guardian_report_subscriptions TO authenticated;
GRANT SELECT ON public.guardian_report_deliveries TO authenticated;

CREATE OR REPLACE FUNCTION public.get_guardian_report_subscription(
  p_family_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  target_family public.families%ROWTYPE;
  subscription public.guardian_report_subscriptions%ROWTYPE;
BEGIN
  SELECT * INTO target_family
  FROM public.families
  WHERE id = p_family_id;

  IF NOT FOUND OR NOT public.current_user_can_access_halaqa(
    target_family.center_id,
    target_family.halaqa_id
  ) THEN
    RAISE EXCEPTION 'family_not_accessible';
  END IF;

  SELECT * INTO subscription
  FROM public.guardian_report_subscriptions
  WHERE family_id = target_family.id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'configured', false,
      'enabled', false,
      'frequency', 'monthly',
      'delivery_channel', 'portal',
      'primary_guardian_available', EXISTS (
        SELECT 1 FROM public.family_guardians AS guardian
        WHERE guardian.family_id = target_family.id
          AND guardian.is_primary
          AND (
            NULLIF(BTRIM(guardian.phone), '') IS NOT NULL
            OR NULLIF(BTRIM(guardian.email), '') IS NOT NULL
          )
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'configured', true,
    'enabled', subscription.enabled,
    'frequency', subscription.frequency,
    'delivery_channel', subscription.delivery_channel,
    'consent_at', subscription.consent_at,
    'next_run_at', subscription.next_run_at,
    'last_published_at', (
      SELECT MAX(delivery.published_at)
      FROM public.guardian_report_deliveries AS delivery
      WHERE delivery.subscription_id = subscription.id
    ),
    'primary_guardian_available', EXISTS (
      SELECT 1 FROM public.family_guardians AS guardian
      WHERE guardian.family_id = target_family.id
        AND guardian.is_primary
        AND (
          NULLIF(BTRIM(guardian.phone), '') IS NOT NULL
          OR NULLIF(BTRIM(guardian.email), '') IS NOT NULL
        )
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.set_guardian_report_subscription(
  p_family_id UUID,
  p_enabled BOOLEAN,
  p_frequency TEXT,
  p_delivery_channel TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  target_family public.families%ROWTYPE;
BEGIN
  SELECT * INTO target_family
  FROM public.families
  WHERE id = p_family_id;

  IF NOT FOUND OR NOT public.current_user_can_access_halaqa(
    target_family.center_id,
    target_family.halaqa_id
  ) THEN
    RAISE EXCEPTION 'family_not_accessible';
  END IF;
  IF p_frequency NOT IN ('weekly', 'monthly') THEN
    RAISE EXCEPTION 'invalid_report_frequency';
  END IF;
  IF p_delivery_channel NOT IN ('portal', 'webhook') THEN
    RAISE EXCEPTION 'invalid_delivery_channel';
  END IF;
  IF p_enabled AND NOT EXISTS (
    SELECT 1 FROM public.students AS student
    WHERE student.family_id = target_family.id
      AND student.status = 'active'
  ) THEN
    RAISE EXCEPTION 'family_has_no_active_students';
  END IF;
  IF p_enabled AND p_delivery_channel = 'webhook' AND NOT EXISTS (
    SELECT 1 FROM public.family_guardians AS guardian
    WHERE guardian.family_id = target_family.id
      AND guardian.is_primary
      AND (
        NULLIF(BTRIM(guardian.phone), '') IS NOT NULL
        OR NULLIF(BTRIM(guardian.email), '') IS NOT NULL
      )
  ) THEN
    RAISE EXCEPTION 'primary_guardian_contact_required';
  END IF;

  INSERT INTO public.guardian_report_subscriptions (
    family_id,
    center_id,
    halaqa_id,
    frequency,
    delivery_channel,
    enabled,
    consent_at,
    next_run_at,
    created_by
  ) VALUES (
    target_family.id,
    target_family.center_id,
    target_family.halaqa_id,
    p_frequency,
    p_delivery_channel,
    p_enabled,
    now(),
    CASE WHEN p_enabled THEN now() ELSE now() + interval '100 years' END,
    auth.uid()
  )
  ON CONFLICT (family_id) DO UPDATE SET
    frequency = EXCLUDED.frequency,
    delivery_channel = EXCLUDED.delivery_channel,
    enabled = EXCLUDED.enabled,
    consent_at = CASE
      WHEN EXCLUDED.enabled THEN now()
      ELSE public.guardian_report_subscriptions.consent_at
    END,
    next_run_at = CASE
      WHEN EXCLUDED.enabled
        AND (
          NOT public.guardian_report_subscriptions.enabled
          OR public.guardian_report_subscriptions.frequency
            IS DISTINCT FROM EXCLUDED.frequency
        )
      THEN now()
      WHEN NOT EXCLUDED.enabled THEN now() + interval '100 years'
      ELSE public.guardian_report_subscriptions.next_run_at
    END,
    updated_at = now();

  RETURN public.get_guardian_report_subscription(target_family.id);
END;
$$;

CREATE OR REPLACE FUNCTION public.publish_due_guardian_reports(
  p_limit INTEGER DEFAULT 100
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  subscription public.guardian_report_subscriptions%ROWTYPE;
  report_days INTEGER;
  period_start_value DATE;
  period_end_value DATE := current_date;
  family_payload JSONB;
  student_payload JSONB;
  published_count INTEGER := 0;
BEGIN
  FOR subscription IN
    SELECT *
    FROM public.guardian_report_subscriptions
    WHERE enabled
      AND next_run_at <= now()
    ORDER BY next_run_at, id
    FOR UPDATE SKIP LOCKED
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 100), 500))
  LOOP
    report_days := CASE
      WHEN subscription.frequency = 'weekly' THEN 7
      ELSE 30
    END;
    period_start_value := period_end_value - (report_days - 1);

    SELECT jsonb_build_object(
      'name', family_row.name,
      'family_code', family_row.family_code,
      'primary_guardian', (
        SELECT jsonb_build_object(
          'name', guardian.name,
          'relationship', guardian.relationship,
          'phone', guardian.phone,
          'email', guardian.email
        )
        FROM public.family_guardians AS guardian
        WHERE guardian.family_id = family_row.id
          AND guardian.is_primary
        LIMIT 1
      )
    ) INTO family_payload
    FROM public.families AS family_row
    WHERE family_row.id = subscription.family_id;

    SELECT COALESCE(
      jsonb_agg(
        (
          public.build_student_portal_dashboard(
            student.id,
            report_days,
            now() + interval '1 hour'
          ) - 'session_expires_at'
        )
        ORDER BY student.name, student.id
      ),
      '[]'::jsonb
    ) INTO student_payload
    FROM public.students AS student
    WHERE student.family_id = subscription.family_id
      AND student.status = 'active';

    INSERT INTO public.guardian_report_deliveries (
      subscription_id,
      family_id,
      center_id,
      halaqa_id,
      period_start,
      period_end,
      frequency,
      delivery_channel,
      report_payload,
      external_status,
      next_attempt_at
    ) VALUES (
      subscription.id,
      subscription.family_id,
      subscription.center_id,
      subscription.halaqa_id,
      period_start_value,
      period_end_value,
      subscription.frequency,
      subscription.delivery_channel,
      jsonb_build_object(
        'schema_version', 1,
        'generated_at', now(),
        'period_start', period_start_value,
        'period_end', period_end_value,
        'frequency', subscription.frequency,
        'family', family_payload,
        'students', student_payload
      ),
      CASE
        WHEN subscription.delivery_channel = 'webhook' THEN 'pending'
        ELSE 'not_requested'
      END,
      CASE
        WHEN subscription.delivery_channel = 'webhook' THEN now()
        ELSE NULL
      END
    )
    ON CONFLICT (subscription_id, period_start, period_end) DO NOTHING;

    IF FOUND THEN
      published_count := published_count + 1;
    END IF;

    UPDATE public.guardian_report_subscriptions
    SET next_run_at = CASE
          WHEN frequency = 'weekly' THEN now() + interval '7 days'
          ELSE now() + interval '1 month'
        END,
        updated_at = now()
    WHERE id = subscription.id;
  END LOOP;

  RETURN published_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.claim_guardian_report_deliveries(
  p_limit INTEGER DEFAULT 25
)
RETURNS SETOF public.guardian_report_deliveries
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  RETURN QUERY
  WITH candidates AS (
    SELECT delivery.id
    FROM public.guardian_report_deliveries AS delivery
    WHERE (
        delivery.external_status IN ('pending', 'failed')
        OR (
          delivery.external_status = 'sending'
          AND delivery.updated_at < now() - interval '15 minutes'
        )
      )
      AND COALESCE(delivery.next_attempt_at, now()) <= now()
      AND delivery.attempt_count < 5
    ORDER BY delivery.created_at, delivery.id
    FOR UPDATE SKIP LOCKED
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 25), 100))
  )
  UPDATE public.guardian_report_deliveries AS delivery
  SET external_status = 'sending',
      attempt_count = delivery.attempt_count + 1,
      failure_reason = NULL,
      updated_at = now()
  FROM candidates
  WHERE delivery.id = candidates.id
  RETURNING delivery.*;
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_guardian_report_delivery(
  p_delivery_id UUID,
  p_succeeded BOOLEAN,
  p_provider_reference TEXT DEFAULT NULL,
  p_failure_reason TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.guardian_report_deliveries
  SET external_status = CASE WHEN p_succeeded THEN 'sent' ELSE 'failed' END,
      delivered_at = CASE WHEN p_succeeded THEN now() ELSE delivered_at END,
      provider_reference = CASE
        WHEN p_succeeded THEN NULLIF(BTRIM(p_provider_reference), '')
        ELSE provider_reference
      END,
      failure_reason = CASE
        WHEN p_succeeded THEN NULL
        ELSE LEFT(COALESCE(NULLIF(BTRIM(p_failure_reason), ''), 'provider_failed'), 500)
      END,
      next_attempt_at = CASE
        WHEN p_succeeded OR attempt_count >= 5 THEN NULL
        ELSE now() + interval '15 minutes'
      END,
      updated_at = now()
  WHERE id = p_delivery_id
    AND external_status = 'sending';
END;
$$;

CREATE OR REPLACE FUNCTION public.family_portal_get_automatic_reports(
  p_session_token TEXT,
  p_limit INTEGER DEFAULT 12
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  active_session public.family_portal_sessions%ROWTYPE;
BEGIN
  IF p_session_token IS NULL OR p_session_token !~ '^[a-f0-9]{64}$' THEN
    RAISE EXCEPTION 'invalid_session';
  END IF;

  SELECT * INTO active_session
  FROM public.family_portal_sessions
  WHERE token_hash = digest(p_session_token, 'sha256')
    AND revoked_at IS NULL
    AND expires_at > now();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_session';
  END IF;

  RETURN COALESCE((
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', delivery.id,
        'period_start', delivery.period_start,
        'period_end', delivery.period_end,
        'frequency', delivery.frequency,
        'published_at', delivery.published_at,
        'external_status', delivery.external_status,
        'report', delivery.report_payload
      )
      ORDER BY delivery.published_at DESC, delivery.id DESC
    )
    FROM (
      SELECT *
      FROM public.guardian_report_deliveries
      WHERE family_id = active_session.family_id
      ORDER BY published_at DESC, id DESC
      LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 12), 24))
    ) AS delivery
  ), '[]'::jsonb);
END;
$$;

REVOKE ALL ON FUNCTION public.validate_guardian_report_subscription()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_guardian_report_subscription(UUID)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_guardian_report_subscription(
  UUID, BOOLEAN, TEXT, TEXT
) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.publish_due_guardian_reports(INTEGER)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.claim_guardian_report_deliveries(INTEGER)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.complete_guardian_report_delivery(
  UUID, BOOLEAN, TEXT, TEXT
) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.family_portal_get_automatic_reports(
  TEXT, INTEGER
) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.get_guardian_report_subscription(UUID)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_guardian_report_subscription(
  UUID, BOOLEAN, TEXT, TEXT
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.publish_due_guardian_reports(INTEGER)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.claim_guardian_report_deliveries(INTEGER)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_guardian_report_delivery(
  UUID, BOOLEAN, TEXT, TEXT
) TO service_role;
GRANT EXECUTE ON FUNCTION public.family_portal_get_automatic_reports(
  TEXT, INTEGER
) TO service_role;

-- If Supabase Cron is already enabled, publish portal reports every 15 minutes.
-- External webhook delivery is performed by the guardian-report-worker function.
DO $$
DECLARE
  job_exists BOOLEAN := false;
  scheduled_job_id BIGINT;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    EXECUTE
      'SELECT EXISTS (
        SELECT 1 FROM cron.job
        WHERE jobname = $1
      )'
      INTO job_exists
      USING 'halaqah-publish-guardian-reports';
    IF NOT job_exists THEN
      EXECUTE 'SELECT cron.schedule($1, $2, $3)'
        INTO scheduled_job_id
        USING
          'halaqah-publish-guardian-reports',
          '*/15 * * * *',
          'SELECT public.publish_due_guardian_reports(100);';
    END IF;
  END IF;
END;
$$;

COMMIT;
