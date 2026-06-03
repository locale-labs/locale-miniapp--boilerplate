// TODO: next step -> extract all of this code to outside miniapps (easy to maintain and error prone code)

import {
  response400_bad_request,
  response500_internal_server_error,
  response401_unauthorized,
} from "../_shared/responses.ts";
import { createSupabaseAdminClient } from "../_shared/client.ts";

interface DeployMiniappParams {
  version: string;
  git_sha?: string | null;
  html_content: string;
  env?: "dev" | "prod";
}

export const deployMiniapp = async ({
  req,
}: {
  req: Request;
}): Promise<
  | {
    error: null;
    data: { success: boolean; message: string; url: string };
  }
  | {
    error: Response;
    data: null;
  }
> => {
  // ── Get request body ─────────────────────────────────────────────────────
  let body: DeployMiniappParams;
  try {
    body = await req.json();
  } catch (_e) {
    return {
      data: null,
      error: response400_bad_request(new Error("Invalid JSON body")),
    };
  }

  const { version, git_sha, html_content, env = "prod" } = body;
  const registeredVersion = git_sha ? `${version}+${git_sha}` : version;

  if (!version || !html_content) {
    return {
      data: null,
      error: response400_bad_request(
        new Error("Missing version or html_content")
      ),
    };
  }

  // ── Validate API Key (Deploy Token) ──────────────────────────────────────
  const apiKey = req.headers.get("x-miniapp-api-key");
  const validApiKey = Deno.env.get("MINIAPP_API_KEY");

  if (!apiKey || !validApiKey || apiKey !== validApiKey) {
    return {
      data: null,
      error: response401_unauthorized(),
    };
  }

  // ── Get Supabase admin client (MiniApp) ──────────────────────────────────
  const { error: adminError, client: supabaseAdmin } =
    createSupabaseAdminClient();
  if (adminError) {
    return { data: null, error: adminError };
  }

  // ── Upload to Storage ────────────────────────────────────────────────────
  const storagePath = `builds/${registeredVersion}/index.html`;
  const { error: uploadError } = await supabaseAdmin.storage
    .from("miniapp-builds")
    .upload(storagePath, html_content, {
      contentType: "text/html",
      upsert: true,
    });

  if (uploadError) {
    return {
      data: null,
      error: response500_internal_server_error(uploadError),
    };
  }

  const {
    data: { publicUrl },
  } = supabaseAdmin.storage.from("miniapp-builds").getPublicUrl(storagePath);

  // ── Register with both Cores ────────────────────────────────────────────
  const coreDevUrl = Deno.env.get("CORE_DEV_SUPABASE_URL");
  const coreDevAnonKey = Deno.env.get("CORE_DEV_SUPABASE_ANON_PUBLIC");
  const coreProdUrl = Deno.env.get("CORE_PROD_SUPABASE_URL");
  const coreProdAnonKey = Deno.env.get("CORE_PROD_SUPABASE_ANON_PUBLIC");
  const coreDeploySecret = Deno.env.get("MINIAPP_DEPLOY_SECRET");
  const slug = Deno.env.get("MINIAPP_SLUG");
  const name = Deno.env.get("MINIAPP_NAME") ?? slug ?? "Mini-app";

  const cores = [
    { name: "core-dev", url: coreDevUrl, anonKey: coreDevAnonKey },
    { name: "core-prod", url: coreProdUrl, anonKey: coreProdAnonKey },
  ];

  const registerFailures: string[] = [];

  for (const core of cores) {
    if (!core.url || !core.anonKey) {
      registerFailures.push(`${core.name}: missing URL or anon key`);
      continue;
    }

    try {
      const response = await fetch(
        `${core.url}/functions/v1/register_miniapp_version`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${core.anonKey}`,
            "x-deploy-secret": coreDeploySecret || "",
          },
          body: JSON.stringify({
            slug,
            version: registeredVersion,
            url: publicUrl,
            name,
            env,
          }),
        }
      );

      if (!response.ok) {
        const text = await response.text();
        registerFailures.push(`${core.name}: HTTP ${response.status} ${text}`);
      }
    } catch (err) {
      registerFailures.push(
        `${core.name}: ${err instanceof Error ? err.message : String(err)}`
      );
    }
  }

  // Fail the deploy if registration with any core failed. The HTML is already
  // in storage, but a green deploy that didn't update the core DB is a silent
  // failure — surface it so the CI job fails.
  if (registerFailures.length > 0) {
    return {
      data: null,
      error: response500_internal_server_error(
        new Error(
          `Uploaded to storage but failed to register version with core(s): ${registerFailures.join(
            "; "
          )}`
        )
      ),
    };
  }

  return {
    data: {
      success: true,
      message: "Miniapp deployed successfully",
      url: publicUrl,
    },
    error: null,
  };
};
