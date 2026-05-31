// supabase/functions/spare-parts-forecast/index.ts
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

    const ninetyDaysAgo = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString();
    const thirtyDaysFromNow = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();

    const [{ data: inventory }, { data: records }, { data: upcomingTasks }] =
      await Promise.all([
        supabase.from("inventory").select("id, part_name, part_number, quantity_in_stock, reorder_threshold, unit_cost"),
        supabase.from("maintenance_records").select("vehicle_id, service_type, service_date").gt("service_date", ninetyDaysAgo),
        supabase.from("maintenance_tasks").select("id, vehicle_id, service_type, due_date").lt("due_date", thirtyDaysFromNow).eq("status", "pending"),
      ]);

    // Count service type frequency from records
    const serviceFrequency: Record<string, number> = {};
    for (const r of records ?? []) {
      serviceFrequency[r.service_type] = (serviceFrequency[r.service_type] ?? 0) + 1;
    }

    const prompt = `
You are a spare parts inventory analyst for a vehicle fleet maintenance team.

Current inventory:
${JSON.stringify(inventory)}

Service frequency in last 90 days (service_type → count):
${JSON.stringify(serviceFrequency)}

Upcoming scheduled maintenance tasks (next 30 days):
${JSON.stringify(upcomingTasks)}

For each inventory item:
1. Estimate how many units will be needed in the next 30 days based on scheduled tasks and historical usage.
2. Flag items where predicted demand exceeds current stock (stockout risk).
3. Recommend a reorder quantity for at-risk items.

Return JSON:
{
  "forecasts": [
    {
      "partId": "<inventory item id>",
      "partName": "<name>",
      "currentStock": <number>,
      "predictedDemand": <number>,
      "stockoutRisk": <true|false>,
      "recommendedReorder": <number>,
      "urgency": "low" | "medium" | "high"
    }
  ],
  "summary": "<2 sentence summary of overall inventory health>"
}
`;

    const text = await callGemini(prompt, true);
    const result = JSON.parse(text);

    // Save to spare_parts_forecasts table
    const { data: saved } = await supabase
      .from("spare_parts_forecasts")
      .insert({ forecasts: result.forecasts })
      .select()
      .single();

    return new Response(JSON.stringify({ ...result, id: saved?.id }), {
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
});
