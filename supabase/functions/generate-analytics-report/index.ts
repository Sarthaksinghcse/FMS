// supabase/functions/generate-analytics-report/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { callGemini } from "../_shared/gemini.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Parse fleet snapshot if passed from client
    let fleetSnapshot = null;
    let bypassCache = false;

    if (req.method === "POST") {
      try {
        const body = await req.json();
        if (body && body.fleetSnapshot) {
          fleetSnapshot = body.fleetSnapshot;
          bypassCache = true;
          console.log("Using live local fleet snapshot provided by client:", JSON.stringify(fleetSnapshot));
        }
      } catch (e) {
        console.log("No valid JSON payload in request, falling back to database query:", e.message);
      }
    }

    if (!bypassCache) {
      // Check if a recent report already exists (< 6 hours old)
      const sixHoursAgo = new Date(Date.now() - 6 * 60 * 60 * 1000).toISOString();
      const { data: existing } = await supabase
        .from("ai_analytics_reports")
        .select("*")
        .gt("generated_at", sixHoursAgo)
        .order("generated_at", { ascending: false })
        .limit(1);

      if (existing?.length) {
        return new Response(JSON.stringify(existing[0]), {
          headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }
    }

    if (!fleetSnapshot) {
      // Aggregate fleet data from remote database
      const [
        { data: vehicles },
        { data: trips },
        { data: workOrders },
        { data: maintenance },
        { data: fuelLogs },
      ] = await Promise.all([
        supabase.from("vehicles").select("id, status, vehicle_type, fuel_type"),
        supabase.from("trips").select("id, status, created_at").order("created_at", { ascending: false }).limit(500),
        supabase.from("work_orders").select("id, priority, status"),
        supabase.from("maintenance_records").select("id, cost, service_date").order("service_date", { ascending: false }).limit(100),
        supabase.from("fuel_logs").select("id, litres, amount_paid, created_at").order("created_at", { ascending: false }).limit(200),
      ]);

      const now = new Date();
      const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

      fleetSnapshot = {
        totalVehicles: vehicles?.length ?? 0,
        activeVehicles: vehicles?.filter(v => v.status === "available").length ?? 0,
        vehiclesInMaintenance: vehicles?.filter(v => v.status === "maintenance").length ?? 0,
        tripsThisMonth: trips?.filter(t => new Date(t.created_at) > thirtyDaysAgo).length ?? 0,
        completedTrips: trips?.filter(t => t.status === "completed").length ?? 0,
        openWorkOrders: workOrders?.filter(wo => wo.status === "open").length ?? 0,
        urgentWorkOrders: workOrders?.filter(wo => wo.priority === "urgent").length ?? 0,
        maintenanceCostThisMonth: maintenance
          ?.filter(m => new Date(m.service_date) > thirtyDaysAgo)
          .reduce((sum, m) => sum + (m.cost ?? 0), 0) ?? 0,
        totalFuelSpend: fuelLogs
          ?.filter(f => new Date(f.created_at) > thirtyDaysAgo)
          .reduce((sum, f) => sum + (f.amount_paid ?? 0), 0) ?? 0,
        totalFuelLitres: fuelLogs
          ?.filter(f => new Date(f.created_at) > thirtyDaysAgo)
          .reduce((sum, f) => sum + (f.litres ?? 0), 0) ?? 0,
      };
    }

    const prompt = `
You are a fleet operations analyst. Generate a concise executive analytics report 
(250–300 words) for a fleet manager based on this last-30-days fleet data:

${JSON.stringify(fleetSnapshot, null, 2)}

Structure your report as:
1. **Fleet Health Overview** — overall status in 2 sentences
2. **Operational Highlights** — key metrics and what they indicate
3. **Cost Analysis** — maintenance and fuel spend observations
4. **Action Items** — top 3 specific, actionable recommendations
5. **Watch List** — any red flags needing immediate attention

Be direct, data-driven, and professional. Avoid generic advice.
`;

    const reportText = await callGemini(prompt, false);

    // Save to database
    const { data: saved } = await supabase
      .from("ai_analytics_reports")
      .insert({ report_text: reportText, fleet_snapshot: fleetSnapshot })
      .select()
      .single();

    return new Response(JSON.stringify(saved), {
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
});
