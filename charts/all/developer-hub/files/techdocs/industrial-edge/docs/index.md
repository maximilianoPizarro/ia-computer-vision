# Industrial Edge (Multi-Cluster)

Operational architecture for the ACM hub-spoke IoT workshop.

## Clusters

| Role | Workloads |
|------|-----------|
| **Hub** | Gateway, MinIO, Kafka Console, GitLab, Developer Hub, Mailpit, Quay |
| **East / West** | Machine sensors, AMQ MQTT, Kafka, Camel K, line dashboard, Tekton CI |

## End-to-end flow

1. **Machine sensors** publish MQTT telemetry to **AMQ Broker** on the spoke.
2. **Camel K** (`mqtt-to-kafka`) routes messages into the **dev-cluster** Kafka topics.
3. **Line dashboard** consumes Kafka and shows real-time charts (via hub gateway + Skupper).
4. **ie-anomaly-alerter** sends threshold alerts to **Mailpit** on the hub.
5. Optional: **data-lake** archives to **MinIO** on the hub via Skupper.

## Developer Hub views

- Open **System → industrial-edge** for the topology graph (hub + east + west).
- Use **Clusters** (`/ocm`) for ACM managed clusters.
- Scaffold new edge instances with the **Industrial Edge** software template (Tekton CI tab on created components).

## Optional components

| Component | When to enable |
|-----------|----------------|
| Anomaly detection (KServe) | `anomalyDetection.enabled` in spoke chart |
| Stormshift / factory-cluster | `industrial-edge-stormshift` spoke app |
