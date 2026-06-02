-- ─────────────────────────────────────────────────────────────────────────────
-- FMS (FLEET MANAGEMENT SYSTEM) — COMPLETE SQL REPOSITORY
-- ─────────────────────────────────────────────────────────────────────────────
-- This file contains all database commands, schemas, triggers, seed data,
-- and user management queries for the FMS project.
-- ─────────────────────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 1: WIPE DATABASE SCHEMA (START OVER FRESH)
-- ─────────────────────────────────────────────────────────────────────────────
-- Use this query to completely delete all tables, enums, triggers, and data.
-- Run this before recreating the database.

-- DROP SCHEMA public CASCADE;
-- CREATE SCHEMA public;
-- GRANT ALL ON SCHEMA public TO postgres;
-- GRANT ALL ON SCHEMA public TO anon;
-- GRANT ALL ON SCHEMA public TO authenticated;
-- GRANT ALL ON SCHEMA public TO service_role;


-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 2: COMPLETE DATABASE SCHEMA CREATION (REBUILD SCHEMA)
-- ─────────────────────────────────────────────────────────────────────────────
-- This creates all enum types, tables, indexes, row-level security,
-- helper views, storage buckets, trigger functions, and inserts 10 vehicles.

-- 2.1 DEFINE ENUM TYPES
CREATE TYPE user_role AS ENUM ('fleet_manager', 'driver', 'maintenance');
CREATE TYPE vehicle_status AS ENUM ('available', 'in_use', 'maintenance', 'inactive');
CREATE TYPE trip_status AS ENUM ('assigned', 'started', 'completed', 'cancelled');
CREATE TYPE inspection_status AS ENUM ('passed', 'failed', 'needs_repair');
CREATE TYPE maintenance_status AS ENUM ('pending', 'in_progress', 'completed');
CREATE TYPE work_order_priority AS ENUM ('low', 'medium', 'high', 'urgent');
CREATE TYPE work_order_status AS ENUM ('open', 'in_progress', 'completed', 'closed');
CREATE TYPE notification_type AS ENUM ('info', 'warning', 'maintenance', 'trip', 'emergency', 'sosAlert');

