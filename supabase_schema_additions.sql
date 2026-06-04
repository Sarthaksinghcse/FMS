-- Predictive Maintenance Alerts
CREATE TABLE IF NOT EXISTS public.predictive_alerts (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id        UUID REFERENCES public.vehicles(id) ON DELETE CASCADE,
    risk_level        TEXT NOT NULL CHECK (risk_level IN ('low','medium','high','critical')),
    risk_score        FLOAT NOT NULL DEFAULT 0,
    triggered_reasons TEXT[],
    suggested_action  TEXT,
    llm_explanation   TEXT,
    created_at        TIMESTAMPTZ DEFAULT now(),
    resolved_at       TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS predictive_alerts_vehicle_id_idx ON public.predictive_alerts(vehicle_id);
CREATE INDEX IF NOT EXISTS predictive_alerts_risk_level_idx ON public.predictive_alerts(risk_level);
ALTER TABLE public.predictive_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "predictive_alerts_select" ON public.predictive_alerts;
CREATE POLICY "predictive_alerts_select" ON public.predictive_alerts FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "predictive_alerts_modify" ON public.predictive_alerts;
CREATE POLICY "predictive_alerts_modify" ON public.predictive_alerts FOR ALL USING (public.current_user_role() = 'fleet_manager');

-- Vehicle Health Scores (one row per vehicle, upserted on each analysis)
CREATE TABLE IF NOT EXISTS public.vehicle_health_scores (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id   UUID REFERENCES public.vehicles(id) ON DELETE CASCADE UNIQUE,
    health_score INT NOT NULL CHECK (health_score BETWEEN 0 AND 100),
    health_grade TEXT NOT NULL CHECK (health_grade IN ('excellent','good','fair','poor','critical')),
    issue_flags  JSONB,
    suggested_tasks TEXT[],
    llm_summary  TEXT,
    analyzed_at  TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS vehicle_health_scores_health_score_idx ON public.vehicle_health_scores(health_score);
ALTER TABLE public.vehicle_health_scores ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "health_scores_select" ON public.vehicle_health_scores;
CREATE POLICY "health_scores_select" ON public.vehicle_health_scores FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "health_scores_modify" ON public.vehicle_health_scores;
CREATE POLICY "health_scores_modify" ON public.vehicle_health_scores FOR ALL USING (public.current_user_role() IN ('fleet_manager','maintenance'));

-- AI Fuel Optimization Insights
CREATE TABLE IF NOT EXISTS public.ai_fuel_insights (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    insights_text     TEXT NOT NULL,
    high_consumers    JSONB,
    estimated_savings FLOAT,
    generated_at      TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.ai_fuel_insights ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "fuel_insights_select" ON public.ai_fuel_insights;
CREATE POLICY "fuel_insights_select" ON public.ai_fuel_insights FOR SELECT USING (TRUE);

-- AI Analytics Reports
CREATE TABLE IF NOT EXISTS public.ai_analytics_reports (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_text     TEXT NOT NULL,
    fleet_snapshot  JSONB,
    generated_at    TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.ai_analytics_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "reports_select" ON public.ai_analytics_reports;
CREATE POLICY "reports_select" ON public.ai_analytics_reports FOR SELECT USING (TRUE);

-- Spare Parts Forecasts
CREATE TABLE IF NOT EXISTS public.spare_parts_forecasts (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    forecasts    JSONB NOT NULL,
    generated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.spare_parts_forecasts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "forecasts_select" ON public.spare_parts_forecasts;
CREATE POLICY "forecasts_select" ON public.spare_parts_forecasts FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "forecasts_modify" ON public.spare_parts_forecasts;
CREATE POLICY "forecasts_modify" ON public.spare_parts_forecasts FOR ALL USING (public.current_user_role() IN ('fleet_manager','maintenance'));

-- Fuel Logs (if not already in schema)
CREATE TABLE IF NOT EXISTS public.fuel_logs (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id   UUID REFERENCES public.users(id),
    vehicle_id  UUID REFERENCES public.vehicles(id),
    trip_id     UUID REFERENCES public.trips(id),
    fuel_type   TEXT NOT NULL,
    litres      FLOAT NOT NULL,
    amount_paid FLOAT NOT NULL,
    odometer    FLOAT,
    receipt_url TEXT,
    notes       TEXT,
    created_at  TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.fuel_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "fuel_logs_select" ON public.fuel_logs;
CREATE POLICY "fuel_logs_select" ON public.fuel_logs FOR SELECT USING (TRUE);

-- Add estimated_cost column to work_orders table
ALTER TABLE public.work_orders ADD COLUMN IF NOT EXISTS estimated_cost NUMERIC(10, 2);
