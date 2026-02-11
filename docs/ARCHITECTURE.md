# Architecture

## KRaft Mode

This collection deploys Apache Kafka in **KRaft mode** (Kafka Raft), which eliminates the dependency on Apache ZooKeeper. In KRaft mode, Kafka manages its own metadata using an internal Raft consensus protocol.

### Node Topology

| Node Type | Process Role | Description |
|-----------|-------------|-------------|
| **Controller** | `controller` | Manages cluster metadata via Raft consensus. Runs the KRaft quorum. |
| **Broker** | `broker` | Handles data plane: produces, consumes, replication, and storage. |

Controllers and brokers are deployed on separate hosts for production isolation. The collection supports both **greenfield** (new cluster) and **brownfield** (existing cluster update) deployments — detected automatically via service facts.

### Quorum Voters

Controllers form a Raft quorum defined by `kafka_controller_quorum_voters`:

```
kafka_controller_quorum_voters: "1@ctrl-01:9093,2@ctrl-02:9093,3@ctrl-03:9093"
```

Each controller is identified by its `node_id` (assigned via host_vars) and listens on port 9093.

### Cluster ID

All nodes in a cluster share the same `kafka_cluster_id`, generated once with:

```bash
kafka-storage.sh random-uuid
```

This ID is used during storage formatting and cannot be changed after initial deployment.

## Storage Layout

### Broker Data

Brokers use JBOD (Just a Bunch of Disks) storage configured via `kafka_data_dirs`:

```yaml
kafka_data_dirs:
  - /data/kafka-1
  - /data/kafka-2
```

The `common` role handles filesystem creation (XFS) and mounting.

### Controller Metadata

Controllers store Raft metadata in `kafka_metadata_log_dir`, typically a single directory on fast storage.

### Directory Structure

```
/opt/kafka/
  versions/                   # Downloaded Kafka releases
    kafka_2.13-4.0.0/
  current -> versions/...     # Symlink to active version

/etc/kafka/
  server.properties           # Main Kafka configuration
  client.properties           # Admin client configuration
  log4j2.properties           # Logging configuration
  ssl/                        # TLS certificates
    ca-cert.pem
    <hostname>.keystore.p12
    kafka.truststore.p12

/data/kafka/                  # Broker data (or JBOD paths)
  metadata/                   # Controller metadata log
```

## Network Ports

| Port | Listener | Protocol | Used By |
|------|----------|----------|---------|
| 9093 | CONTROLLER | SSL | Controller-to-controller quorum replication |
| 9092 | SSL | SSL | Client connections (mTLS) |
| 9094 | SASL_SSL | SASL_SSL | Client connections (SCRAM-SHA-512 over TLS) |
| 7071 | JMX Exporter | HTTP | Prometheus metric scraping |
| 9090 | Prometheus | HTTP | Metric storage and query API |
| 3000 | Grafana | HTTP | Dashboard UI |
| 8080 | Kafka UI | HTTP | Kafbat cluster management UI |

## Security Model

### TLS (Transport Layer Security)

```
┌──────────────┐
│  Self-Signed │
│      CA      │
└──────┬───────┘
       │ Signs
  ┌────┴─────┬──────────┬──────────┐
  ▼          ▼          ▼          ▼
┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐
│C-01  │  │C-02  │  │B-01  │  │B-02  │
│.p12  │  │.p12  │  │.p12  │  │.p12  │
└──────┘  └──────┘  └──────┘  └──────┘
  Per-node PKCS12 keystores with SAN
```

- A self-signed CA is generated on the first controller and distributed to all nodes
- Each node gets a PKCS12 keystore with SAN (Subject Alternative Name) entries
- All nodes share a common truststore containing the CA certificate
- Controller listener uses mutual TLS (client auth required)
- Broker SSL listener uses mutual TLS
- Broker SASL_SSL listener uses server-only TLS + SCRAM authentication

### SASL/SCRAM-SHA-512

```
Client ──SCRAM-SHA-512──▶ Broker (SASL_SSL :9094)
                            │
                            ▼
                      Credential Store
                      (in Kafka metadata)
```

- SCRAM credentials are stored in Kafka's internal metadata (not ZooKeeper)
- Each application gets its own username/password
- ACLs control per-user access to topics and consumer groups
- Super users bypass ACL checks for administrative operations

### Authorization

The `StandardAuthorizer` (KRaft-native) provides ACL-based authorization:

- Default: allow (configurable to deny)
- ACLs defined per service principal
- Supports PREFIXED and LITERAL resource patterns
- Super users configured via `kafka_super_users`

## Monitoring Data Flow

```
Kafka Nodes                  Monitoring Stack
┌──────────┐
│  Kafka   │
│ Process  │
│          │──JMX──▶ JMX Exporter (:7071)
└──────────┘              │
                          │ /metrics (HTTP)
                          ▼
                    ┌────────────┐     ┌────────────┐
                    │ Prometheus │────▶│  Grafana   │
                    │   :9090   │     │   :3000    │
                    └────────────┘     └────────────┘
                          │
                          ▼
                    Alert Rules
                    (under-replicated partitions,
                     offline partitions,
                     controller elections)
```

### JMX Exporter

Each Kafka node runs a JMX Prometheus exporter as a Java agent. The exporter configuration (`jmx-exporter.yml`) defines which MBeans to expose as Prometheus metrics.

### Prometheus

Prometheus scrapes JMX exporter endpoints on all Kafka nodes at a configurable interval (default: 15s). Alert rules are pre-configured for common Kafka failure scenarios.

### Grafana Dashboards

Four pre-built dashboards are included:

| Dashboard | Metrics |
|-----------|---------|
| **Kafka Overview** | Cluster-level: topic count, partition distribution, active controllers |
| **Kafka Broker** | Per-broker: bytes in/out, request rate, request latency, log size |
| **Kafka Controller** | Quorum: leader elections, metadata propagation, commit latency |
| **JVM Metrics** | Per-node: heap usage, GC pauses, thread count |

## Deployment Strategy

### Greenfield (New Cluster)

1. All controllers deployed in parallel
2. Storage formatted with cluster ID
3. All brokers deployed in parallel
4. Topics and SCRAM users created

### Brownfield (Existing Cluster)

1. Controllers updated serial:1 with health checks
2. Brokers updated serial:1 with URP (under-replicated partition) checks
3. Configuration changes applied incrementally

The `site.yml` playbook automatically detects which strategy to use by checking if the Kafka systemd service is already running on each node.
