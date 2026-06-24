# Data Flow

```text
[Machine Sensors] --MQTT--> [AMQ Broker]
                                |
                                v
                         [Camel mqtt-to-kafka]
                                |
                                v
                         [Kafka dev-cluster]
                          /            \
                         v              v
              [Line Dashboard]    [Anomaly ML optional]
                         |
                         v
                   [Hub Gateway / Skupper]
```

## Namespaces (typical)

| Namespace | Cluster | Purpose |
|-----------|---------|---------|
| `industrial-edge-tst-all` | east/west | Sensors, MQTT, Kafka, Camel, dashboard |
| `industrial-edge-ci` | east/west | Shared Tekton pipelines |
| `industrial-edge-ml-workspace` | hub | MinIO models + Quay |
| `hub-gateway-system` | hub | Multi-cluster HTTP entry |
