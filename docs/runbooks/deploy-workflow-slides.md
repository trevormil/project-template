---
title: Deploy workflow slides to workflow.trevormil.com
last-verified: 2026-06-09
---

# Deploy Workflow Slides

The workflow slide deck at [`docs/workflow/e2e-workflow-slides.html`](../workflow/e2e-workflow-slides.html)
deploys as a single static nginx container to **https://workflow.trevormil.com**.
It follows the same shared DigitalOcean Kubernetes pattern as the other
`trevormil.com` static sites: GHCR image, ingress-nginx, cert-manager, and the
`letsencrypt-prod` ClusterIssuer.

## One-Time Setup

Create or verify the DNS record:

```bash
workflow   A   159.89.222.96   proxied=off
```

Apply the namespace and copy the GHCR pull secret from another deployed site:

```bash
kubectl apply -f docs/workflow/k8s/namespace.yaml

kubectl get secret ghcr-pull -n yuno-landing -o yaml \
  | sed 's/namespace: yuno-landing/namespace: workflow-slides/' \
  | kubectl apply -f -
```

## Build And Push

From the repo root:

```bash
docker buildx build \
  --platform linux/amd64 \
  -t ghcr.io/trevormil/workflow-slides:latest \
  --push \
  docs/workflow
```

## Deploy

```bash
kubectl apply -f docs/workflow/k8s/deployment.yaml
kubectl apply -f docs/workflow/k8s/service.yaml
kubectl apply -f docs/workflow/k8s/ingress.yaml

kubectl -n workflow-slides rollout status deploy/workflow-slides --timeout=90s
```

## Verify

```bash
kubectl -n workflow-slides get pods
kubectl -n workflow-slides get ingress
kubectl -n workflow-slides get certificate
curl -sI https://workflow.trevormil.com | head -3
```

Expected response is `HTTP/2 200` with `content-type: text/html`.
