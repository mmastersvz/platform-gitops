
SHELL := /bin/bash

init:
	@echo "Initializing ArgoCD application..."
	@read -s -p "GitHub PAT: " GITHUB_PAT && echo "" && \
	kubectl create secret generic platform-gitops-repo \
		-n argocd \
		--from-literal=type=git \
		--from-literal=url=https://github.com/mmastersvz/platform-gitops.git \
		--from-literal=username=mmastersvz \
		--from-literal=password=$$GITHUB_PAT \
		--dry-run=client -o yaml | \
	kubectl apply -f - && \
	kubectl label secret platform-gitops-repo -n argocd argocd.argoproj.io/secret-type=repository --overwrite
	kubectl apply -f argocd/projects.yaml
	kubectl apply -f argocd/root-app.yaml