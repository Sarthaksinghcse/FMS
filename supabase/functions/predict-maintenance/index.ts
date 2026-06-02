// supabase/functions/predict-maintenance/index.ts
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

    // Fetch all needed operational and inspection data in parallel
    const [
      { data: vehicles },
      { data: defects },
      { data: records },
      { data: inspections },
      { data: trips }
    ] = await Promise.all([
      supabase.from("vehicles").select("id, vehicle_number, last_service_date, next_service_date, status, odometer_reading"),
      supabase.from("defect_reports").select("id, vehicle_id, title, severity, status, defect_description, created_at"),
      supabase.from("maintenance_records").select("id, vehicle_id, service_type, service_date, cost, notes").order("service_date", { ascending: false }).limit(200),
      supabase.from("vehicle_inspections").select("id, vehicle_id, defects, status, inspection_date").order("inspection_date", { ascending: false }).limit(200),
      supabase.from("trips").select("id, vehicle_id, distance, status, created_at").order("created_at", { ascending: false }).limit(200),
    ]);

    const prompt = `
You are a predictive fleet maintenance expert. Analyze the following real-time and historical operational fleet data to identify which vehicles are at risk of breakdown in the next 30 days.

Base your analysis and predictions strictly on these factors:
1. **Pre and Post-Trip Defects**: Active defects reported in inspections (vehicle_inspections) and direct defect reports (defect_reports). Look for safety-critical components (brakes, tires, engine, steering).
2. **Mileage & Odometer Run**: How much the vehicle has run (odometer_reading from vehicles) and the frequency of trips (from trips table). Higher mileage and intensive short/long trips accelerate component wear.
3. **Service History**: Historical records (maintenance_records) vs. elapsed time since last service, and pending service schedules (next_service_date).

Vehicles list:
${JSON.stringify(vehicles)}

Defect Reports:
${JSON.stringify(defects)}

Vehicle Pre/Post-Trip Inspections (recent 200):
${JSON.stringify(inspections)}

Recent Trips (recent 200):
${JSON.stringify(trips)}

Recent Maintenance Records (recent 200):
${JSON.stringify(records)}

For each AT-RISK vehicle, determine a detailed breakdown risk and return:
- vehicleId: The exact vehicle ID
- riskLevel: "medium" | "high" | "critical" based on severity of defects and run distance
- explanation: A detailed, factual explanation of why this vehicle is at risk (e.g. mention specific pre/post-trip defects, run mileage, or service interval)
- recommendedAction: clear, actionable maintenance task to schedule (e.g. "Schedule immediate brake inspection and replacement" or "Perform oil filter service")

Only return predictions for vehicles with active risks. If a vehicle is healthy, omit it.

Return ONLY a valid JSON object matching this structure:
{ 
  "alerts": [
    { 
      "vehicleId": "UUID", 
      "riskLevel": "medium" | "high" | "critical", 
      "explanation": "text", 
      "recommendedAction": "text" 
    }
  ] 
}
`;

    const text = await callGemini(prompt, true);
    const { alerts } = JSON.parse(text);

    // Resolve all existing active predictive alerts before inserting new ones
    await supabase
      .from("predictive_alerts")
      .update({ resolved_at: new Date().toISOString() })
      .is("resolved_at", null);

    // Save alerts to predictive_alerts table
    let insertedAlerts = [];
    if (alerts?.length) {
      const { data } = await supabase.from("predictive_alerts").insert(
        alerts.map((a: any) => ({
          vehicle_id: a.vehicleId,
          risk_level: a.riskLevel,
          risk_score: a.riskLevel === "critical" ? 0.9 : a.riskLevel === "high" ? 0.75 : 0.45,
          triggered_reasons: [a.explanation],
          suggested_action: a.recommendedAction,
          llm_explanation: a.explanation,
        }))
      ).select();
      insertedAlerts = data ?? [];
    }

    return new Response(JSON.stringify({ alerts: insertedAlerts }), {
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
});
