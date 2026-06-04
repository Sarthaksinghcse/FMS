// supabase/functions/estimate-work-order-cost/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { callGemini } from "../_shared/gemini.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
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

    const body = await req.json();
    const { issueDescription, vehicleId, vehicleInfo } = body;

    if (!issueDescription) {
      return new Response(
        JSON.stringify({ error: "issueDescription is required" }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // Fetch all inventory items so Gemini can match against real parts
    const { data: inventory } = await supabase
      .from("inventory")
      .select("id, part_name, part_number, unit_cost, quantity_in_stock")
      .gt("quantity_in_stock", 0);

    // Fetch vehicle details if vehicleId provided
    let vehicle = null;
    if (vehicleId) {
      const { data } = await supabase
        .from("vehicles")
        .select("vehicle_number, make, model, vehicle_type, fuel_type, odometer_reading")
        .eq("id", vehicleId)
        .single();
      vehicle = data;
    }

    // Build the inventory catalog for Gemini
    const inventoryCatalog = (inventory ?? []).map((item: any) => ({
      partName: item.part_name,
      partNumber: item.part_number,
      unitCost: item.unit_cost,
      inStock: item.quantity_in_stock,
    }));

    const prompt = `
You are an expert automotive maintenance cost estimator for a commercial fleet management system.

WORK ORDER DETAILS:
- Issue Description: ${issueDescription}
${vehicle ? `- Vehicle: ${vehicle.vehicle_number} (${vehicle.make} ${vehicle.model})` : ""}
${vehicle ? `- Vehicle Type: ${vehicle.vehicle_type || "Commercial"}` : ""}
${vehicle ? `- Fuel Type: ${vehicle.fuel_type || "diesel"}` : ""}
${vehicle ? `- Odometer: ${vehicle.odometer_reading || 0} km` : ""}
${vehicleInfo ? `- Additional Info: ${vehicleInfo}` : ""}

AVAILABLE SPARE PARTS INVENTORY (match from this list ONLY):
${JSON.stringify(inventoryCatalog, null, 2)}

TASKS:
1. Analyze the issue and determine which spare parts from the AVAILABLE INVENTORY are needed for this repair. Only suggest parts that exist in the inventory list above. Match by part name.
2. For each suggested part, specify the quantity needed (usually 1-2 for most parts, 4 for tire rotations, etc.).
3. Estimate labor hours required for this repair (be realistic based on industry standards for commercial vehicles).
4. Estimate additional/miscellaneous costs (shop supplies, disposal fees, diagnostic fees, fluid top-ups, etc.).

Return a JSON object in exactly this format:
{
  "suggestedParts": [
    {
      "partName": "<exact part name from inventory>",
      "quantity": <number>,
      "reason": "<why this part is needed>"
    }
  ],
  "laborHours": <number>,
  "laborReason": "<brief explanation of labor time estimate>",
  "additionalCosts": <number in INR>,
  "additionalReason": "<brief explanation of additional costs>"
}

IMPORTANT:
- Only suggest parts that EXACTLY match names in the available inventory
- If no spare parts are needed (e.g., software update, inspection only), return an empty suggestedParts array
- Labor hours should be realistic (0.5 to 8 hours typically)
- Additional costs should be in Indian Rupees (INR), typically ₹200-₹2000
- Be conservative and accurate with estimates
`;

    const text = await callGemini(prompt, true);
    const estimate = JSON.parse(text);

    // Validate and enrich suggested parts with actual DB prices
    const enrichedParts = [];
    for (const part of estimate.suggestedParts || []) {
      const dbPart = (inventory ?? []).find(
        (item: any) =>
          item.part_name.toLowerCase() === part.partName.toLowerCase()
      );
      if (dbPart) {
        enrichedParts.push({
          inventoryId: dbPart.id,
          partName: dbPart.part_name,
          partNumber: dbPart.part_number,
          unitCost: dbPart.unit_cost,
          inStock: dbPart.quantity_in_stock,
          quantity: Math.min(part.quantity || 1, dbPart.quantity_in_stock),
          reason: part.reason || "",
        });
      }
    }

    // Calculate totals
    const partsCost = enrichedParts.reduce(
      (sum: number, p: any) => sum + p.unitCost * p.quantity,
      0
    );
    const laborRate = 500; // ₹500/hr
    const laborHours = estimate.laborHours || 1;
    const laborCost = laborRate * laborHours;
    const additionalCosts = estimate.additionalCosts || 0;
    const totalEstimate = partsCost + laborCost + additionalCosts;

    const response = {
      suggestedParts: enrichedParts,
      laborHours: laborHours,
      laborReason: estimate.laborReason || "",
      laborRatePerHour: laborRate,
      laborCost: laborCost,
      additionalCosts: additionalCosts,
      additionalReason: estimate.additionalReason || "",
      partsCost: partsCost,
      totalEstimate: totalEstimate,
    };

    return new Response(JSON.stringify(response), {
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
});
