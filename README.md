# platform-gitops

GitOps repository for the local k3d platform cluster, managed by ArgoCD using the App-of-Apps pattern.

## Prerequisites

- [k3d](https://k3d.io) cluster bootstrapped via [platform-bootstrap](https://github.com/mmastersvz/platform-bootstrap)
- `kubectl` configured against the cluster
- `argocd` CLI installed
- A GitHub Personal Access Token (PAT) with `repo` read access

## Bootstrap

After the cluster is up, initialize ArgoCD with:

```bash
make init
```

This will:
1. Prompt for a GitHub PAT and create a repo credential secret in ArgoCD
2. Apply the `platform` AppProject
3. Apply the root App-of-Apps, which recursively syncs this repo

## Directory structure

```text
platform-gitops/
│
├── argocd/                        # ArgoCD Applications and config (synced by root-app)
│   ├── root-app.yaml              # App-of-Apps — watches argocd/ and bootstraps everything
│   ├── argocd-self.yaml           # ArgoCD self-managed via Helm (argocd-self-server)
│   ├── projects.yaml              # AppProjects: platform, team-a, team-b
│   ├── infrastructure-apps.yaml   # Application syncing infrastructure/
│   ├── tenants-apps.yaml          # Application syncing tenants/
│   └── apps.yaml                  # Per-team Applications (team-a-apps, team-b-apps)
│
├── infrastructure/                # Cluster-wide platform components
│   ├── ingress-nginx.yaml         # Ingress controller (LoadBalancer on :8080/:8443)
│   ├── monitoring.yaml            # kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
│   └── external-secrets.yaml      # External Secrets Operator
│
├── tenants/                       # Per-team namespace setup (managed by platform team)
│   ├── team-a/
│   │   ├── namespace.yaml         # Namespace
│   │   ├── quota.yaml             # ResourceQuota (2 CPU / 2Gi req, 4 CPU / 4Gi limit, 10 pods)
│   │   ├── limits.yaml            # LimitRange (default 200m/256Mi req, 500m/512Mi limit)
│   │   └── rbac.yaml              # Role + RoleBinding for team-a developer group
│   └── team-b/
│       ├── namespace.yaml
│       ├── quota.yaml
│       ├── limits.yaml
│       └── rbac.yaml
│
├── apps/                          # Team workloads (each team owns their subdirectory)
│   ├── team-a-app/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── hpa.yaml
│   └── team-b-app/
│       ├── deployment.yaml
│       └── service.yaml
│
├── Makefile
└── README.md
```

## ArgoCD applications

| Application | Project | Source path | Destination |
|---|---|---|---|
| `platform-root` | `platform` | `argocd/` | cluster-wide |
| `infrastructure` | `platform` | `infrastructure/` | cluster-wide |
| `tenants` | `platform` | `tenants/` | cluster-wide |
| `argocd-self` | `platform` | Helm: `argo-cd` | `argocd` |
| `ingress-nginx` | `platform` | Helm: `ingress-nginx` | `ingress-nginx` |
| `monitoring` | `platform` | Helm: `kube-prometheus-stack` | `monitoring` |
| `external-secrets` | `platform` | Helm: `external-secrets` | `external-secrets` |
| `team-a-apps` | `team-a` | `apps/team-a-app/` | `team-a` |
| `team-b-apps` | `team-b` | `apps/team-b-app/` | `team-b` |

## RBAC model

Access is enforced at two layers:

### Kubernetes RBAC

Each team namespace has a `developer` Role and RoleBinding bound to their group (`team-a` / `team-b`). Developers can read workloads, exec into pods, and forward ports — but cannot write resources (workloads are managed exclusively via GitOps).

To grant a user access to a team namespace, bind them to the group via your identity provider or directly:

```bash
kubectl create rolebinding <user>-team-a \
  --role=developer \
  --user=<user> \
  -n team-a
```

### ArgoCD AppProject

Each team has a dedicated AppProject (`team-a`, `team-b`) that enforces:

- **Source**: only this repository
- **Destination**: only their namespace — cannot deploy to other namespaces or `kube-system`
- **Resource whitelist**: namespace-scoped only (Deployment, Service, Ingress, ConfigMap, Secret, HPA, etc.) — cluster-scoped resources (ClusterRole, CRD, etc.) are blocked
- **ArgoCD role**: `proj:<team>:developer` — can view and sync their team's applications only

## Port-forwards (local dev)

```bash
make pf           # start all port-forwards in parallel
make stop-pf      # stop all port-forwards

make argocd-pf        # ArgoCD UI  → http://localhost:9080
make grafana-pf        # Grafana    → http://localhost:9081
make prometheus-pf     # Prometheus → http://localhost:9082
make alertmanager-pf   # Alertmanager → http://localhost:9083
```

Each target prints credentials read live from cluster secrets before starting the forward.

The k3d load balancer exposes ingress-nginx on:
- `http://localhost:8080` — HTTP
- `https://localhost:8443` — HTTPS

## Adding a new team

1. Add a new AppProject to `argocd/projects.yaml` (copy `team-b`, adjust name/namespace)
2. Add a new Application to `argocd/apps.yaml` pointing to `apps/<team>-app/`
3. Create `tenants/<team>/` with `namespace.yaml`, `quota.yaml`, `limits.yaml`, `rbac.yaml`
4. Create `apps/<team>-app/` with workload manifests
5. Commit and push — ArgoCD will sync automatically
