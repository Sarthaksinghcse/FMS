-- ─────────────────────────────────────────────────────────────
-- MNT-005: SOS Panic Alert Notification Routing Trigger
-- ─────────────────────────────────────────────────────────────
-- This script sets up a Postgres trigger that automatically routes
-- emergency panic alerts to all registered fleet managers in real time.
-- Run this in your Supabase SQL Editor.

-- 1. Create a function that handles routing notifications to fleet managers
CREATE OR REPLACE FUNCTION public.handle_new_sos_alert()
RETURNS TRIGGER AS $$
DECLARE
    manager_record RECORD;
    v_driver_name TEXT;
BEGIN
    -- Resolve driver name
    SELECT name INTO v_driver_name FROM public.users WHERE id = NEW.driver_id;
    IF v_driver_name IS NULL THEN
        v_driver_name := 'Driver';
    END IF;

    -- Insert a notification for every fleet manager in the system
    FOR manager_record IN 
        SELECT id FROM public.users WHERE role = 'fleet_manager'
    LOOP
        INSERT INTO public.notifications (user_id, title, message, type, is_read, created_at)
        VALUES (
            manager_record.id,
            '🚨 EMERGENCY SOS SIGNAL',
            COALESCE(NEW.message, 'Driver ' || v_driver_name || ' has triggered a panic alarm. Assistance is required immediately.'),
            'sosAlert', -- maps to enum NotificationType.sosAlert in Swift
            FALSE,
            NEW.created_at
        );
    END LOOP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Drop the trigger if it already exists to avoid duplicates
DROP TRIGGER IF EXISTS on_sos_alert_inserted ON public.sos_alerts;

-- 3. Bind the trigger to run AFTER INSERT on the public.sos_alerts table
CREATE TRIGGER on_sos_alert_inserted
    AFTER INSERT ON public.sos_alerts
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_sos_alert();
