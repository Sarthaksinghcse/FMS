-- ============================================================
-- Add tracking columns and UPDATE policy to trip_logs table
-- Run this in your Supabase SQL Editor
-- ============================================================

-- 1. Add tracking columns to public.trip_logs
ALTER TABLE public.trip_logs ADD COLUMN IF NOT EXISTS is_edited BOOLEAN DEFAULT FALSE;
ALTER TABLE public.trip_logs ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;

-- 2. Create UPDATE policy to allow drivers to update their own logs
CREATE POLICY "trip_logs_update_own" ON public.trip_logs 
FOR UPDATE 
USING (driver_id = auth.uid());
