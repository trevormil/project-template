# Deploy module — prod URL from day one

Gets even a bare MVP live at `<project>.trevormil.com` on the shared DOKS cluster.
All free/self-hosted; DigitalOcean is the only paid line.

One action (Admin → Deploy, or `bash deploy/k8s/deploy.sh`):
1. `docker build` → push `ghcr.io/trevormil/<project>`
2. `kubectl apply -k deploy/k8s` (namespace + deployment + service + ingress)
3. `doctl compute domain records create trevormil.com` → A-record `<project>` → ingress LB `159.89.222.96`
4. cert-manager issues Let's Encrypt TLS

Convention: `autopilot-harness/K8s.md`. Wraps `docker`/`doctl`/`kubectl` — no reinvention.

> Phase-0 stub — full manifests + deploy.sh land in Phase 2.
