# OSO Kafka Platform Collection

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

Production-ready Ansible collection for deploying Apache Kafka with KRaft consensus (no ZooKeeper), TLS/SASL security, and a full monitoring stack.

## Overview

This collection automates the complete lifecycle of an Apache Kafka cluster:

- **Apache Kafka** with KRaft mode (controllers + brokers)
- **TLS encryption** with self-signed CA and per-node certificates
- **SASL/SCRAM-SHA-512** authentication
- **Prometheus** metrics collection with Kafka-specific alert rules
- **Grafana** dashboards for cluster, broker, controller, and JVM monitoring
- **Kafbat UI** for web-based cluster management

## Roles

| Role | Description |
|------|-------------|
| `common` | OS prerequisites: packages, Java 21, storage, kernel tuning, NTP |
| `ssl` | TLS certificate generation: self-signed CA, keystores, truststores |
| `kafka_install` | Apache Kafka binary download, extraction, JMX exporter |
| `kafka_controller` | KRaft controller deployment with quorum management |
| `kafka_broker` | Kafka broker deployment with SSL and SASL/SCRAM |
| `kafka_topics` | Declarative Kafka topic creation and management |
| `kafka_ui` | Kafbat UI deployment for cluster management |
| `prometheus` | Prometheus with Kafka scrape targets and alert rules |
| `grafana` | Grafana with pre-built Kafka dashboards |
| `kafka_analysis` | Read-only topic configuration analysis and reporting |

## Requirements

- **Ansible:** >= 2.16.0
- **Python:** >= 3.10
- **Target OS:** Ubuntu 20.04+, Debian 11+, RHEL/Rocky 8+
- **Java:** OpenJDK 21 (installed by the `common` role)

### Network Ports

| Port | Service | Protocol |
|------|---------|----------|
| 9093 | KRaft Controller | TCP |
| 9092 | Kafka Broker (SSL) | TCP |
| 9094 | Kafka Broker (SASL_SSL) | TCP |
| 7071 | JMX Exporter | TCP |
| 9090 | Prometheus | TCP |
| 3000 | Grafana | TCP |
| 8080 | Kafka UI | TCP |

## Installation

```bash
ansible-galaxy collection install osodevops.kafka_platform
```

Or add to your `requirements.yml`:

```yaml
collections:
  - name: osodevops.kafka_platform
    version: ">=1.0.0"
```

## Quick Start

1. **Install the collection:**

   ```bash
   ansible-galaxy collection install osodevops.kafka_platform
   ```

2. **Copy the example inventory:**

   ```bash
   cp -r ~/.ansible/collections/ansible_collections/osodevops/kafka_platform/examples/inventory ./inventory
   ```

3. **Customize your inventory:**

   Edit `inventory/hosts.yml` with your hostnames and IPs, then update the group_vars files:
   - `group_vars/all/main.yml` — cluster ID, quorum voters, paths
   - `group_vars/all/security.yml` — TLS and SCRAM passwords (encrypt with `ansible-vault`)
   - `group_vars/all/topics.yml` — topic definitions
   - `group_vars/all/monitoring.yml` — Prometheus targets

4. **Deploy the cluster:**

   ```bash
   ansible-playbook -i inventory/hosts.yml osodevops.kafka_platform.site
   ```

5. **Verify health:**

   ```bash
   ansible-playbook -i inventory/hosts.yml osodevops.kafka_platform.health_check
   ```

## Architecture

