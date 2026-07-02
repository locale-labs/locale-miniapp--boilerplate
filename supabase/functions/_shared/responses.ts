// Nota: aca solo se usaba el TYPE `PostgrestError` (union `PostgrestError | unknown`),
// union que colapsa a `unknown` (sin efecto). La dependencia @supabase/supabase-js
// SI es real y sigue en uso: client.ts la importa (createClient) y se resuelve via
// el import map de deno.json (jsr:@supabase/supabase-js@2).
import { corsHeaders } from "./cors.ts";

const headers = { ...corsHeaders, "Content-Type": "application/json" };

const errorMessageOrUnknownError = (error: unknown) =>
  error instanceof Error ? error.message : "Unknown error";

export const response200 = (data: unknown) =>
  new Response(JSON.stringify(data), {
    headers,
    status: 200,
  });

export const response400_bad_request = (error: unknown) =>
  new Response(JSON.stringify({ error: errorMessageOrUnknownError(error) }), {
    headers,
    status: 400,
  });

export const response401_unauthorized = () =>
  new Response(JSON.stringify({ error: "Unauthorized" }), {
    headers,
    status: 401,
  });

export const response405_method_not_allowed = () =>
  new Response(JSON.stringify({ error: "Method not allowed" }), {
    headers,
    status: 405,
  });

export const response500_internal_server_error = (error: unknown) =>
  new Response(JSON.stringify({ error: errorMessageOrUnknownError(error) }), {
    headers,
    status: 500,
  });

// ─────────────────────────────────────────────────────────────────────

export const response_cors_preflight = () =>
  new Response("ok", { headers: corsHeaders });
