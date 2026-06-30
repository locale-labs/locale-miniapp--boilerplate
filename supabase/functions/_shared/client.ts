// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment

// Setup type definitions for built-in Supabase Runtime APIs
// deno-lint-ignore no-unversioned-import no-import-prefix
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, SupabaseClient } from "@supabase/supabase-js";

import { Database } from "../../../_shared/supabase/db.types.ts";
import { response500_internal_server_error } from "./responses.ts";

export const createSupabaseAdminClient = ():
  | {
      error: null;
      client: SupabaseClient<Database>;
    }
  | {
      error: Response;
      client: null;
    } => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!supabaseUrl || !serviceRoleKey) {
      return {
        error: response500_internal_server_error(
          new Error("Missing Supabase environment variables")
        ),
        client: null,
      };
    }

    return {
      error: null,
      client: createClient<Database>(supabaseUrl, serviceRoleKey, {
        auth: { persistSession: false, autoRefreshToken: false },
      }),
    };
  } catch (error) {
    return { error: response500_internal_server_error(error), client: null };
  }
};
