-- ============================================================
--  trip_logs table — Voice Log persistence for drivers
--  Run this in your Supabase SQL Editor
-- ============================================================

-- 1. Create trip_logs table
CREATE TABLE IF NOT EXISTS public.trip_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id       UUID        NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    trip_id         UUID                 REFERENCES public.trips (id) ON DELETE SET NULL,
    transcript      TEXT        NOT NULL,
    start_location  TEXT,
    end_location    TEXT,
    start_time      TEXT,
    end_time        TEXT,
    mileage         DOUBLE PRECISION,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Indexes
CREATE INDEX IF NOT EXISTS idx_trip_logs_driver    ON public.trip_logs (driver_id);
CREATE INDEX IF NOT EXISTS idx_trip_logs_trip      ON public.trip_logs (trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_logs_created   ON public.trip_logs (created_at DESC);

-- 3. Enable Row Level Security
ALTER TABLE public.trip_logs ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies
CREATE POLICY "trip_logs_select_own" ON public.trip_logs FOR SELECT USING (
    driver_id = auth.uid() OR public.current_user_role() = 'fleet_manager'
);

CREATE POLICY "trip_logs_insert_driver" ON public.trip_logs FOR INSERT WITH CHECK (
    driver_id = auth.uid()
);

CREATE POLICY "trip_logs_delete_manager" ON public.trip_logs FOR DELETE USING (
    public.current_user_role() = 'fleet_manager'
);

-- 5. Add to Realtime Publication
ALTER PUBLICATION supabase_realtime ADD TABLE public.trip_logs;
