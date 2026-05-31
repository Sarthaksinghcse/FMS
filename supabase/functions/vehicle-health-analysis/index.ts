// supabase/functions/vehicle-health-analysis/index.ts
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

    const [{ data: vehicles }, { data: defects }, { data: records }, { data: inspections }] =
      await Promise.all([
        supabase.from("vehicles").select("id, vehicle_number, model, year, last_service_date, next_service_date, odometer_reading, status"),
        supabase.from("defect_reports").select("id, vehicle_id, title, severity, status").eq("status", "open"),
        supabase.from("maintenance_records").select("vehicle_id, service_type, service_date, cost").order("service_date", { ascending: false }).limit(300),
        supabase.from("vehicle_inspections").select("vehicle_id, inspection_date, overall_status").order("inspection_date", { ascending: false }).limit(100),
      ]);

    // Only analyze vehicles with issues (skip healthy ones to save tokens)
    const prompt = `
You are a vehicle health expert for a commercial fleet.

Analyze the health of each vehicle and provide a brief health summary.

Vehicles:
${JSON.stringify(vehicles)}

Open defect reports:
${JSON.stringify(defects)}

Recent maintenance records (last 300):
${JSON.stringify(records)}

Recent inspections:
${JSON.stringify(inspections)}

For each vehicle, provide:
- vehicleId
- summary: 1-2 sentence health assessment
- predictedIssues: array of potential issues in next 30 days (empty array if healthy)
- maintenanceTasks: array of specific tasks to schedule now (empty if none needed)

Focus on vehicles that need attention. For healthy vehicles, just confirm good health.

Return JSON:
{
  "analyses": [
    {
      "vehicleId": "<uuid>",
      "summary": "<1-2 sentences>",
      "predictedIssues": ["<issue>"],
      "maintenanceTasks": ["<task>"]
    }
  ]
}
`;

    const text = await callGemini(prompt, true);
    const { analyses } = JSON.parse(text);

    // Upsert health scores into vehicle_health_scores table
    if (analyses?.length) {
      for (const analysis of analyses) {
        await supabase.from("vehicle_health_scores").upsert({
          vehicle_id: analysis.vehicleId,
          health_score: 75,           // Base score — refined by Swift local algorithm
          health_grade: "good",       // Refined by Swift
          suggested_tasks: analysis.maintenanceTasks,
          llm_summary: analysis.summary,
          analyzed_at: new Date().toISOString(),
        }, { onConflict: "vehicle_id" });
      }
    }

    return new Response(JSON.stringify({ analyses }), {
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
});
