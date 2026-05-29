-- ─────────────────────────────────────────────────────────────
-- MNT-004: Work Order Assignment Notification Trigger
-- ─────────────────────────────────────────────────────────────
-- This script sets up a Postgres trigger that automatically creates
-- a notification in the `notifications` table whenever a work order is
-- created or reassigned in the `work_orders` table.
-- Run this in your Supabase SQL Editor.

-- 1. Create or replace the notification handler function
CREATE OR REPLACE FUNCTION public.handle_work_order_assignment()
RETURNS TRIGGER AS $$
BEGIN
    -- Only trigger notification on insert, or if assignment changes on update
    IF (TG_OP = 'INSERT') OR (TG_OP = 'UPDATE' AND NEW.assigned_to IS DISTINCT FROM OLD.assigned_to) THEN
        INSERT INTO public.notifications (user_id, title, message, type, is_read, created_at)
        VALUES (
            NEW.assigned_to,
            'New Work Order Assigned',
            'You have been assigned a new work order: ' || NEW.title || ' (ID: ' || NEW.id || ')',
            'maintenance',
            FALSE,
            NOW()
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Drop the trigger if it already exists to avoid duplication
DROP TRIGGER IF EXISTS on_work_order_assigned ON public.work_orders;

-- 3. Create the AFTER trigger on INSERT or UPDATE
CREATE TRIGGER on_work_order_assigned
    AFTER INSERT OR UPDATE ON public.work_orders
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_work_order_assignment();
