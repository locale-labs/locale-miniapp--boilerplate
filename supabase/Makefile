.PHONY:
	deno-check \
	deno-lint \
	deploy-supabase-function--deploy_miniapp \
	deploy-supabase-functions \
	deploy-supabase-functions-dev \
	deploy-supabase-functions-prod \
	check-errors

DEPLOY_ENV ?= dev

ifneq (,$(wildcard ../.env.$(DEPLOY_ENV)))
    include ../.env.$(DEPLOY_ENV)
    export
else ifneq (,$(wildcard ../.env))
    include ../.env
    export
endif

deno-check:
	@deno check functions/**/*.ts

deno-lint:
	@deno lint functions/

# ──────────────────────────────────────────────────────────────────────────────

SUPABASE_DEPLOY_FLAGS := --project-ref $(MINIAPP_SUPABASE_PROJECT_ID)
export SUPABASE_ACCESS_TOKEN := $(MINIAPP_SUPABASE_ACCESS_TOKEN)

deploy-supabase-function--deploy_miniapp:
	@supabase functions deploy deploy_miniapp $(SUPABASE_DEPLOY_FLAGS)

deploy-supabase-functions:
	@supabase functions deploy $(SUPABASE_DEPLOY_FLAGS)

deploy-supabase-functions-dev:
	@supabase functions deploy $(SUPABASE_DEPLOY_FLAGS)
	@supabase secrets set --project-ref $(MINIAPP_SUPABASE_PROJECT_ID) \
		MINIAPP_API_KEY=$(MINIAPP_API_KEY) \
		MINIAPP_DEPLOY_SECRET=$(MINIAPP_DEPLOY_SECRET) \
		CORE_DEV_SUPABASE_URL=$(CORE_DEV_SUPABASE_URL) \
		CORE_DEV_SUPABASE_ANON_PUBLIC=$(CORE_DEV_SUPABASE_ANON_PUBLIC) \
		CORE_PROD_SUPABASE_URL=$(CORE_PROD_SUPABASE_URL) \
		CORE_PROD_SUPABASE_ANON_PUBLIC=$(CORE_PROD_SUPABASE_ANON_PUBLIC) \
		MINIAPP_SLUG=$(MINIAPP_SLUG) \
		MINIAPP_NAME=$(MINIAPP_NAME)

deploy-supabase-functions-prod:
	@supabase functions deploy $(SUPABASE_DEPLOY_FLAGS)
	@supabase secrets set --project-ref $(MINIAPP_SUPABASE_PROJECT_ID) \
		MINIAPP_API_KEY=$(MINIAPP_API_KEY) \
		MINIAPP_DEPLOY_SECRET=$(MINIAPP_DEPLOY_SECRET) \
		CORE_DEV_SUPABASE_URL=$(CORE_DEV_SUPABASE_URL) \
		CORE_DEV_SUPABASE_ANON_PUBLIC=$(CORE_DEV_SUPABASE_ANON_PUBLIC) \
		CORE_PROD_SUPABASE_URL=$(CORE_PROD_SUPABASE_URL) \
		CORE_PROD_SUPABASE_ANON_PUBLIC=$(CORE_PROD_SUPABASE_ANON_PUBLIC) \
		MINIAPP_SLUG=$(MINIAPP_SLUG) \
		MINIAPP_NAME=$(MINIAPP_NAME)

check-errors:
	@echo "🔍 Checking errors in supabase..."
	@make -j2 deno-check deno-lint
	@echo "✅ Done checking errors in supabase"
