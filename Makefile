
init:
	@echo "Initializing ArgoCD application..."
	kubectl apply -f argocd/root-app.yaml