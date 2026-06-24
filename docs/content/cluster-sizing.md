---
title: Cluster sizing
weight: 20
---

# Cluster sizing for AI Computer Vision

This pattern requires **three independent clusters**: one hub and two spokes (east and west).

## Recommended AWS sizing

| Cluster role | Control plane | Workers |
|---|---|---|
| Hub | 3 x `m6a.2xlarge` | 3 x `m6a.2xlarge` |
| East spoke | 3 x `m6a.2xlarge` | 3 x `m6a.2xlarge` |
| West spoke | 3 x `m6a.2xlarge` | 3 x `m6a.2xlarge` |

Each `m6a.2xlarge` instance provides 8 vCPU and 32 GiB memory.

## Minimum requirements

- OpenShift 4.14 or later on all clusters
- Three worker nodes per cluster (minimum)
- Sufficient persistent storage for Vault, Quay, GitLab, and OpenShift AI components on the hub

## GPU acceleration (optional)

For GPU-accelerated inference on spokes, add worker nodes with NVIDIA GPUs:

- AWS `g4dn.xlarge` (NVIDIA T4)
- AWS `g5.2xlarge` (NVIDIA A10G)

Install the Node Feature Discovery and NVIDIA GPU Operator on spoke clusters before enabling GPU-backed inference services.

## Source of truth

Sizing metadata is defined in `pattern-metadata.yaml` at the repository root and feeds automated documentation generation in the Validated Patterns catalog.
