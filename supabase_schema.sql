-- ============================================================
--  FMS (Fleet Management System) — Supabase SQL Schema
--  Generated from Swift data models in /FMS/Models/
-- ============================================================

-- ============================================================
-- 1. CUSTOM ENUM TYPES
-- ============================================================

-- UserRole  (UserRole.swift)
CREATE TYPE user_role AS ENUM (
    'fleet_manager',
    'driver',
    'maintenance'
);

-- VehicleStatus  (VehicleStatus.swift)
CREATE TYPE vehicle_status AS ENUM (
    'available',
    'in_use',
    'maintenance',
    'inactive'
);

-- TripStatus  (TripStatus.swift)
CREATE TYPE trip_status AS ENUM (
    'assigned',
    'started',
    'completed',
    'cancelled'
);

-- InspectionStatus  (InspectionStatus.swift)
CREATE TYPE inspection_status AS ENUM (
    'passed',
    'failed',
    'needs_repair'
);

-- MaintenanceStatus  (MaintenanceStatus.swift)
CREATE TYPE maintenance_status AS ENUM (
    'pending',
    'in_progress',
    'completed'
);

-- WorkOrderPriority  (WorkOrderPriority.swift)
CREATE TYPE work_order_priority AS ENUM (
    'low',
    'medium',
    'high',
    'urgent'
);

-- WorkOrderStatus  (WorkOrderPriority.swift)
CREATE TYPE work_order_status AS ENUM (
    'open',
    'in_progress',
    'completed',
    'closed'
);

-- NotificationType  (NotificationType.swift)
CREATE TYPE notification_type AS ENUM (
    'info',
    'warning',
    'maintenance',
    'trip',
    'emergency'
);


-- ============================================================
-- 2. TABLES
-- ============================================================

