import {
  response_cors_preflight,
  response200,
  response405_method_not_allowed,
  response500_internal_server_error,
} from "../_shared/responses.ts";

import { deployMiniapp } from "./deploy_miniapp.ts";

// Setup type definitions for built-in Supabase Runtime APIs
// deno-lint-ignore no-unversioned-import no-import-prefix
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return response_cors_preflight();
  }

  if (req.method !== "POST") {
    return response405_method_not_allowed();
  }

  try {
    const { data, error } = await deployMiniapp({ req });
    if (error) return error;

    return response200(data);
  } catch (error) {
    return response500_internal_server_error(error);
  }
});
