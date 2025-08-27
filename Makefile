.PHONY: validate deploy fresh-deploy master-deploy logs backup rollback setup-passwords status start stop restart update resources info

validate:
	bash scripts/validate.sh

deploy:
	bash scripts/deploy.sh

fresh-deploy:
	@echo "Running fresh deployment pipeline..."
	@make validate
	@make deploy
	@echo ""
	@echo "🎉 Fresh deployment completed!"
	@echo ""
	@echo "Post-deployment steps:"
	@echo "1. Test external access via Cloudflare tunnels"
	@echo "2. Configure services through their web interfaces"
	@echo "3. Create a stable backup: git add -A && git commit -m 'deploy: $(shell date +%Y%m%d-%H%M)' && git tag -f last-good && git push --tags"

master-deploy:
	@echo "🚀 Starting SOL Homelab Master Deployment..."
	@echo "This will perform a complete fresh deployment from scratch:"
	@echo "  • Clean all Docker containers, images, and volumes"
	@echo "  • Set up directories and permissions"
	@echo "  • Generate secure passwords"
	@echo "  • Deploy all services"
	@echo "  • Configure Cloudflare tunnels"
	@echo ""
	bash scripts/master_deploy.sh

master-deploy-skip-cleanup:
	@echo "🚀 Starting SOL Homelab Master Deployment (skipping cleanup)..."
	bash scripts/master_deploy.sh --skip-cleanup

setup-env:
	@echo "🔐 Setting up environment configuration..."
	@echo "This will configure passwords, VPN credentials, and system settings."
	@echo ""
	bash scripts/setup_env.sh

setup-tunnel:
	@echo "🔧 Setting up Cloudflare tunnel for external access..."
	@echo "This will configure DNS and external routing for your services."
	@echo ""
	bash scripts/setup_tunnel.sh

logs:
	@echo "Showing cloudflared logs (ctrl+c to exit)..."
	@cd docker && docker compose logs -f cloudflared

status:
	bash scripts/service-manager.sh status

start:
	@echo "Usage: make start GROUP=<group>"
	@echo "Available groups: media, vpn, monitoring, infrastructure, all"
	@if [ -n "$(GROUP)" ]; then bash scripts/service-manager.sh start $(GROUP); fi

stop:
	@echo "Usage: make stop GROUP=<group>"
	@echo "Available groups: media, vpn, monitoring, infrastructure, all"
	@if [ -n "$(GROUP)" ]; then bash scripts/service-manager.sh stop $(GROUP); fi

restart:
	@echo "Usage: make restart GROUP=<group>"
	@echo "Available groups: media, vpn, monitoring, infrastructure, all"
	@if [ -n "$(GROUP)" ]; then bash scripts/service-manager.sh restart $(GROUP); fi

update:
	@echo "Usage: make update GROUP=<group>"
	@echo "Available groups: media, vpn, monitoring, infrastructure, all"
	@if [ -n "$(GROUP)" ]; then bash scripts/service-manager.sh update $(GROUP); fi

resources:
	bash scripts/service-manager.sh resources

info:
	@echo "Usage: make info SERVICE=<service>"
	@if [ -n "$(SERVICE)" ]; then bash scripts/service-manager.sh info $(SERVICE); else bash scripts/service-manager.sh info; fi

backup:
	bash scripts/backup.sh

rollback:
	bash scripts/rollback.sh

setup-passwords:
	bash scripts/generate_passwords.sh
