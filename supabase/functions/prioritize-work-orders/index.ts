// supabase/functions/prioritize-work-orders/index.ts

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

    // Fetch open work orders with high/urgent priority
    const { data: workOrders } = await supabase
      .from("work_orders")
      .select("id, priority, status, created_at, issue_description")
      .in("priority", ["high", "urgent"])
      .eq("status", "open")
      .limit(20);

    if (!workOrders?.length) {
      return new Response(JSON.stringify({ explanations: [] }), {
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    const prompt = `
You are a fleet operations expert. For each of these open high-priority work orders,
write a one-sentence explanation of why it should be addressed urgently.

Work Orders:
${JSON.stringify(workOrders, null, 2)}

Return JSON array:
[{ "id": "<uuid>", "urgencyExplanation": "<one sentence>" }]
`;

    const text = await callGemini(prompt, true);
    const explanations = JSON.parse(text);

    return new Response(JSON.stringify({ explanations }), {
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
});
