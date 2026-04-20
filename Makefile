
SHELL := /bin/bash

MONITORING_NS     := monitoring
ARGOCD_NS         := argocd
ROLLOUTS_NS       := argo-rollouts

ARGOCD_PORT       := 9080
ROLLOUTS_PORT     := 9081
GRAFANA_PORT      := 9082
PROMETHEUS_PORT   := 9083
ALERTMANAGER_PORT := 9084

# $(call decode-secret,NAMESPACE,SECRET,KEY)
decode-secret = kubectl get secret $(2) -n $(1) -o jsonpath='{.data.$(3)}' | base64 -d

# Port-forward commands (defined once, reused in individual and parallel targets)
ARGOCD_PF_CMD       := kubectl port-forward svc/argocd-self-server -n $(ARGOCD_NS) $(ARGOCD_PORT):80
GRAFANA_PF_CMD      := kubectl port-forward svc/monitoring-grafana -n $(MONITORING_NS) $(GRAFANA_PORT):80
PROMETHEUS_PF_CMD   := kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n $(MONITORING_NS) $(PROMETHEUS_PORT):9090
ALERTMANAGER_PF_CMD := kubectl port-forward svc/monitoring-kube-prometheus-alertmanager -n $(MONITORING_NS) $(ALERTMANAGER_PORT):9093
ROLLOUTS_PF_CMD     := kubectl port-forward svc/argo-rollouts-dashboard -n $(ROLLOUTS_NS) $(ROLLOUTS_PORT):3100

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

# Info targets — print URL and credentials for each service
argocd-info:
	@echo "ArgoCD       → http://localhost:$(ARGOCD_PORT)"
	@echo "  username: admin"
	@printf "  password: "; $(call decode-secret,$(ARGOCD_NS),argocd-initial-admin-secret,password); echo

grafana-info:
	@echo "Grafana      → http://localhost:$(GRAFANA_PORT)"
	@printf "  username: "; $(call decode-secret,$(MONITORING_NS),monitoring-grafana,admin-user); echo
	@printf "  password: "; $(call decode-secret,$(MONITORING_NS),monitoring-grafana,admin-password); echo

prometheus-info:
	@echo "Prometheus   → http://localhost:$(PROMETHEUS_PORT)"

alertmanager-info:
	@echo "Alertmanager → http://localhost:$(ALERTMANAGER_PORT)"

rollouts-info:
	@echo "Rollouts     → http://localhost:$(ROLLBACK_PORT)"

# Individual port-forwards (print info then forward)
argocd-pf: argocd-info
	$(ARGOCD_PF_CMD)

grafana-pf: grafana-info
	$(GRAFANA_PF_CMD)

prometheus-pf: prometheus-info
	$(PROMETHEUS_PF_CMD)

alertmanager-pf: alertmanager-info
	$(ALERTMANAGER_PF_CMD)

rollouts-pf: rollouts-info
	$(ROLLOUTS_PF_CMD)

stop-pf:
	@pkill -f "kubectl[[:space:]]port-forward" && echo "Port-forwards stopped" || echo "No port-forwards running"

# All port-forwards in parallel
pf: argocd-info grafana-info prometheus-info alertmanager-info
	@$(ARGOCD_PF_CMD) & \
	$(GRAFANA_PF_CMD) & \
	$(PROMETHEUS_PF_CMD) & \
	$(ALERTMANAGER_PF_CMD) & \
	wait