-- 2.2 CREATE TABLES
CREATE TABLE public.users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL,
    email           TEXT NOT NULL UNIQUE,
    role            user_role NOT NULL,
    phone_number    TEXT,
    profile_image   TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.vehicles (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_number      TEXT NOT NULL UNIQUE,
    model               TEXT NOT NULL,
    manufacturer        TEXT NOT NULL,
    year                INTEGER NOT NULL CHECK (year >= 1900),
    vin                 TEXT NOT NULL UNIQUE,
    license_plate       TEXT NOT NULL UNIQUE,
    status              vehicle_status NOT NULL DEFAULT 'available',
    assigned_driver_id  UUID REFERENCES public.users(id) ON DELETE SET NULL,
    last_service_date   TIMESTAMPTZ,
    vehicle_type        TEXT DEFAULT 'car',
    fuel_type           TEXT DEFAULT 'petrol',
    odometer_reading    DOUBLE PRECISION DEFAULT 0.0,
    insurance_expiry_date TIMESTAMPTZ,
    permit_expiry_date   TIMESTAMPTZ,
    next_service_date    TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.trips (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id  UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
    driver_id   UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    source      TEXT NOT NULL,
    destination TEXT NOT NULL,
    start_time  TIMESTAMPTZ,
    end_time    TIMESTAMPTZ,
    distance    NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (distance >= 0),
    status      trip_status NOT NULL DEFAULT 'assigned',
    notes       TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.vehicle_inspections (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id      UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
    driver_id       UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    checklist       TEXT[] NOT NULL DEFAULT '{}',
    defects         TEXT,
    inspection_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status          inspection_status NOT NULL
);

CREATE TABLE public.maintenance_tasks (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id  UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
    assigned_to UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    service_type TEXT NOT NULL,
    due_date    TIMESTAMPTZ NOT NULL,
    status      maintenance_status NOT NULL DEFAULT 'pending',
    notes       TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.work_orders (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id        UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
    created_by        UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    assigned_to       UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    priority          work_order_priority NOT NULL DEFAULT 'medium',
    issue_description TEXT NOT NULL,
    status            work_order_status NOT NULL DEFAULT 'open',
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.messages (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id   UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    message     TEXT NOT NULL,
    timestamp   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.notifications (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title       TEXT NOT NULL,
    message     TEXT NOT NULL,
    type        notification_type NOT NULL,
    is_read     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.vehicle_locations (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id  UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
    latitude    DOUBLE PRECISION NOT NULL,
    longitude   DOUBLE PRECISION NOT NULL,
    timestamp   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.defect_reports (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id         UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
    reported_by        UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    inspection_id      UUID REFERENCES public.vehicle_inspections(id) ON DELETE SET NULL,
    title              TEXT NOT NULL,
    defect_description TEXT NOT NULL,
    severity           TEXT NOT NULL,
    status             TEXT NOT NULL DEFAULT 'open',
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.sos_alerts (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id   UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    vehicle_id  UUID REFERENCES public.vehicles(id) ON DELETE SET NULL,
    trip_id     UUID REFERENCES public.trips(id) ON DELETE SET NULL,
    latitude    DOUBLE PRECISION NOT NULL,
    longitude   DOUBLE PRECISION NOT NULL,
    message     TEXT,
    status      TEXT NOT NULL DEFAULT 'active',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.inventory (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    part_name          TEXT NOT NULL,
    part_number        TEXT NOT NULL UNIQUE,
    quantity_in_stock  INTEGER NOT NULL DEFAULT 0,
    reorder_threshold  INTEGER NOT NULL DEFAULT 0,
    unit_cost          NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    supplier_name      TEXT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.maintenance_records (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id    UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
    work_order_id UUID REFERENCES public.work_orders(id) ON DELETE SET NULL,
    service_type  TEXT NOT NULL,
    service_date  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    cost          NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (cost >= 0),
    notes         TEXT,
    repair_images TEXT[],
    performed_by  UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.fuel_logs (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id   UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    vehicle_id  UUID REFERENCES public.vehicles(id) ON DELETE SET NULL,
    trip_id     UUID REFERENCES public.trips(id) ON DELETE SET NULL,
    fuel_type   TEXT NOT NULL DEFAULT 'petrol',
    litres      NUMERIC(10, 2) NOT NULL CHECK (litres >= 0),
    amount_paid NUMERIC(10, 2) NOT NULL CHECK (amount_paid >= 0),
    odometer    DOUBLE PRECISION,
    receipt_url TEXT,
    notes       TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.compliance_alerts (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id    UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
    alert_type    TEXT NOT NULL,
    status        TEXT NOT NULL,
    deadline_date TIMESTAMPTZ NOT NULL,
    resolved_at   TIMESTAMPTZ,
    notes         TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.3 CREATE INDEXES
CREATE INDEX idx_vehicles_status             ON public.vehicles (status);
CREATE INDEX idx_vehicles_assigned_driver    ON public.vehicles (assigned_driver_id);
CREATE INDEX idx_trips_vehicle               ON public.trips (vehicle_id);
CREATE INDEX idx_trips_driver                ON public.trips (driver_id);
CREATE INDEX idx_trips_status                ON public.trips (status);
CREATE INDEX idx_inspections_vehicle         ON public.vehicle_inspections (vehicle_id);
CREATE INDEX idx_inspections_driver          ON public.vehicle_inspections (driver_id);
CREATE INDEX idx_inspections_date            ON public.vehicle_inspections (inspection_date DESC);
CREATE INDEX idx_maintenance_vehicle         ON public.maintenance_tasks (vehicle_id);
CREATE INDEX idx_maintenance_assigned        ON public.maintenance_tasks (assigned_to);
CREATE INDEX idx_maintenance_status          ON public.maintenance_tasks (status);
CREATE INDEX idx_maintenance_due             ON public.maintenance_tasks (due_date);
CREATE INDEX idx_work_orders_vehicle         ON public.work_orders (vehicle_id);
CREATE INDEX idx_work_orders_assigned        ON public.work_orders (assigned_to);
CREATE INDEX idx_work_orders_status          ON public.work_orders (status);
CREATE INDEX idx_work_orders_priority        ON public.work_orders (priority);
CREATE INDEX idx_messages_sender             ON public.messages (sender_id);
CREATE INDEX idx_messages_receiver           ON public.messages (receiver_id);
CREATE INDEX idx_messages_timestamp          ON public.messages (timestamp DESC);
CREATE INDEX idx_notifications_user          ON public.notifications (user_id);
CREATE INDEX idx_notifications_is_read       ON public.notifications (user_id, is_read);
CREATE INDEX idx_vehicle_locations_vehicle   ON public.vehicle_locations (vehicle_id);
CREATE INDEX idx_vehicle_locations_timestamp ON public.vehicle_locations (vehicle_id, timestamp DESC);
CREATE INDEX idx_defect_reports_vehicle      ON public.defect_reports (vehicle_id);
CREATE INDEX idx_defect_reports_reported_by  ON public.defect_reports (reported_by);
CREATE INDEX idx_defect_reports_status       ON public.defect_reports (status);
CREATE INDEX idx_sos_alerts_driver           ON public.sos_alerts (driver_id);
CREATE INDEX idx_maintenance_records_vehicle ON public.maintenance_records (vehicle_id);
CREATE INDEX idx_maintenance_records_date    ON public.maintenance_records (service_date DESC);
CREATE INDEX idx_fuel_logs_driver            ON public.fuel_logs (driver_id);
CREATE INDEX idx_fuel_logs_vehicle           ON public.fuel_logs (vehicle_id);
CREATE INDEX idx_compliance_alerts_vehicle   ON public.compliance_alerts (vehicle_id);

-- 2.4 ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE public.users               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trips               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicle_inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_tasks   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.work_orders         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicle_locations   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.defect_reports       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sos_alerts          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fuel_logs           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.compliance_alerts   ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS user_role LANGUAGE sql SECURITY DEFINER STABLE AS $$
    SELECT role FROM public.users WHERE id = auth.uid();
$$;

-- Users RLS
CREATE POLICY "users_select_own"         ON public.users FOR SELECT USING (id = auth.uid());
CREATE POLICY "users_select_all_manager" ON public.users FOR SELECT USING (public.current_user_role() = 'fleet_manager');
CREATE POLICY "users_select_managers"    ON public.users FOR SELECT USING (role = 'fleet_manager');
CREATE POLICY "users_update_own"         ON public.users FOR UPDATE USING (id = auth.uid());
CREATE POLICY "users_insert_manager"     ON public.users FOR INSERT WITH CHECK (public.current_user_role() = 'fleet_manager');
CREATE POLICY "users_update_manager"     ON public.users FOR UPDATE USING (public.current_user_role() = 'fleet_manager');
CREATE POLICY "users_delete_manager"     ON public.users FOR DELETE USING (public.current_user_role() = 'fleet_manager');

-- Vehicles RLS
CREATE POLICY "vehicles_select_all"     ON public.vehicles FOR SELECT USING (TRUE);
CREATE POLICY "vehicles_modify_manager" ON public.vehicles FOR ALL   USING (public.current_user_role() = 'fleet_manager');

-- Trips RLS
CREATE POLICY "trips_select_own_driver" ON public.trips FOR SELECT USING (driver_id = auth.uid());
CREATE POLICY "trips_select_manager"    ON public.trips FOR SELECT USING (public.current_user_role() = 'fleet_manager');
CREATE POLICY "trips_insert_manager"    ON public.trips FOR INSERT WITH CHECK (public.current_user_role() = 'fleet_manager');
CREATE POLICY "trips_update_driver"     ON public.trips FOR UPDATE USING (driver_id = auth.uid() AND status IN ('assigned','started')) WITH CHECK (driver_id = auth.uid() AND status IN ('assigned','started','completed'));
CREATE POLICY "trips_update_manager"    ON public.trips FOR UPDATE USING (public.current_user_role() = 'fleet_manager');
CREATE POLICY "trips_delete_manager"    ON public.trips FOR DELETE USING (public.current_user_role() = 'fleet_manager');

-- Inspections RLS
CREATE POLICY "inspections_select_manager"    ON public.vehicle_inspections FOR SELECT USING (public.current_user_role() = 'fleet_manager');
CREATE POLICY "inspections_select_own_driver" ON public.vehicle_inspections FOR SELECT USING (driver_id = auth.uid());
CREATE POLICY "inspections_insert_driver"     ON public.vehicle_inspections FOR INSERT WITH CHECK (driver_id = auth.uid());

-- Maintenance Tasks RLS
CREATE POLICY "maintenance_select_manager"  ON public.maintenance_tasks FOR SELECT USING (public.current_user_role() = 'fleet_manager');
CREATE POLICY "maintenance_select_own"      ON public.maintenance_tasks FOR SELECT USING (assigned_to = auth.uid());
CREATE POLICY "maintenance_insert_manager"  ON public.maintenance_tasks FOR INSERT WITH CHECK (public.current_user_role() = 'fleet_manager');
CREATE POLICY "maintenance_update_assigned" ON public.maintenance_tasks FOR UPDATE USING (assigned_to = auth.uid());
CREATE POLICY "maintenance_update_manager"  ON public.maintenance_tasks FOR UPDATE USING (public.current_user_role() = 'fleet_manager');

-- Work Orders RLS
CREATE POLICY "work_orders_select_manager"  ON public.work_orders FOR SELECT USING (public.current_user_role() = 'fleet_manager');
CREATE POLICY "work_orders_select_assigned" ON public.work_orders FOR SELECT USING (assigned_to = auth.uid());
CREATE POLICY "work_orders_insert_manager"  ON public.work_orders FOR INSERT WITH CHECK (public.current_user_role() = 'fleet_manager');
CREATE POLICY "work_orders_update_assigned" ON public.work_orders FOR UPDATE USING (assigned_to = auth.uid());

-- Messages RLS
CREATE POLICY "messages_select_policy" ON public.messages FOR SELECT USING (sender_id = auth.uid() OR receiver_id = auth.uid() OR (SELECT role FROM public.users WHERE id = auth.uid()) = 'fleet_manager');
CREATE POLICY "messages_insert_own" ON public.messages FOR INSERT WITH CHECK (sender_id = auth.uid());

-- Notifications RLS
CREATE POLICY "notifications_select_own" ON public.notifications FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "notifications_update_own" ON public.notifications FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "notifications_insert_own" ON public.notifications FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "notifications_select_manager" ON public.notifications FOR SELECT USING (public.current_user_role() = 'fleet_manager');
CREATE POLICY "notifications_insert_manager" ON public.notifications FOR INSERT WITH CHECK (public.current_user_role() = 'fleet_manager');
CREATE POLICY "notifications_insert_to_manager" ON public.notifications FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM public.users WHERE id = user_id AND role = 'fleet_manager'));

-- Defect Reports RLS
CREATE POLICY "defect_reports_select_all" ON public.defect_reports FOR SELECT USING (TRUE);
CREATE POLICY "defect_reports_insert_driver" ON public.defect_reports FOR INSERT WITH CHECK (reported_by = auth.uid());
CREATE POLICY "defect_reports_update_policy" ON public.defect_reports FOR UPDATE USING (reported_by = auth.uid() OR public.current_user_role() = 'fleet_manager' OR public.current_user_role() = 'maintenance');
CREATE POLICY "defect_reports_delete_manager" ON public.defect_reports FOR DELETE USING (public.current_user_role() = 'fleet_manager');

-- Vehicle Locations RLS
CREATE POLICY "locations_select_manager" ON public.vehicle_locations FOR SELECT USING (public.current_user_role() = 'fleet_manager');
CREATE POLICY "locations_select_driver" ON public.vehicle_locations FOR SELECT USING (EXISTS (SELECT 1 FROM public.vehicles WHERE id = vehicle_id AND assigned_driver_id = auth.uid()));
CREATE POLICY "locations_insert_driver"  ON public.vehicle_locations FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM public.vehicles WHERE id = vehicle_id AND assigned_driver_id = auth.uid()));

-- SOS Alerts RLS
CREATE POLICY "sos_alerts_select_all" ON public.sos_alerts FOR SELECT USING (TRUE);
CREATE POLICY "sos_alerts_insert_driver" ON public.sos_alerts FOR INSERT WITH CHECK (driver_id = auth.uid());
CREATE POLICY "sos_alerts_update_all" ON public.sos_alerts FOR UPDATE USING (TRUE);

-- Inventory RLS
CREATE POLICY "inventory_select_all" ON public.inventory FOR SELECT USING (TRUE);
CREATE POLICY "inventory_modify_manager" ON public.inventory FOR ALL USING (public.current_user_role() = 'fleet_manager');
CREATE POLICY "inventory_modify_maintenance" ON public.inventory FOR ALL USING (public.current_user_role() = 'maintenance');

-- Maintenance Records RLS
CREATE POLICY "maintenance_records_select_all" ON public.maintenance_records FOR SELECT USING (TRUE);
CREATE POLICY "maintenance_records_modify_all" ON public.maintenance_records FOR ALL USING (public.current_user_role() = 'fleet_manager' OR public.current_user_role() = 'maintenance');

-- Fuel Logs RLS
CREATE POLICY "fuel_logs_select_all" ON public.fuel_logs FOR SELECT USING (TRUE);
CREATE POLICY "fuel_logs_insert_driver" ON public.fuel_logs FOR INSERT WITH CHECK (driver_id = auth.uid());
CREATE POLICY "fuel_logs_update_all" ON public.fuel_logs FOR UPDATE USING (TRUE);
CREATE POLICY "fuel_logs_delete_manager" ON public.fuel_logs FOR DELETE USING (public.current_user_role() = 'fleet_manager');

-- Compliance Alerts RLS
CREATE POLICY "compliance_alerts_select_all" ON public.compliance_alerts FOR SELECT USING (TRUE);
CREATE POLICY "compliance_alerts_modify_all" ON public.compliance_alerts FOR ALL USING (public.current_user_role() = 'fleet_manager' OR public.current_user_role() = 'maintenance');

-- 2.5 CREATE HELPER VIEWS
CREATE OR REPLACE VIEW public.v_active_trips AS
SELECT t.id, t.source, t.destination, t.start_time, t.distance, t.status, t.notes,
       v.vehicle_number, v.model, v.license_plate,
       u.name AS driver_name, u.phone_number AS driver_phone
FROM public.trips t
JOIN public.vehicles v ON v.id = t.vehicle_id
JOIN public.users    u ON u.id = t.driver_id
WHERE t.status IN ('assigned', 'started');

CREATE OR REPLACE VIEW public.v_unread_notification_count AS
SELECT user_id, COUNT(*) AS unread_count
FROM public.notifications
WHERE is_read = FALSE
GROUP BY user_id;

CREATE OR REPLACE VIEW public.v_latest_vehicle_location AS
SELECT DISTINCT ON (vehicle_id) id, vehicle_id, latitude, longitude, timestamp
FROM public.vehicle_locations
ORDER BY vehicle_id, timestamp DESC;

CREATE OR REPLACE VIEW public.v_open_work_orders AS
SELECT wo.id, wo.issue_description, wo.priority, wo.status, wo.created_at,
       v.vehicle_number, v.license_plate,
       u.name AS assigned_to_name
FROM public.work_orders wo
JOIN public.vehicles v ON v.id = wo.vehicle_id
JOIN public.users    u ON u.id = wo.assigned_to
WHERE wo.status IN ('open', 'in_progress');

-- 2.6 ENABLE REALTIME PUBLICATIONS
ALTER PUBLICATION supabase_realtime ADD TABLE public.trips;
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.vehicle_locations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.maintenance_tasks;
ALTER PUBLICATION supabase_realtime ADD TABLE public.sos_alerts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.inventory;
ALTER PUBLICATION supabase_realtime ADD TABLE public.maintenance_records;
ALTER PUBLICATION supabase_realtime ADD TABLE public.fuel_logs;
ALTER PUBLICATION supabase_realtime ADD TABLE public.compliance_alerts;

-- 2.7 INITIALIZE STORAGE BUCKETS
INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('maintenance-images', 'maintenance-images', true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('receipts', 'receipts', true) ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Public Avatar Access" ON storage.objects;
CREATE POLICY "Public Avatar Access" ON storage.objects FOR SELECT USING (bucket_id = 'avatars');
DROP POLICY IF EXISTS "Insert own avatar" ON storage.objects;
CREATE POLICY "Insert own avatar" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'avatars');
DROP POLICY IF EXISTS "Update own avatar" ON storage.objects;
CREATE POLICY "Update own avatar" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Public Maintenance Image Access" ON storage.objects;
CREATE POLICY "Public Maintenance Image Access" ON storage.objects FOR SELECT USING (bucket_id = 'maintenance-images');
DROP POLICY IF EXISTS "Insert maintenance image" ON storage.objects;
CREATE POLICY "Insert maintenance image" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'maintenance-images');
DROP POLICY IF EXISTS "Update maintenance image" ON storage.objects;
CREATE POLICY "Update maintenance image" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'maintenance-images');

DROP POLICY IF EXISTS "Public Receipt Access" ON storage.objects;
CREATE POLICY "Public Receipt Access" ON storage.objects FOR SELECT USING (bucket_id = 'receipts');
DROP POLICY IF EXISTS "Insert own receipt" ON storage.objects;
CREATE POLICY "Insert own receipt" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'receipts');
DROP POLICY IF EXISTS "Update own receipt" ON storage.objects;
CREATE POLICY "Update own receipt" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'receipts');

-- 2.8 AUTOMATION TRIGGERS SETUP
-- 2.8.1 Work Order Notification Trigger
CREATE OR REPLACE FUNCTION public.handle_work_order_assignment()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') OR (TG_OP = 'UPDATE' AND NEW.assigned_to IS DISTINCT FROM OLD.assigned_to) THEN
        INSERT INTO public.notifications (user_id, title, message, type, is_read, created_at)
        VALUES (
            NEW.assigned_to,
            'New Work Order Assigned',
            'You have been assigned a new work order: ' || NEW.issue_description || ' (ID: ' || NEW.id || ')',
            'maintenance',
            FALSE,
            NOW()
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_work_order_assigned ON public.work_orders;
CREATE TRIGGER on_work_order_assigned
    AFTER INSERT OR UPDATE ON public.work_orders
    FOR EACH ROW EXECUTE FUNCTION public.handle_work_order_assignment();

-- 2.8.2 Emergency SOS Router Trigger
CREATE OR REPLACE FUNCTION public.handle_new_sos_alert()
RETURNS TRIGGER AS $$
DECLARE
    manager_record RECORD;
    v_driver_name TEXT;
BEGIN
    SELECT name INTO v_driver_name FROM public.users WHERE id = NEW.driver_id;
    IF v_driver_name IS NULL THEN
        v_driver_name := 'Driver';
    END IF;

    FOR manager_record IN SELECT id FROM public.users WHERE role = 'fleet_manager' LOOP
        INSERT INTO public.notifications (user_id, title, message, type, is_read, created_at)
        VALUES (
            manager_record.id,
            '🚨 EMERGENCY SOS SIGNAL',
            COALESCE(NEW.message, 'Driver ' || v_driver_name || ' has triggered a panic alarm. Assistance is required immediately.'),
            'sosAlert',
            FALSE,
            NEW.created_at
        );
    END LOOP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_sos_alert_inserted ON public.sos_alerts;
CREATE TRIGGER on_sos_alert_inserted
    AFTER INSERT ON public.sos_alerts
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_sos_alert();

-- 2.9 SEED DATA - 10 VEHICLES OF DIFFERENT TYPES & FUEL TYPES
INSERT INTO public.vehicles (id, vehicle_number, model, manufacturer, year, vin, license_plate, status, vehicle_type, fuel_type, odometer_reading, insurance_expiry_date, permit_expiry_date, next_service_date)
VALUES
  (gen_random_uuid(), 'TRK-001', 'F-150 Lightning', 'Ford', 2023, 'VIN-TRUCK-00000001', 'MH12AA1111', 'available', 'truck', 'electric', 12000.50, NOW() + INTERVAL '300 days', NOW() + INTERVAL '180 days', NOW() + INTERVAL '90 days'),
  (gen_random_uuid(), 'TRK-002', 'Super Duty F-350', 'Ford', 2022, 'VIN-TRUCK-00000002', 'MH12AA2222', 'available', 'truck', 'diesel', 45000.00, NOW() + INTERVAL '120 days', NOW() + INTERVAL '90 days', NOW() + INTERVAL '30 days'),
  (gen_random_uuid(), 'VAN-001', 'Transit Cargo Van', 'Ford', 2021, 'VIN-VAN-0000000001', 'MH12BB1111', 'available', 'van', 'petrol', 35000.75, NOW() + INTERVAL '240 days', NOW() + INTERVAL '150 days', NOW() + INTERVAL '60 days'),
  (gen_random_uuid(), 'VAN-002', 'e-Transit', 'Ford', 2023, 'VIN-VAN-0000000002', 'MH12BB2222', 'available', 'van', 'electric', 8500.20, NOW() + INTERVAL '310 days', NOW() + INTERVAL '210 days', NOW() + INTERVAL '100 days'),
  (gen_random_uuid(), 'CAR-001', 'Model 3 Long Range', 'Tesla', 2022, 'VIN-CAR-0000000001', 'MH12CC1111', 'available', 'car', 'electric', 18450.00, NOW() + INTERVAL '200 days', NOW() + INTERVAL '100 days', NOW() + INTERVAL '45 days'),
  (gen_random_uuid(), 'CAR-002', 'Prius AWD-e', 'Toyota', 2021, 'VIN-CAR-0000000002', 'MH12CC2222', 'available', 'car', 'hybrid', 29000.80, NOW() + INTERVAL '150 days', NOW() + INTERVAL '80 days', NOW() + INTERVAL '20 days'),
  (gen_random_uuid(), 'CAR-003', 'Civic Sedan', 'Honda', 2020, 'VIN-CAR-0000000003', 'MH12CC3333', 'available', 'car', 'petrol', 52000.10, NOW() + INTERVAL '90 days', NOW() + INTERVAL '60 days', NOW() + INTERVAL '15 days'),
  (gen_random_uuid(), 'BKE-001', 'LiveWire One', 'Harley-Davidson', 2023, 'VIN-BIKE-000000001', 'MH12DD1111', 'available', 'bike', 'electric', 2500.40, NOW() + INTERVAL '320 days', NOW() + INTERVAL '250 days', NOW() + INTERVAL '120 days'),
  (gen_random_uuid(), 'BKE-002', 'CB500X', 'Honda', 2022, 'VIN-BIKE-000000002', 'MH12DD2222', 'available', 'bike', 'petrol', 11000.30, NOW() + INTERVAL '180 days', NOW() + INTERVAL '120 days', NOW() + INTERVAL '40 days'),
  (gen_random_uuid(), 'BKE-003', 'V-Strom 650 XT', 'Suzuki', 2021, 'VIN-BIKE-000000003', 'MH12DD3333', 'available', 'bike', 'petrol', 17800.90, NOW() + INTERVAL '140 days', NOW() + INTERVAL '90 days', NOW() + INTERVAL '25 days');


-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 3: USER & AUTH ACCOUNTS MANAGEMENT
-- ─────────────────────────────────────────────────────────────────────────────

-- 3.1 RESET & CREATE PERMANENT TEST ACCOUNTS
-- First deletes any old conflicting test accounts, then inserts fresh login credentials (confirmed) and profiles.
-- Run this block directly to setup driver & mechanic.

-- DELETE FROM auth.users WHERE email IN ('driver@fms.com', 'mechanic@fms.com');
-- DELETE FROM public.users WHERE email IN ('driver@fms.com', 'mechanic@fms.com', 'carol@fms.com');

-- DO $$
-- DECLARE
--   v_driver_id UUID := gen_random_uuid();
--   v_mechanic_id UUID := gen_random_uuid();
-- BEGIN
--   INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, role, aud, created_at, updated_at)
--   VALUES (v_driver_id, '00000000-0000-0000-0000-000000000000', 'driver@fms.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"name":"Bob Driver","role":"driver"}', false, 'authenticated', 'authenticated', now(), now());
--   
--   INSERT INTO public.users (id, name, email, role, phone_number, is_active)
--   VALUES (v_driver_id, 'Bob Driver', 'driver@fms.com', 'driver', '+910000000002', true);
-- 
--   INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, role, aud, created_at, updated_at)
--   VALUES (v_mechanic_id, '00000000-0000-0000-0000-000000000000', 'mechanic@fms.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"name":"Carol Mechanic","role":"maintenance"}', false, 'authenticated', 'authenticated', now(), now());
-- 
--   INSERT INTO public.users (id, name, email, role, phone_number, is_active)
--   VALUES (v_mechanic_id, 'Carol Mechanic', 'mechanic@fms.com', 'maintenance', '+910000000003', true);
-- END $$;


-- 3.2 INSERT FLEET MANAGER ROW IN PUBLIC.USERS
-- Required for RLS authentication to work properly after a schema wipe.
-- Retrieve your manager user ID from `SELECT id FROM auth.users WHERE email = 'your-manager-email';` first.

INSERT INTO public.users (id, name, email, role, phone_number, is_active)
VALUES (
  '2e2f15c4-a9cf-4397-941a-85e9737a92dd',
  'Naman',
  'fleetmanager@fms.com',
  'fleet_manager',
  '+1234567890',
  true
);


-- 3.3 UPDATE USER PASSWORD
-- Replace NEW_PASSWORD_HERE with your desired password, and email with the target user's email.
-- UPDATE auth.users 
-- SET encrypted_password = crypt('NEW_PASSWORD_HERE', gen_salt('bf'))
-- WHERE email = 'target-user@fms.com';


-- 3.4 UPDATE USER FULL NAME (BOTH AUTH METADATA & PUBLIC VIEW)
-- UPDATE public.users 
-- SET name = 'New Target Name' 
-- WHERE email = 'target-user@fms.com';
-- 
-- UPDATE auth.users 
-- SET raw_user_meta_data = jsonb_set(raw_user_meta_data, '{name}', '"New Target Name"')
-- WHERE email = 'target-user@fms.com';


-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 4: CONVENIENCE & DEBUG QUERY COMMANDS
-- ─────────────────────────────────────────────────────────────────────────────

-- 4.1 VIEW PROFILE RELATIONSHIPS (VERIFY RLS COMPLIANCE)
-- SELECT id, email, role FROM public.users;
-- SELECT id, email, raw_user_meta_data FROM auth.users;

-- 4.2 LIST VEHICLES ASSIGNMENT & STATUS
-- SELECT id, vehicle_number, model, status, assigned_driver_id FROM public.vehicles;

-- 4.3 VIEW PENDING SOS PANIC ALERTS
-- SELECT * FROM public.sos_alerts WHERE status = 'active';

-- 4.4 VIEW RECENT DISPATCHED TRIPS
-- SELECT * FROM public.v_active_trips;