-- 2.1  users   (UserRole.swift)
-- NOTE: Supabase Auth already manages auth.users.
--       This table stores profile data; id links to auth.uid().
CREATE TABLE IF NOT EXISTS public.users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT        NOT NULL,
    email           TEXT        NOT NULL UNIQUE,
    role            user_role   NOT NULL,
    phone_number    TEXT,
    profile_image   TEXT,
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.2  vehicles   (VehicleStatus.swift)
CREATE TABLE IF NOT EXISTS public.vehicles (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_number      TEXT           NOT NULL UNIQUE,
    model               TEXT           NOT NULL,
    manufacturer        TEXT           NOT NULL,
    year                INTEGER        NOT NULL CHECK (year >= 1900),
    vin                 TEXT           NOT NULL UNIQUE,
    license_plate       TEXT           NOT NULL UNIQUE,
    status              vehicle_status NOT NULL DEFAULT 'available',
    assigned_driver_id  UUID           REFERENCES public.users (id) ON DELETE SET NULL,
    last_service_date   TIMESTAMPTZ,
    created_at          TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

-- 2.3  trips   (TripStatus.swift)
CREATE TABLE IF NOT EXISTS public.trips (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id  UUID        NOT NULL REFERENCES public.vehicles (id) ON DELETE CASCADE,
    driver_id   UUID        NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    source      TEXT        NOT NULL,
    destination TEXT        NOT NULL,
    start_time  TIMESTAMPTZ,
    end_time    TIMESTAMPTZ,
    distance    NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (distance >= 0),
    status      trip_status NOT NULL DEFAULT 'assigned',
    notes       TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.4  vehicle_inspections   (InspectionStatus.swift)
CREATE TABLE IF NOT EXISTS public.vehicle_inspections (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id      UUID               NOT NULL REFERENCES public.vehicles (id) ON DELETE CASCADE,
    driver_id       UUID               NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    checklist       TEXT[]             NOT NULL DEFAULT '{}',
    defects         TEXT,
    inspection_date TIMESTAMPTZ        NOT NULL DEFAULT NOW(),
    status          inspection_status  NOT NULL
);

-- 2.5  maintenance_tasks   (MaintenanceStatus.swift)
CREATE TABLE IF NOT EXISTS public.maintenance_tasks (
    id          UUID               PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id  UUID               NOT NULL REFERENCES public.vehicles (id) ON DELETE CASCADE,
    assigned_to UUID               NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    service_type TEXT              NOT NULL,
    due_date    TIMESTAMPTZ        NOT NULL,
    status      maintenance_status NOT NULL DEFAULT 'pending',
    notes       TEXT,
    created_at  TIMESTAMPTZ        NOT NULL DEFAULT NOW()
);

-- 2.6  work_orders   (WorkOrderPriority.swift)
CREATE TABLE IF NOT EXISTS public.work_orders (
    id                UUID               PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id        UUID               NOT NULL REFERENCES public.vehicles (id) ON DELETE CASCADE,
    created_by        UUID               NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    assigned_to       UUID               NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    priority          work_order_priority NOT NULL DEFAULT 'medium',
    issue_description TEXT               NOT NULL,
    status            work_order_status  NOT NULL DEFAULT 'open',
    created_at        TIMESTAMPTZ        NOT NULL DEFAULT NOW()
);

-- 2.7  messages   (Message.swift)
CREATE TABLE IF NOT EXISTS public.messages (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id   UUID        NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    receiver_id UUID        NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    message     TEXT        NOT NULL,
    timestamp   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.8  notifications   (NotificationType.swift)
CREATE TABLE IF NOT EXISTS public.notifications (
    id          UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID              NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    title       TEXT              NOT NULL,
    message     TEXT              NOT NULL,
    type        notification_type NOT NULL,
    is_read     BOOLEAN           NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

-- 2.9  vehicle_locations   (VehicleLocation.swift)
CREATE TABLE IF NOT EXISTS public.vehicle_locations (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id  UUID        NOT NULL REFERENCES public.vehicles (id) ON DELETE CASCADE,
    latitude    DOUBLE PRECISION NOT NULL,
    longitude   DOUBLE PRECISION NOT NULL,
    timestamp   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.10  defect_reports   (DefectReport.swift)
CREATE TABLE IF NOT EXISTS public.defect_reports (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id         UUID NOT NULL REFERENCES public.vehicles (id) ON DELETE CASCADE,
    reported_by        UUID NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    inspection_id      UUID REFERENCES public.vehicle_inspections (id) ON DELETE SET NULL,
    title              TEXT NOT NULL,
    defect_description TEXT NOT NULL,
    severity           TEXT NOT NULL, -- 'low', 'medium', 'high'
    status             TEXT NOT NULL DEFAULT 'open', -- 'open', 'in_progress', 'resolved'
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- 2.11  sos_alerts   (SOSAlert.swift)
CREATE TABLE IF NOT EXISTS public.sos_alerts (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id   UUID        NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    vehicle_id  UUID,
    trip_id     UUID,
    latitude    DOUBLE PRECISION NOT NULL,
    longitude   DOUBLE PRECISION NOT NULL,
    message     TEXT,
    status      TEXT NOT NULL DEFAULT 'active',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.12  inventory   (InventoryItem.swift)
CREATE TABLE IF NOT EXISTS public.inventory (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    part_name          TEXT        NOT NULL,
    part_number        TEXT        NOT NULL UNIQUE,
    quantity_in_stock  INTEGER     NOT NULL DEFAULT 0,
    reorder_threshold  INTEGER     NOT NULL DEFAULT 0,
    unit_cost          NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    supplier_name      TEXT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.13  maintenance_records   (MaintenanceRecord.swift)
CREATE TABLE IF NOT EXISTS public.maintenance_records (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id    UUID        NOT NULL REFERENCES public.vehicles (id) ON DELETE CASCADE,
    work_order_id UUID                 REFERENCES public.work_orders (id) ON DELETE SET NULL,
    service_type  TEXT        NOT NULL,
    service_date  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    cost          NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (cost >= 0),
    notes         TEXT,
    repair_images TEXT[],
    performed_by  UUID        NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 3. INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_vehicles_status             ON public.vehicles (status);
CREATE INDEX IF NOT EXISTS idx_vehicles_assigned_driver    ON public.vehicles (assigned_driver_id);

CREATE INDEX IF NOT EXISTS idx_trips_vehicle               ON public.trips (vehicle_id);
CREATE INDEX IF NOT EXISTS idx_trips_driver                ON public.trips (driver_id);
CREATE INDEX IF NOT EXISTS idx_trips_status                ON public.trips (status);

CREATE INDEX IF NOT EXISTS idx_inspections_vehicle         ON public.vehicle_inspections (vehicle_id);
CREATE INDEX IF NOT EXISTS idx_inspections_driver          ON public.vehicle_inspections (driver_id);
CREATE INDEX IF NOT EXISTS idx_inspections_date            ON public.vehicle_inspections (inspection_date DESC);

CREATE INDEX IF NOT EXISTS idx_maintenance_vehicle         ON public.maintenance_tasks (vehicle_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_assigned        ON public.maintenance_tasks (assigned_to);
CREATE INDEX IF NOT EXISTS idx_maintenance_status          ON public.maintenance_tasks (status);
CREATE INDEX IF NOT EXISTS idx_maintenance_due             ON public.maintenance_tasks (due_date);

CREATE INDEX IF NOT EXISTS idx_work_orders_vehicle         ON public.work_orders (vehicle_id);
CREATE INDEX IF NOT EXISTS idx_work_orders_assigned        ON public.work_orders (assigned_to);
CREATE INDEX IF NOT EXISTS idx_work_orders_status          ON public.work_orders (status);
CREATE INDEX IF NOT EXISTS idx_work_orders_priority        ON public.work_orders (priority);

CREATE INDEX IF NOT EXISTS idx_messages_sender             ON public.messages (sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_receiver           ON public.messages (receiver_id);
CREATE INDEX IF NOT EXISTS idx_messages_timestamp          ON public.messages (timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user          ON public.notifications (user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read       ON public.notifications (user_id, is_read);

CREATE INDEX IF NOT EXISTS idx_vehicle_locations_vehicle   ON public.vehicle_locations (vehicle_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_locations_timestamp ON public.vehicle_locations (vehicle_id, timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_defect_reports_vehicle      ON public.defect_reports (vehicle_id);
CREATE INDEX IF NOT EXISTS idx_defect_reports_reported_by  ON public.defect_reports (reported_by);
CREATE INDEX IF NOT EXISTS idx_defect_reports_status       ON public.defect_reports (status);

CREATE INDEX IF NOT EXISTS idx_sos_alerts_driver           ON public.sos_alerts (driver_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_records_vehicle ON public.maintenance_records (vehicle_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_records_date    ON public.maintenance_records (service_date DESC);


-- ============================================================
-- 4. ROW LEVEL SECURITY (RLS)
-- ============================================================

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

-- Helper: get role of logged-in user
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS user_role LANGUAGE sql STABLE AS $$
    SELECT role FROM public.users WHERE id = auth.uid();
$$;

-- ---- users ----
CREATE POLICY "users_select_own"         ON public.users FOR SELECT USING (id = auth.uid());
CREATE POLICY "users_select_all_manager" ON public.users FOR SELECT USING (public.current_user_role() = 'fleet_manager');
DROP POLICY IF EXISTS "users_select_managers"    ON public.users;
CREATE POLICY "users_select_managers"    ON public.users FOR SELECT USING (role = 'fleet_manager');
CREATE POLICY "users_update_own"         ON public.users FOR UPDATE USING (id = auth.uid());
CREATE POLICY "users_insert_manager"     ON public.users FOR INSERT WITH CHECK (public.current_user_role() = 'fleet_manager');
CREATE POLICY "users_update_manager"     ON public.users FOR UPDATE USING (public.current_user_role() = 'fleet_manager');
CREATE POLICY "users_delete_manager"     ON public.users FOR DELETE USING (public.current_user_role() = 'fleet_manager');

-- ---- vehicles ----
CREATE POLICY "vehicles_select_all"     ON public.vehicles FOR SELECT USING (TRUE);
CREATE POLICY "vehicles_modify_manager" ON public.vehicles FOR ALL   USING (public.current_user_role() = 'fleet_manager');

-- ---- trips ----
CREATE POLICY "trips_select_own_driver" ON public.trips FOR SELECT USING (driver_id = auth.uid());
CREATE POLICY "trips_select_manager"    ON public.trips FOR SELECT USING (public.current_user_role() = 'fleet_manager');
CREATE POLICY "trips_insert_manager"    ON public.trips FOR INSERT WITH CHECK (public.current_user_role() = 'fleet_manager');
CREATE POLICY "trips_update_driver"     ON public.trips FOR UPDATE USING (driver_id = auth.uid() AND status IN ('assigned','started')) WITH CHECK (driver_id = auth.uid() AND status IN ('assigned','started','completed'));
CREATE POLICY "trips_update_manager"    ON public.trips FOR UPDATE USING (public.current_user_role() = 'fleet_manager');
CREATE POLICY "trips_delete_manager"    ON public.trips FOR DELETE USING (public.current_user_role() = 'fleet_manager');

-- ---- vehicle_inspections ----
CREATE POLICY "inspections_select_manager"    ON public.vehicle_inspections FOR SELECT USING (public.current_user_role() = 'fleet_manager');
CREATE POLICY "inspections_select_own_driver" ON public.vehicle_inspections FOR SELECT USING (driver_id = auth.uid());
CREATE POLICY "inspections_insert_driver"     ON public.vehicle_inspections FOR INSERT WITH CHECK (driver_id = auth.uid());

-- ---- maintenance_tasks ----
CREATE POLICY "maintenance_select_manager"  ON public.maintenance_tasks FOR SELECT USING (public.current_user_role() = 'fleet_manager');
CREATE POLICY "maintenance_select_own"      ON public.maintenance_tasks FOR SELECT USING (assigned_to = auth.uid());
CREATE POLICY "maintenance_insert_manager"  ON public.maintenance_tasks FOR INSERT WITH CHECK (public.current_user_role() = 'fleet_manager');
CREATE POLICY "maintenance_update_assigned" ON public.maintenance_tasks FOR UPDATE USING (assigned_to = auth.uid());
CREATE POLICY "maintenance_update_manager"  ON public.maintenance_tasks FOR UPDATE USING (public.current_user_role() = 'fleet_manager');

-- ---- work_orders ----
CREATE POLICY "work_orders_select_manager"  ON public.work_orders FOR SELECT USING (public.current_user_role() = 'fleet_manager');
CREATE POLICY "work_orders_select_assigned" ON public.work_orders FOR SELECT USING (assigned_to = auth.uid());
CREATE POLICY "work_orders_insert_manager"  ON public.work_orders FOR INSERT WITH CHECK (public.current_user_role() = 'fleet_manager');
CREATE POLICY "work_orders_update_assigned" ON public.work_orders FOR UPDATE USING (assigned_to = auth.uid());

-- ---- messages ----
DROP POLICY IF EXISTS "messages_select_own" ON public.messages;
CREATE POLICY "messages_select_policy" ON public.messages FOR SELECT USING (
    sender_id = auth.uid() OR 
    receiver_id = auth.uid() OR 
    (SELECT role FROM public.users WHERE id = auth.uid()) = 'fleet_manager'
);
CREATE POLICY "messages_insert_own" ON public.messages FOR INSERT WITH CHECK (sender_id = auth.uid());

-- ---- notifications ----
CREATE POLICY "notifications_select_own" ON public.notifications FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "notifications_update_own" ON public.notifications FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "notifications_insert_own" ON public.notifications FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "notifications_select_manager" ON public.notifications FOR SELECT USING (public.current_user_role() = 'fleet_manager');
DROP POLICY IF EXISTS "notifications_insert_manager" ON public.notifications;
CREATE POLICY "notifications_insert_manager" ON public.notifications FOR INSERT WITH CHECK (public.current_user_role() = 'fleet_manager');
DROP POLICY IF EXISTS "notifications_insert_to_manager" ON public.notifications;
CREATE POLICY "notifications_insert_to_manager" ON public.notifications FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE id = user_id AND role = 'fleet_manager'
    )
);

-- ---- defect_reports ----
DROP POLICY IF EXISTS "defect_reports_select_all" ON public.defect_reports;
CREATE POLICY "defect_reports_select_all" ON public.defect_reports FOR SELECT USING (TRUE);
DROP POLICY IF EXISTS "defect_reports_insert_driver" ON public.defect_reports;
CREATE POLICY "defect_reports_insert_driver" ON public.defect_reports FOR INSERT WITH CHECK (reported_by = auth.uid());
DROP POLICY IF EXISTS "defect_reports_update_all" ON public.defect_reports;
CREATE POLICY "defect_reports_update_all" ON public.defect_reports FOR UPDATE USING (TRUE);
DROP POLICY IF EXISTS "defect_reports_delete_manager" ON public.defect_reports;
CREATE POLICY "defect_reports_delete_manager" ON public.defect_reports FOR DELETE USING (public.current_user_role() = 'fleet_manager');

-- ---- vehicle_locations ----
CREATE POLICY "locations_select_manager" ON public.vehicle_locations FOR SELECT USING (public.current_user_role() = 'fleet_manager');
CREATE POLICY "locations_insert_driver"  ON public.vehicle_locations FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.vehicles WHERE id = vehicle_id AND assigned_driver_id = auth.uid())
);

-- ---- sos_alerts ----
CREATE POLICY "sos_alerts_select_all" ON public.sos_alerts FOR SELECT USING (TRUE);
CREATE POLICY "sos_alerts_insert_driver" ON public.sos_alerts FOR INSERT WITH CHECK (driver_id = auth.uid());
CREATE POLICY "sos_alerts_update_all" ON public.sos_alerts FOR UPDATE USING (TRUE);

-- ---- inventory ----
CREATE POLICY "inventory_select_all" ON public.inventory FOR SELECT USING (TRUE);
CREATE POLICY "inventory_modify_manager" ON public.inventory FOR ALL USING (public.current_user_role() = 'fleet_manager');
CREATE POLICY "inventory_modify_maintenance" ON public.inventory FOR ALL USING (public.current_user_role() = 'maintenance');

-- ---- maintenance_records ----
CREATE POLICY "maintenance_records_select_all" ON public.maintenance_records FOR SELECT USING (TRUE);
CREATE POLICY "maintenance_records_modify_all" ON public.maintenance_records FOR ALL USING (
    public.current_user_role() = 'fleet_manager' OR 
    public.current_user_role() = 'maintenance'
);


-- ============================================================
-- 5. REALTIME SUBSCRIPTIONS
-- ============================================================

ALTER PUBLICATION supabase_realtime ADD TABLE public.trips;
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.vehicle_locations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.maintenance_tasks;

ALTER PUBLICATION supabase_realtime ADD TABLE public.sos_alerts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.inventory;
ALTER PUBLICATION supabase_realtime ADD TABLE public.maintenance_records;


-- ============================================================
-- 6. HELPER VIEWS
-- ============================================================

-- Active trips with vehicle + driver info
CREATE OR REPLACE VIEW public.v_active_trips AS
SELECT t.id, t.source, t.destination, t.start_time, t.distance, t.status, t.notes,
       v.vehicle_number, v.model, v.license_plate,
       u.name AS driver_name, u.phone_number AS driver_phone
FROM public.trips t
JOIN public.vehicles v ON v.id = t.vehicle_id
JOIN public.users    u ON u.id = t.driver_id
WHERE t.status IN ('assigned', 'started');

-- Unread notification count per user
CREATE OR REPLACE VIEW public.v_unread_notification_count AS
SELECT user_id, COUNT(*) AS unread_count
FROM public.notifications
WHERE is_read = FALSE
GROUP BY user_id;

-- Latest location per vehicle
CREATE OR REPLACE VIEW public.v_latest_vehicle_location AS
SELECT DISTINCT ON (vehicle_id) id, vehicle_id, latitude, longitude, timestamp
FROM public.vehicle_locations
ORDER BY vehicle_id, timestamp DESC;

-- Open work orders with vehicle + assignee info
CREATE OR REPLACE VIEW public.v_open_work_orders AS
SELECT wo.id, wo.issue_description, wo.priority, wo.status, wo.created_at,
       v.vehicle_number, v.license_plate,
       u.name AS assigned_to_name
FROM public.work_orders wo
JOIN public.vehicles v ON v.id = wo.vehicle_id
JOIN public.users    u ON u.id = wo.assigned_to
WHERE wo.status IN ('open', 'in_progress');


-- ============================================================
-- 7. SAMPLE CRUD QUERIES  (self-contained, no placeholder UUIDs)
-- ============================================================
-- All queries below are wrapped in a single DO $$ block so that
-- UUID values are declared as variables once and reused safely.
-- Simply run the entire block in the Supabase SQL Editor.
-- ============================================================

DO $$
DECLARE
    v_manager_id   UUID := gen_random_uuid();
    v_driver_id    UUID := gen_random_uuid();
    v_mechanic_id  UUID := gen_random_uuid();
    v_vehicle_id   UUID := gen_random_uuid();
    v_trip_id      UUID := gen_random_uuid();
    v_task_id      UUID := gen_random_uuid();
    v_work_order_id UUID := gen_random_uuid();
    v_message_id   UUID := gen_random_uuid();
    v_notif_id     UUID := gen_random_uuid();
    v_location_id  UUID := gen_random_uuid();
    v_inspection_id UUID := gen_random_uuid();
BEGIN

    -- ── 1. Seed Users ──────────────────────────────────────────
    INSERT INTO public.users (id, name, email, role, phone_number)
    VALUES
        (v_manager_id,  'Alice Manager',  'alice@fms.com',   'fleet_manager', '+910000000001'),
        (v_driver_id,   'Bob Driver',     'bob@fms.com',     'driver',        '+910000000002'),
        (v_mechanic_id, 'Carol Mechanic', 'carol@fms.com',   'maintenance',   '+910000000003');

    -- ── 2. Seed Vehicle ────────────────────────────────────────
    INSERT INTO public.vehicles
        (id, vehicle_number, model, manufacturer, year, vin, license_plate, status, assigned_driver_id)
    VALUES
        (v_vehicle_id, 'VH-001', 'Transit 350', 'Ford', 2022,
         '1FTBF2B60KKA12345', 'MH12AB1234', 'in_use', v_driver_id);

    -- ── 3. Create a Trip ───────────────────────────────────────
    INSERT INTO public.trips
        (id, vehicle_id, driver_id, source, destination, status, distance)
    VALUES
        (v_trip_id, v_vehicle_id, v_driver_id, 'Mumbai', 'Pune', 'assigned', 0);

    -- ── 4. Start the Trip ──────────────────────────────────────
    UPDATE public.trips
    SET status = 'started', start_time = NOW()
    WHERE id = v_trip_id;

    -- ── 5. Complete the Trip ───────────────────────────────────
    UPDATE public.trips
    SET status = 'completed', end_time = NOW(), distance = 148.5
    WHERE id = v_trip_id;

    -- ── 6. Submit a Vehicle Inspection ─────────────────────────
    INSERT INTO public.vehicle_inspections
        (id, vehicle_id, driver_id, checklist, defects, status)
    VALUES
        (v_inspection_id, v_vehicle_id, v_driver_id,
         ARRAY['Brakes OK', 'Tyres OK', 'Lights OK', 'Engine Oil OK'],
         NULL, 'passed');

    -- ── 7. Create a Maintenance Task ───────────────────────────
    INSERT INTO public.maintenance_tasks
        (id, vehicle_id, assigned_to, service_type, due_date, status)
    VALUES
        (v_task_id, v_vehicle_id, v_mechanic_id,
         'Oil Change', NOW() + INTERVAL '7 days', 'pending');

    -- ── 8. Update Maintenance Task to In-Progress ──────────────
    UPDATE public.maintenance_tasks
    SET status = 'in_progress'
    WHERE id = v_task_id;

    -- ── 9. Create a Work Order ─────────────────────────────────
    INSERT INTO public.work_orders
        (id, vehicle_id, created_by, assigned_to, priority, issue_description, status)
    VALUES
        (v_work_order_id, v_vehicle_id, v_manager_id, v_mechanic_id,
         'high', 'Front brake pads worn out, immediate replacement needed.', 'open');

    -- ── 10. Send a Message (manager → driver) ──────────────────
    INSERT INTO public.messages
        (id, sender_id, receiver_id, message)
    VALUES
        (v_message_id, v_manager_id, v_driver_id,
         'Please complete the pre-trip inspection before departure.');

    -- ── 11. Push a Notification to Driver ──────────────────────
    INSERT INTO public.notifications
        (id, user_id, title, message, type)
    VALUES
        (v_notif_id, v_driver_id,
         'Trip Assigned',
         'You have a new trip: Mumbai → Pune. Depart by 09:00.',
         'trip');

    -- ── 12. Mark Notification as Read ──────────────────────────
    UPDATE public.notifications
    SET is_read = TRUE
    WHERE id = v_notif_id;

    -- ── 13. Log Vehicle GPS Location ───────────────────────────
    INSERT INTO public.vehicle_locations
        (id, vehicle_id, latitude, longitude)
    VALUES
        (v_location_id, v_vehicle_id, 19.0760, 72.8777);

    RAISE NOTICE 'Seed data inserted successfully.';
    RAISE NOTICE '  manager_id   = %', v_manager_id;
    RAISE NOTICE '  driver_id    = %', v_driver_id;
    RAISE NOTICE '  mechanic_id  = %', v_mechanic_id;
    RAISE NOTICE '  vehicle_id   = %', v_vehicle_id;
    RAISE NOTICE '  trip_id      = %', v_trip_id;

END $$;


-- ============================================================
-- 7b. READ QUERIES  (run individually after the DO block above)
-- ============================================================

-- Fleet status summary (dashboard)
SELECT status, COUNT(*) AS total
FROM public.vehicles
GROUP BY status
ORDER BY status;

-- All active trips with driver + vehicle details
SELECT * FROM public.v_active_trips;

-- Latest GPS location per vehicle
SELECT * FROM public.v_latest_vehicle_location;

-- Open / in-progress work orders
SELECT * FROM public.v_open_work_orders;

-- Unread notification counts per user
SELECT * FROM public.v_unread_notification_count;

-- Overdue maintenance tasks
SELECT mt.id, mt.service_type, mt.due_date, v.vehicle_number, u.name AS assigned_to
FROM public.maintenance_tasks mt
JOIN public.vehicles v ON v.id = mt.vehicle_id
JOIN public.users    u ON u.id = mt.assigned_to
WHERE mt.due_date < NOW()
  AND mt.status != 'completed'
ORDER BY mt.due_date ASC;

-- Conversation between two users
-- Replace the UUIDs below with real ones from your users table:
-- SELECT * FROM public.messages
-- WHERE (sender_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
--        AND receiver_id = 'yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy')
--    OR (sender_id = 'yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy'
--        AND receiver_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx')
-- ORDER BY timestamp ASC;

-- ============================================================
-- 8. SCHEMA UPDATES FOR NEW SYSTEM FEATURES
-- ============================================================

-- 1. Create sos_alerts table
CREATE TABLE IF NOT EXISTS public.sos_alerts (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id   UUID        NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    vehicle_id  UUID,
    trip_id     UUID,
    latitude    DOUBLE PRECISION NOT NULL,
    longitude   DOUBLE PRECISION NOT NULL,
    message     TEXT,
    status      TEXT NOT NULL DEFAULT 'active',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Create inventory table
CREATE TABLE IF NOT EXISTS public.inventory (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    part_name          TEXT        NOT NULL,
    part_number        TEXT        NOT NULL UNIQUE,
    quantity_in_stock  INTEGER     NOT NULL DEFAULT 0,
    reorder_threshold  INTEGER     NOT NULL DEFAULT 0,
    unit_cost          NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    supplier_name      TEXT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Create maintenance_records table
CREATE TABLE IF NOT EXISTS public.maintenance_records (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id    UUID        NOT NULL REFERENCES public.vehicles (id) ON DELETE CASCADE,
    work_order_id UUID                 REFERENCES public.work_orders (id) ON DELETE SET NULL,
    service_type  TEXT        NOT NULL,
    service_date  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    cost          NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (cost >= 0),
    notes         TEXT,
    repair_images TEXT[],
    performed_by  UUID        NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Create Indexes
CREATE INDEX IF NOT EXISTS idx_sos_alerts_driver ON public.sos_alerts (driver_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_records_vehicle ON public.maintenance_records (vehicle_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_records_date ON public.maintenance_records (service_date DESC);

-- 5. Enable Row Level Security (RLS)
ALTER TABLE public.sos_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_records ENABLE ROW LEVEL SECURITY;

-- 6. Add RLS Policies
CREATE POLICY "sos_alerts_select_all" ON public.sos_alerts FOR SELECT USING (TRUE);
CREATE POLICY "sos_alerts_insert_driver" ON public.sos_alerts FOR INSERT WITH CHECK (driver_id = auth.uid());
CREATE POLICY "sos_alerts_update_all" ON public.sos_alerts FOR UPDATE USING (TRUE);

CREATE POLICY "inventory_select_all" ON public.inventory FOR SELECT USING (TRUE);
CREATE POLICY "inventory_modify_manager" ON public.inventory FOR ALL USING (public.current_user_role() = 'fleet_manager');
CREATE POLICY "inventory_modify_maintenance" ON public.inventory FOR ALL USING (public.current_user_role() = 'maintenance');

CREATE POLICY "maintenance_records_select_all" ON public.maintenance_records FOR SELECT USING (TRUE);
CREATE POLICY "maintenance_records_modify_all" ON public.maintenance_records FOR ALL USING (
    public.current_user_role() = 'fleet_manager' OR 
    public.current_user_role() = 'maintenance'
);

-- 7. Add Tables to Realtime Publication
ALTER PUBLICATION supabase_realtime ADD TABLE public.sos_alerts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.inventory;
ALTER PUBLICATION supabase_realtime ADD TABLE public.maintenance_records;

-- 8. Add Storage Bucket (Avatars) and Policies
INSERT INTO storage.buckets (id, name, public) 
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Public Avatar Access" ON storage.objects FOR SELECT USING (bucket_id = 'avatars');
CREATE POLICY "Insert own avatar" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'avatars');
CREATE POLICY "Update own avatar" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'avatars');

-- 9. Add Storage Bucket (Maintenance Images) and Policies
INSERT INTO storage.buckets (id, name, public) 
VALUES ('maintenance-images', 'maintenance-images', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Public Maintenance Image Access" ON storage.objects FOR SELECT USING (bucket_id = 'maintenance-images');
CREATE POLICY "Insert maintenance image" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'maintenance-images');
CREATE POLICY "Update maintenance image" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'maintenance-images');

-- 10. Add repair_images column to maintenance_records if it doesn't exist
ALTER TABLE public.maintenance_records ADD COLUMN IF NOT EXISTS repair_images TEXT[];