```
                    ┌─────────────────────────────────┐
                    │       KRaft Controller Quorum    │
                    │  ┌──────┐ ┌──────┐ ┌──────┐     │
                    │  │ C-01 │ │ C-02 │ │ C-03 │     │
                    │  │ :9093│ │ :9093│ │ :9093│     │
                    │  └──┬───┘ └──┬───┘ └──┬───┘     │
                    └─────┼────────┼────────┼─────────┘
                          │  Metadata Replication  │
                    ┌─────┼────────┼────────┼─────────┐
                    │  ┌──┴───┐ ┌──┴───┐ ┌──┴───┐     │
                    │  │ B-01 │ │ B-02 │ │ B-03 │     │
                    │  │ :9092│ │ :9092│ │ :9092│     │
                    │  │ :9094│ │ :9094│ │ :9094│     │
                    │  └──┬───┘ └──┬───┘ └──┬───┘     │
                    │     Kafka Broker Fleet           │
                    └─────┬────────┬────────┬─────────┘
                          │  JMX :7071      │
                    ┌─────┴────────────────────────────┐
                    │  ┌────────────┐  ┌────────────┐  │
                    │  │ Prometheus │  │  Grafana   │  │
                    │  │   :9090   │──│   :3000    │  │
                    │  └────────────┘  │  Kafka UI  │  │
                    │                  │   :8080    │  │
                    │                  └────────────┘  │
                    │        Monitoring Stack          │
                    └──────────────────────────────────┘
```

- **Controllers** manage cluster metadata via Raft consensus (KRaft)
- **Brokers** handle data plane operations (produce/consume)
- **JMX Exporter** exposes Kafka metrics on each node
- **Prometheus** scrapes metrics from all Kafka nodes
- **Grafana** provides dashboards and alerting

## Configuration

See [docs/VARIABLES.md](docs/VARIABLES.md) for the complete variable reference.

Key configuration files in your inventory:

| File | Purpose |
|------|---------|
| `group_vars/all/main.yml` | Kafka version, paths, cluster ID, quorum voters |
| `group_vars/all/kafka.yml` | Replication, partitions, retention, networking |
| `group_vars/all/security.yml` | TLS certificates, SCRAM users and passwords |
| `group_vars/all/topics.yml` | Topic definitions with per-topic config |
| `group_vars/all/monitoring.yml` | Prometheus, Grafana, Kafka UI settings |

## Security

### TLS/SSL

The `ssl` role generates a self-signed CA and per-node certificates:
- PKCS12 keystores with SAN (Subject Alternative Name) support
- Mutual TLS (mTLS) between controllers and brokers
- Configurable certificate validity periods

### SASL/SCRAM-SHA-512

The `kafka_broker` role configures SASL/SCRAM authentication:
- Per-application SCRAM users with individual credentials
- ACL-based authorization with deny-by-default support
- Super user configuration for administrative access

**Important:** Encrypt `security.yml` with `ansible-vault` in production.

## Playbooks

| Playbook | Description |
|----------|-------------|
| `site.yml` | Full cluster deployment (greenfield/brownfield aware) |
| `common.yml` | OS prerequisites only |
| `kafka_controller.yml` | Controller deployment |
| `kafka_broker.yml` | Broker deployment |
| `monitoring.yml` | Prometheus + Grafana + Kafka UI |
| `create_topics.yml` | Topic provisioning |
| `create_acls.yml` | ACL provisioning |
| `create_scram_users.yml` | SCRAM user creation |
| `health_check.yml` | Full cluster health verification |
| `rolling_restart.yml` | Zero-downtime rolling restart |
| `upgrade.yml` | Rolling Kafka version upgrade |
| `analysis.yml` | Topic configuration analysis |

## Day-2 Operations

### Rolling Restart

```bash
ansible-playbook -i inventory/hosts.yml osodevops.kafka_platform.rolling_restart
```

Restarts controllers first (serial:1), then brokers (serial:1), with health checks between each node.

### Kafka Version Upgrade

```bash
ansible-playbook -i inventory/hosts.yml osodevops.kafka_platform.upgrade \
  -e kafka_new_version=4.1.0
```

Downloads the new version to all nodes, then performs a rolling upgrade with zero-downtime.

### Topic Management

```bash
ansible-playbook -i inventory/hosts.yml osodevops.kafka_platform.create_topics
```

Creates topics defined in `group_vars/all/topics.yml`. Idempotent — skips existing topics.

## Testing

This collection includes Molecule test scenarios:

```bash
# Basic single-node test (PLAINTEXT)
make test

# Multi-node TLS + SCRAM test
make test-tls
```

Requirements: Docker, Python 3.10+, molecule, molecule-plugins[docker].

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `make lint` and `make test`
5. Submit a pull request

## License

Apache-2.0 — see [LICENSE](LICENSE) for details.
