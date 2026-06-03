// supabase/functions/fuel-optimization-insights/index.ts
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

    // Read POST body if present
    let body = {};
    if (req.method === "POST") {
      try {
        body = await req.json();
      } catch (e) {
        // No body or invalid json
      }
    }
    const { vehicleId } = body;

    // Single Vehicle Optimization flow
    if (vehicleId) {
      const [{ data: fuelLogs }, { data: vehicle }, { data: trips }] = await Promise.all([
        supabase.from("fuel_logs").select("*").eq("vehicle_id", vehicleId).order("created_at", { ascending: false }),
        supabase.from("vehicles").select("*").eq("id", vehicleId).single(),
        supabase.from("trips").select("*").eq("vehicle_id", vehicleId).order("created_at", { ascending: false }).limit(10)
      ]);

      if (!vehicle) {
        return new Response(JSON.stringify({ error: "Vehicle not found" }), {
          status: 404,
          headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }

      const prompt = `
You are an expert fuel efficiency and commercial fleet optimization AI.
Analyze the following fuel and trip data for vehicle ${vehicle.vehicle_number} (${vehicle.make} ${vehicle.model}):

Vehicle Specs:
- Type: ${vehicle.vehicle_type || "Commercial Truck"}
- Fuel Type: ${vehicle.fuel_type || "diesel"}
- Current Odometer: ${vehicle.odometer_reading || 0} km

Fuel Logs (Last Refuels):
${JSON.stringify(fuelLogs, null, 2)}

Recent Trips (Patterns & Distances):
${JSON.stringify(trips?.map(t => ({ source: t.source, destination: t.destination, distance: t.distance, status: t.status })), null, 2)}

Tasks:
1. Analyze the vehicle's fuel consumption pattern (litres refueled, spend, frequency).
2. Identify likely issues causing inefficiency (e.g. idle times, sudden driving behaviors, potential mechanical maintenance required like fuel filter, tire pressure).
3. Provide 3 highly personalized, specific, and actionable optimization strategies for this vehicle.
4. Estimate potential monthly savings specifically for this vehicle.

Return a JSON object in this format:
{
  "vehicleNumber": "${vehicle.vehicle_number}",
  "totalSpend": ${fuelLogs?.reduce((sum, l) => sum + (l.amount_paid || 0), 0) || 0},
  "totalLitres": ${fuelLogs?.reduce((sum, l) => sum + (l.litres || 0), 0) || 0},
  "avgCostPerLitre": ${fuelLogs?.length ? (fuelLogs.reduce((sum, l) => sum + (l.amount_paid || 0), 0) / fuelLogs.reduce((sum, l) => sum + (l.litres || 0), 0)) : 0},
  "insights": "<3-4 sentence comprehensive and user-friendly explanation of usage patterns and current efficiency status>",
  "issues": [
    "<issue 1 description>",
    "<issue 2 description>"
  ],
  "recommendations": [
    "<specific actionable recommendation 1>",
    "<specific actionable recommendation 2>",
    "<specific actionable recommendation 3>"
  ],
  "estimatedSavings": <number of monthly savings in Rupees>
}
`;

      const text = await callGemini(prompt, true);
      const insight = JSON.parse(text);

      return new Response(JSON.stringify(insight), {
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // Fleet-wide optimization flow (original logic)
    // Check cache (6-hour window)
    const sixHoursAgo = new Date(Date.now() - 6 * 60 * 60 * 1000).toISOString();
    const { data: cached } = await supabase
      .from("ai_fuel_insights")
      .select("*")
      .gt("generated_at", sixHoursAgo)
      .order("generated_at", { ascending: false })
      .limit(1);

    if (cached?.length) {
      return new Response(JSON.stringify(cached[0]), {
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();

    const [{ data: fuelLogs }, { data: vehicles }] = await Promise.all([
      supabase.from("fuel_logs").select("*").gt("created_at", thirtyDaysAgo),
      supabase.from("vehicles").select("id, vehicle_number, vehicle_type, fuel_type"),
    ]);

    // Aggregate per vehicle for the prompt
    const vehicleMap = Object.fromEntries((vehicles ?? []).map(v => [v.id, v]));
    const grouped: Record<string, any> = {};
    for (const log of fuelLogs ?? []) {
      if (!log.vehicle_id) continue;
      const vid = log.vehicle_id;
      if (!grouped[vid]) {
        grouped[vid] = { vehicleNumber: vehicleMap[vid]?.vehicle_number, vehicleType: vehicleMap[vid]?.vehicle_type, totalLitres: 0, totalSpend: 0, logCount: 0 };
      }
      grouped[vid].totalLitres += log.litres ?? 0;
      grouped[vid].totalSpend  += log.amount_paid ?? 0;
      grouped[vid].logCount    += 1;
    }

    const vehicleStats = Object.entries(grouped).map(([id, stats]) => ({ vehicleId: id, ...stats }));
    const fleetAvgSpend = vehicleStats.reduce((s, v) => s + v.totalSpend, 0) / (vehicleStats.length || 1);

    const prompt = `
You are a fuel efficiency expert for a commercial vehicle fleet.

Fleet fuel data (last 30 days) by vehicle:
${JSON.stringify(vehicleStats, null, 2)}

Fleet average monthly fuel spend per vehicle: ${fleetAvgSpend.toFixed(2)}

Tasks:
1. Identify vehicles with the highest fuel consumption from the provided fleet fuel data list (up to 3). Only include real vehicles that exist in the provided list. Do NOT invent or make up any vehicle IDs, and do NOT output generic placeholders like 'N/A'. If there are fewer than 3 vehicles in the list, only return the ones that actually exist. If no vehicles have high consumption, return an empty array.
2. Give specific, actionable fuel-saving recommendations for the fleet manager.
3. Estimate potential monthly cost savings (as a number) if high-consuming vehicles improve efficiency by 15%.

Return JSON:
{
  "insights": "<3–4 sentence narrative summary>",
  "estimatedSavings": <number>,
  "vehicles": [
    { "vehicleId": "<id from the fleet data list>", "issue": "<cause of high consumption>", "recommendation": "<specific action>" }
  ]
}
`;

    const text = await callGemini(prompt, true);
    const insight = JSON.parse(text);

    const { data: saved } = await supabase
      .from("ai_fuel_insights")
      .insert({
        insights_text: insight.insights,
        high_consumers: insight.vehicles,
        estimated_savings: insight.estimatedSavings,
      })
      .select()
      .single();

    const responsePayload = {
      id: saved?.id,
      insights_text: saved?.insights_text ?? insight.insights,
      high_consumers: (saved?.high_consumers ?? insight.vehicles).map((v: any) => ({
        vehicle_id: v.vehicleId ?? v.vehicle_id,
        issue: v.issue,
        recommendation: v.recommendation
      })),
      estimated_savings: saved?.estimated_savings ?? insight.estimatedSavings,
      generated_at: saved?.generated_at
    };

    return new Response(JSON.stringify(responsePayload), {
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
});
