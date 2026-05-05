.PHONY: \
	build \
	build-html \
	build-ts \
	build-css \
	dev \
	deploy \
	lint \
	lint-fix \
	format \
	ts-check \
	check-errors \
	clean

# ============================================================
# BUILD
# ============================================================

DEPLOY_ENV ?= dev

ifneq (,$(wildcard ./.env.$(DEPLOY_ENV)))
    include .env.$(DEPLOY_ENV)
    export
else ifneq (,$(wildcard ./.env))
    include .env
    export
endif

build:
	@bun run build

build-html:
	@bun run build:html

build-ts:
	@bun run build:ts

build-css:
	@bun run build:css

# ============================================================
# DEVELOPMENT
# ============================================================

dev:
	@bun run dev

# Watch mode: full build on each change (for use with locale-core proxy which reads build/)
watch:
	@bun run build
	@bun x chokidar-cli "src/**/*" -c "bun run build"

# ============================================================
# LINTING & FORMATTING
# ============================================================

lint:
	@bun run lint

lint-fix:
	@bun run lint -- --fix || true

format:
	@bun run format

ts-check:
	@bun x tsc --noEmit

# ============================================================
# CHECK ERRORS (main command)
# ============================================================

check-errors:
	@echo "🔍 Checking errors in miniapp..."
	@echo ""
	@echo "📝 Running ESLint..."
	@bun run lint
	@echo ""
	@echo "📝 Running TypeScript check..."
	@bun x tsc --noEmit
	@echo ""
	@echo "✅ Done checking errors in miniapp"
	@echo ""
	@echo "🔍 Checking errors in supabase folder..."
	@make -C supabase check-errors
	@echo ""
	@echo "✅ Done checking errors in supabase folder"


# ============================================================
# DEPLOYMENT
# ============================================================

deploy:
	@if [ ! -f .env.$(DEPLOY_ENV) ]; then \
		echo "❌ Missing .env.$(DEPLOY_ENV) file. Copy from .env.$(DEPLOY_ENV).example and fill in values."; \
		exit 1; \
	fi
	@echo "🚀 Deploying supabase functions to $(DEPLOY_ENV)..."
	@make -C supabase deploy-supabase-functions-$(DEPLOY_ENV)
	@echo "🚀 Deploying miniapp to $(DEPLOY_ENV)..."
	@env DEPLOY_ENV=$(DEPLOY_ENV) $$(grep -v '^#' .env.$(DEPLOY_ENV) | grep -v '^\s*$$' | xargs) bun run deploy
	@echo "✅ Deployment to $(DEPLOY_ENV) complete!"

deploy-dev:
	@DEPLOY_ENV=dev $(MAKE) deploy

deploy-prod:
	@DEPLOY_ENV=prod $(MAKE) deploy

# ============================================================
# UTILITIES
# ============================================================

clean:
	@rm -rf .temp build node_modules
	@echo "🧹 Cleaned .temp, build, and node_modules"
