# platform-gitops

GitOps repository for the platform cluster, managed by ArgoCD using the App-of-Apps pattern.

## Prerequisites

- [k3d](https://k3d.io) cluster bootstrapped via [platform-bootstrap](https://github.com/mmastersvz/platform-bootstrap)
- `kubectl` configured against the cluster
- A GitHub Personal Access Token (PAT) with `repo` read access

## Bootstrap

After the cluster is up, initialize ArgoCD with:

```bash
make init
```

This will:
1. Prompt for a GitHub PAT and create a repo credential secret in ArgoCD
2. Apply the `platform` AppProject
3. Apply the root App-of-Apps

## Directory structure

```text
platform-gitops/
│
├── argocd/
│   ├── root-app.yaml       # App-of-Apps — syncs this entire repo
│   ├── argocd-self.yaml    # ArgoCD self-managed via Helm
│   └── projects.yaml       # platform AppProject definition
│
├── infrastructure/
│   ├── ingress-nginx.yaml
│   ├── monitoring.yaml
│   └── external-secrets.yaml
│
├── tenants/
│   └── team-a/
│       ├── namespace.yaml
│       ├── quota.yaml
│       └── limits.yaml
│
├── apps/
│   └── team-a-app/
│       ├── deployment.yaml
│       └── values.yaml
│
├── Makefile
└── README.md
```
