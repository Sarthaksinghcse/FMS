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
1. Identify top 3 vehicles with highest fuel consumption and explain likely causes (driver behavior, vehicle age, route type).
2. Give 3 specific, actionable fuel-saving recommendations for the fleet manager.
3. Estimate potential monthly cost savings (as a number) if high-consuming vehicles improve efficiency by 15%.

Return JSON:
{
  "insights": "<3–4 sentence narrative summary>",
  "estimatedSavings": <number>,
  "vehicles": [
    { "vehicleId": "<id>", "issue": "<cause of high consumption>", "recommendation": "<specific action>" }
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

    const responsePayload = saved ? {
      id: saved.id,
      insightsText: saved.insights_text,
      highConsumers: saved.high_consumers,
      estimatedSavings: saved.estimated_savings,
      generatedAt: saved.generated_at
    } : {
      insightsText: insight.insights,
      highConsumers: insight.vehicles,
      estimatedSavings: insight.estimatedSavings
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
