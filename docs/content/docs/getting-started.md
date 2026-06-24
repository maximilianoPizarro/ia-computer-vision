---
title: Getting started
weight: 10
---

# Getting started with AI Computer Vision

Deploy the AI Computer Vision Validated Pattern on three Red Hat OpenShift Container Platform clusters.

## Prerequisites

- Three clusters running OpenShift 4.20 or later (hub, east spoke, west spoke)
- Cluster admin access and `kubeconfig` for each cluster
- `podman` installed on your workstation (for `./pattern.sh`)
- Validated Patterns Operator installed on each cluster

## Installing the Validated Patterns Operator

On each cluster:

1. Log in to the OpenShift web console as a cluster administrator.
2. Navigate to **Operators > OperatorHub**.
3. Search for *Validated Patterns Operator* and install it into the default namespace.

## Deploying the hub cluster

1. Clone this repository:

```bash
git clone https://github.com/maximilianoPizarro/ia-computer-vision.git
cd ia-computer-vision
```

2. Copy and customize secrets (optional for auto-generated Vault secrets):

```bash
cp values-secret.yaml.template ~/values-secret-ia-computer-vision.yaml
```

3. Install the pattern on the hub:

```bash
./pattern.sh make install
```

Alternatively, create a Pattern custom resource with `clusterGroupName: hub`.

## Deploying east and west spokes

On each spoke cluster, install the Validated Patterns Operator, then:

**East:**

```bash
export TARGET_CLUSTERGROUP=east
./pattern.sh make install
```

**West:**

```bash
export TARGET_CLUSTERGROUP=west
./pattern.sh make install
```

## Verifying the deployment

1. In the hub cluster, open the Argo CD UI in the `vp-gitops` namespace.
2. Confirm all applications are *Synced* and *Healthy*.
3. Import east and west clusters into ACM using the labels `clusterGroup=east` and `clusterGroup=west`.

## Troubleshooting

If Argo CD applications remain out of sync on the hub after ACM 2.16 install, the `openshift-gitops` chart includes a CronJob that refreshes the ACM OpenAPI schema.

For additional guidance, see the [Validated Patterns documentation](https://validatedpatterns.io/).
