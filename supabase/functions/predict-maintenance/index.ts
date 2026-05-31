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

    // Fetch all needed data in parallel
    const [{ data: vehicles }, { data: defects }, { data: records }] =
      await Promise.all([
        supabase.from("vehicles").select("id, vehicle_number, last_service_date, next_service_date, status, odometer_reading"),
        supabase.from("defect_reports").select("id, vehicle_id, title, severity, status"),
        supabase.from("maintenance_records").select("id, vehicle_id, service_type, service_date").order("service_date", { ascending: false }).limit(200),
      ]);

    const prompt = `
You are a predictive fleet maintenance expert. Analyze this vehicle data and 
identify which vehicles are at risk of breakdown in the next 30 days.

Vehicles:
${JSON.stringify(vehicles)}

Open Defect Reports:
${JSON.stringify(defects?.filter(d => d.status === 'open'))}

Recent Maintenance Records (last 200):
${JSON.stringify(records)}

For each AT-RISK vehicle, return:
- vehicleId
- riskLevel: "medium" | "high" | "critical"
- explanation: 1-2 sentence explanation of the risk
- recommendedAction: specific action the fleet manager should take

Only include vehicles with medium/high/critical risk. Skip healthy vehicles.

Return JSON: { "alerts": [{ "vehicleId": "", "riskLevel": "", "explanation": "", "recommendedAction": "" }] }
`;

    const text = await callGemini(prompt, true);
    const { alerts } = JSON.parse(text);

    // Save alerts to predictive_alerts table
    if (alerts?.length) {
      await supabase.from("predictive_alerts").insert(
        alerts.map((a: any) => ({
          vehicle_id: a.vehicleId,
          risk_level: a.riskLevel,
          risk_score: a.riskLevel === "critical" ? 80 : a.riskLevel === "high" ? 60 : 30,
          triggered_reasons: [a.explanation],
          suggested_action: a.recommendedAction,
          llm_explanation: a.explanation,
        }))
      );
    }

    return new Response(JSON.stringify({ alerts, count: alerts?.length ?? 0 }), {
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
});
