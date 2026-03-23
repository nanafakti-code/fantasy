// Supabase Edge Function: calcular-puntos-jornada
// Invocación: POST /functions/v1/calcular-puntos-jornada
// Body: { "liga_id": "...", "jornada_id": "..." }
// Auth: solo administradores (service_role)

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      { auth: { persistSession: false } }
    );

    const { liga_id, jornada_id } = await req.json();

    if (!liga_id || !jornada_id) {
      return new Response(
        JSON.stringify({ error: "Se requieren liga_id y jornada_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Llamar a la función PL/pgSQL que calcula los puntos
    const { error } = await supabaseAdmin.rpc("calcular_puntos_jornada_liga", {
      p_liga_id: liga_id,
      p_jornada_id: jornada_id,
    });

    if (error) throw error;

    // Obtener la clasificación actualizada para devolver al cliente
    const { data: clasificacion } = await supabaseAdmin
      .from("vista_clasificacion")
      .select("*")
      .eq("liga_id", liga_id)
      .order("posicion");

    return new Response(
      JSON.stringify({
        success: true,
        mensaje: "Puntos calculados y clasificación actualizada",
        clasificacion,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
