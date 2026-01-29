.PHONY: help up down restart logs ps init shell backup

help: ## Show this help message
	@echo "Moltbot (Clawdbot) Docker Deploy - commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

up: ## Start gateway (runs init first if needed)
	@docker compose up -d

down: ## Stop containers
	@docker compose down

restart: ## Restart gateway
	@docker compose restart clawdbot

logs: ## Follow logs
	@docker compose logs -f

ps: ## Show status
	@docker compose ps

init: ## Re-run init (apply env/config changes), then restart gateway
	@docker compose run --rm moltbot-init
	@docker compose restart clawdbot

shell: ## Shell into gateway container
	@docker exec -it clawdbot-gateway sh

backup: ## Backup persisted config/workspace to ./backups/
	@mkdir -p backups
	@tar czf backups/moltbot-backup-$$(date +%Y%m%d_%H%M%S).tar.gz data workspace
	@echo "✓ Backup written to backups/"
