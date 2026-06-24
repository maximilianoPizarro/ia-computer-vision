# Create an Industrial Edge component

## From Developer Hub

1. Sign in to Developer Hub.
2. Go to **Create** → **Industrial Edge: IoT Manufacturing (Multi-Cluster)**.
3. Fill in:
   - **Instance name** — e.g. `edge-factory-1`
   - **Owner** — defaults to your catalog user (`user1`)
   - **Target cluster** — `east` or `west`
   - **Hub cluster apps domain** — hub apps domain (for GitLab URLs)
   - **Spoke apps domain** — auto-filled when you pick east/west
4. Run the template.

## What happens

1. Skeleton is generated and pushed to GitLab: `ws-<owner>/<name>-<cluster>`.
2. A catalog **Component** is registered with Kubernetes/Topology annotations.
3. An Argo CD **Application** is created on the hub targeting the spoke.
4. Manifests sync into namespace `ie-<name>-<cluster>` on the spoke.

## Camel / Kaoto variant

Use **Industrial Edge — Camel Routes (Kaoto + Continue AI)** for route editing in DevSpaces with Kaoto.

## Tips

- Ensure your GitLab org exists (`ws-userN`) — provisioned by the platform GitLab setup job.
- If DevSpaces link fails, verify you opened the spoke DevSpaces URL, not the hub.
