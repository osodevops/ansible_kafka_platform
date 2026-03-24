# Air-Gapped Deployment Guide

## Overview

An air-gapped (or disconnected) deployment is one where the target environment
has **no outbound Internet access**. This is a hard requirement in government,
defence, financial-services, and critical-infrastructure networks that enforce
strict network segmentation.

The `osodevops.kafka_platform` collection fully supports air-gapped
installation. The approach follows Confluent's proven pattern: download every
artefact once on an Internet-connected machine, transfer the bundle across the
security boundary, serve it from a lightweight internal repository, and point
the Ansible variables at that repository instead of the public Internet.

---

## Architecture Overview

```
  INTERNET-FACING ZONE            AIR-GAP BOUNDARY           ISOLATED ZONE
 +---------------------+        |                |     +-------------------------+
 |  Distribution Server |        |   USB / SCP /  |     |  Control Node           |
 |  (connected to web)  | -----> |   Diode        | --> |  (runs Ansible)         |
 |                       |        |                |     |                         |
 |  - download-airgap-  |        |                |     |  Internal Repo (HTTP)   |
 |    bundle.sh          |        |                |     |  - Kafka tarball        |
 |  - OS package mirror  |        |                |     |  - JMX exporter JAR    |
 +---------------------+        |                |     |  - Prometheus tarball   |
                                  |                |     |  - Grafana package      |
                                  |                |     |  - Kafbat UI JAR        |
                                  |                |     |  - OS packages (RPM/DEB)|
                                  |                |     +------------+------------+
                                  |                |                  |
                                  |                |     +------------v------------+
                                  |                |     |  Managed Nodes          |
                                  |                |     |  - Kafka Controllers    |
                                  |                |     |  - Kafka Brokers        |
                                  |                |     |  - Monitoring stack     |
                                  |                |     +-------------------------+
```

### Network Requirements (Isolated Zone)

| Port  | Protocol | Source          | Destination      | Purpose                        |
|-------|----------|-----------------|------------------|--------------------------------|
| 22    | TCP      | Control Node    | Managed Nodes    | SSH (Ansible)                  |
| 8080  | TCP      | Managed Nodes   | Internal Repo    | HTTP artefact repository       |
| 9092  | TCP      | Clients         | Kafka Brokers    | Kafka plaintext listener       |
| 9093  | TCP      | Clients         | Kafka Brokers    | Kafka TLS listener             |
| 9094  | TCP      | Brokers/Ctrls   | Brokers/Ctrls    | Inter-broker / controller      |
| 7071  | TCP      | Prometheus      | Kafka Nodes      | JMX exporter metrics           |
| 9090  | TCP      | Grafana         | Prometheus       | Prometheus HTTP API            |
| 3000  | TCP      | Operators       | Grafana          | Grafana web UI                 |

---

## Prerequisites

| Component            | Requirement                                                       |
|----------------------|-------------------------------------------------------------------|
| Distribution Server  | Internet-connected Linux or macOS host with `curl`, `sha256sum`   |
| Control Node         | RHEL/Rocky 8-9 or Ubuntu 22.04+ with Ansible 2.14+ and Python 3.9+ |
| Managed Nodes        | RHEL/Rocky 8-9 or Ubuntu 22.04+, SSH access from Control Node    |
| Transfer Mechanism   | USB drive, SCP over data diode, SFTP, or equivalent              |
| Disk Space (bundle)  | Minimum 2 GB for core bundle; 4 GB if including OS packages      |
| Disk Space (nodes)   | 20 GB minimum per Kafka node (data volume separate)              |

---

## Internet-Facing Downloads Audit

The table below lists every artefact each role attempts to download at runtime.
In an air-gapped deployment, all of these must be pre-staged on the internal
repository.

| Role                | Artefact(s) Downloaded                                        |
|---------------------|---------------------------------------------------------------|
| `common`            | OS packages (Java, chrony, xfsprogs, acl, curl, tar)         |
| `kafka_install`     | Apache Kafka binary tarball, JMX Exporter JAR                |
| `prometheus`        | Prometheus server binary tarball                              |
| `grafana`           | Grafana APT/RPM package or standalone tarball                 |
| `kafka_ui`          | Kafbat UI JAR                                                 |
| `ssl`               | None (generates certificates locally)                         |
| `kafka_controller`  | None (uses artefacts from `kafka_install`)                    |
| `kafka_broker`      | None (uses artefacts from `kafka_install`)                    |
| `kafka_topics`      | None (uses Kafka CLI already on disk)                         |
| `kafka_analysis`    | None (uses Kafka CLI already on disk)                         |

---

## Step-by-Step Deployment

### Step 1: Download the Air-Gap Bundle

On the **Internet-connected** distribution server, run the bundled download
script. It pulls every binary artefact and records SHA-256 checksums.

```bash
# Use default versions (matches collection defaults)
./scripts/download-airgap-bundle.sh

# Override versions via environment variables
KAFKA_VERSION=3.9.0 \
JMX_EXPORTER_VERSION=1.3.0 \
PROMETHEUS_VERSION=3.3.0 \
GRAFANA_VERSION=11.6.0 \
KAFKA_UI_VERSION=1.0.0 \
  ./scripts/download-airgap-bundle.sh
```

The script creates the following directory tree:

```
airgap-bundle/
  kafka/
    kafka_2.13-3.9.0.tgz
  jmx-exporter/
    jmx_prometheus_javaagent-1.3.0.jar
  prometheus/
    prometheus-3.3.0.linux-amd64.tar.gz
  grafana/
    grafana-enterprise-11.6.0.linux-amd64.tar.gz
  kafka-ui/
    kafbat-ui-v1.0.0.jar
  checksums/
    SHA256SUMS
```

### Step 2: Download OS Packages

OS packages must be downloaded separately because they are distribution-
specific. Collect them on a connected machine running the **same OS version**
as the target nodes.

**RHEL / Rocky Linux 8-9:**

```bash
sudo yum install --downloadonly --downloaddir=./airgap-bundle/os-packages/ \
  java-21-openjdk-headless \
  chrony \
  xfsprogs \
  acl \
  curl \
  tar \
  gzip \
  openssl \
  policycoreutils-python-utils
```

**Ubuntu / Debian:**

```bash
mkdir -p ./airgap-bundle/os-packages/
cd ./airgap-bundle/os-packages/

apt-get download \
  openjdk-21-jdk-headless \
  chrony \
  xfsprogs \
  acl \
  curl \
  tar \
  gzip \
  openssl

# Also pull transitive dependencies
apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts \
  --no-breaks --no-replaces --no-enhances \
  openjdk-21-jdk-headless chrony xfsprogs acl | \
  grep "^\w" | sort -u | xargs apt-get download
```

### Step 3: Verify the Bundle

Before transferring across the security boundary, verify integrity.

```bash
./scripts/verify-airgap-bundle.sh --bundle-dir ./airgap-bundle
```

The script validates every file against `checksums/SHA256SUMS` and reports
pass/fail for each artefact. A non-zero exit code indicates a checksum
mismatch.

### Step 4: Transfer to the Air-Gapped Network

Move the bundle across the air-gap boundary using your organisation's approved
transfer mechanism (USB media, data diode, approved SCP gateway, etc.).

```bash
# Example: tar up for transfer
tar czf airgap-bundle.tar.gz airgap-bundle/

# On the air-gapped control node, extract
tar xzf airgap-bundle.tar.gz -C /opt/kafka-airgap/
```

### Step 5: Set Up the Internal Repository

On the air-gapped **control node** (or a dedicated repository host), use the
setup script to serve the bundle over HTTP.

```bash
# Serve immediately on port 8080 (foreground, useful for testing)
./scripts/setup-airgap-repo.sh --serve \
  --bundle-dir /opt/kafka-airgap/airgap-bundle \
  --port 8080

# Install as a systemd service (recommended for production)
sudo ./scripts/setup-airgap-repo.sh --systemd \
  --bundle-dir /opt/kafka-airgap/airgap-bundle \
  --port 8080

# Set up a local YUM/APT repository from OS packages
sudo ./scripts/setup-airgap-repo.sh --setup-os-repo \
  --bundle-dir /opt/kafka-airgap/airgap-bundle

# Generate a starter inventory file pointing at this repo
./scripts/setup-airgap-repo.sh --generate-inventory \
  --bundle-dir /opt/kafka-airgap/airgap-bundle \
  --port 8080 \
  --output ./inventory/group_vars/all/airgap.yml
```

### Step 6: Configure the Inventory

Create (or generate via `--generate-inventory` above) the file
`inventory/group_vars/all/airgap.yml`. This file overrides every download URL
so that roles fetch artefacts from the internal repository instead of the
public Internet.

```yaml
# inventory/group_vars/all/airgap.yml
---
airgap_enabled: true
airgap_repo_url: "http://repo.internal:8080"

# Kafka
kafka_download_url: "{{ airgap_repo_url }}/kafka/kafka_2.13-{{ kafka_version }}.tgz"

# JMX Exporter
jmx_exporter_download_url: "{{ airgap_repo_url }}/jmx-exporter/jmx_prometheus_javaagent-{{ jmx_exporter_version }}.jar"

# Prometheus
prometheus_binary_url: "{{ airgap_repo_url }}/prometheus/prometheus-{{ prometheus_version }}.linux-amd64.tar.gz"

# Grafana
grafana_install_method: "tarball"
grafana_tarball_url: "{{ airgap_repo_url }}/grafana/grafana-enterprise-{{ grafana_version }}.linux-amd64.tar.gz"

# Kafbat UI
kafka_ui_download_url: "{{ airgap_repo_url }}/kafka-ui/kafbat-ui-v{{ kafka_ui_version }}.jar"

# OS package repository (RHEL/Rocky)
airgap_yum_repofile: "/etc/yum.repos.d/kafka-airgap.repo"

# OS package repository (Ubuntu/Debian)
airgap_apt_sources_list: "/etc/apt/sources.list.d/kafka-airgap.list"
```

#### Complete Variable Reference

| Variable                    | Role(s)          | Default (online)                              | Air-Gap Value                                                        |
|-----------------------------|------------------|-----------------------------------------------|----------------------------------------------------------------------|
| `kafka_download_url`        | `kafka_install`  | `https://downloads.apache.org/kafka/...`      | `{{ airgap_repo_url }}/kafka/kafka_2.13-{{ kafka_version }}.tgz`     |
| `jmx_exporter_download_url` | `kafka_install` | `https://repo1.maven.org/maven2/...`          | `{{ airgap_repo_url }}/jmx-exporter/jmx_prometheus_javaagent-...jar` |
| `prometheus_binary_url`     | `prometheus`     | `https://github.com/prometheus/...`           | `{{ airgap_repo_url }}/prometheus/prometheus-...tar.gz`               |
| `grafana_install_method`    | `grafana`        | `apt` or `yum`                                | `tarball`                                                            |
| `grafana_tarball_url`       | `grafana`        | `https://dl.grafana.com/enterprise/...`       | `{{ airgap_repo_url }}/grafana/grafana-enterprise-...tar.gz`         |
| `kafka_ui_download_url`     | `kafka_ui`       | `https://github.com/kafbat/kafka-ui/...`      | `{{ airgap_repo_url }}/kafka-ui/kafbat-ui-v...jar`                   |
| `airgap_enabled`            | all              | `false`                                       | `true`                                                               |
| `airgap_repo_url`           | all              | (not set)                                     | `http://repo.internal:8080`                                          |
| `airgap_yum_repofile`       | `common`         | (not set)                                     | `/etc/yum.repos.d/kafka-airgap.repo`                                 |
| `airgap_apt_sources_list`   | `common`         | (not set)                                     | `/etc/apt/sources.list.d/kafka-airgap.list`                          |

### Step 7: Run Preflight Checks

The preflight target validates that every expected artefact is reachable from
the managed nodes and that checksums match.

```bash
make preflight-airgap INVENTORY=inventory/hosts.yml
```

The check performs the following validations:

- Internal repository HTTP reachability from every managed node.
- Each artefact URL returns HTTP 200.
- SHA-256 checksum of each downloaded artefact matches the manifest.
- OS package repository is configured and reachable.
- Required ports are open between relevant host groups.

### Step 8: Deploy

**Full deployment (all components):**

```bash
make deploy INVENTORY=inventory/hosts.yml
```

**Staged deployment (recommended for first-time installs):**

```bash
# Stage 1: Common packages and SSL certificates
make deploy-common INVENTORY=inventory/hosts.yml
make deploy-ssl    INVENTORY=inventory/hosts.yml

# Stage 2: Kafka controllers and brokers
make deploy-controllers INVENTORY=inventory/hosts.yml
make deploy-brokers     INVENTORY=inventory/hosts.yml

# Stage 3: Post-deployment configuration
make deploy-topics INVENTORY=inventory/hosts.yml

# Stage 4: Monitoring stack
make deploy-prometheus INVENTORY=inventory/hosts.yml
make deploy-grafana    INVENTORY=inventory/hosts.yml
make deploy-kafka-ui   INVENTORY=inventory/hosts.yml
```

---

## Day-2 Operations

### Rolling Upgrades

1. On the Internet-connected distribution server, re-run the download script
   with the new version variables:

   ```bash
   KAFKA_VERSION=3.10.0 ./scripts/download-airgap-bundle.sh
   ```

2. Verify and transfer the updated bundle across the air-gap boundary.

3. Replace the artefacts on the internal repository host.

4. Update the version variable in your inventory:

   ```yaml
   kafka_version: "3.10.0"
   ```

5. Run the upgrade playbook:

   ```bash
   make upgrade INVENTORY=inventory/hosts.yml
   ```

   The playbook performs a rolling restart, one node at a time, waiting for
   under-replicated partitions to clear before proceeding.

### Adding Nodes

1. Add the new host entries to `inventory/hosts.yml` under the appropriate
   group (`kafka_broker`, `kafka_controller`, etc.).

2. Run the playbook with `--limit` to target only the new nodes:

   ```bash
   ansible-playbook playbooks/site.yml \
     -i inventory/hosts.yml \
     --limit new-broker-04.internal
   ```

### Certificate Rotation

The `ssl` role generates certificates locally on the control node and
distributes them over SSH. It requires **no Internet access** and works
identically in air-gapped environments.

```bash
make deploy-ssl INVENTORY=inventory/hosts.yml
```

To rotate without downtime, the role supports staged rotation: deploy new
truststores first, then new keystores, and finally restart brokers.

---

## Security Considerations

### Supply-Chain Integrity

- Always verify SHA-256 checksums on the Internet-connected side **before**
  transfer. The `verify-airgap-bundle.sh` script automates this.
- Where available, verify GPG signatures on upstream artefacts (Apache Kafka
  releases are GPG-signed).
- Maintain a manifest of all artefact versions and checksums in your
  configuration management system.

### Repository Hardening

- Serve the internal repository over **HTTPS** with a certificate from your
  organisation's internal CA.
- Restrict access to the repository port (8080 or your chosen port) using
  firewall rules. Only managed nodes and the control node should reach it.
- For high-security environments, consider mTLS between managed nodes and the
  internal repository.

### Vault Encryption

Encrypt sensitive inventory variables using Ansible Vault:

```bash
ansible-vault encrypt inventory/group_vars/all/secrets.yml
```

Variables that should be vaulted include:

- TLS keystore and truststore passwords
- Kafka SASL credentials
- Grafana admin password
- Any custom JMX authentication credentials

---

## Troubleshooting

### Common Issues

| Symptom                              | Likely Cause                                    | Resolution                                                              |
|--------------------------------------|-------------------------------------------------|-------------------------------------------------------------------------|
| `apt-get` fails with "unable to locate package" | Air-gapped APT source not configured or missing dependencies | Run `setup-airgap-repo.sh --setup-os-repo`; ensure transitive deps were downloaded |
| `yum` fails with "No package available" | Local YUM repo not configured or `createrepo` not run | Run `setup-airgap-repo.sh --setup-os-repo`; verify `.repo` file points to correct path |
| Checksum mismatch during preflight   | Corrupted transfer or version mismatch          | Re-run `verify-airgap-bundle.sh` on source; re-transfer the failing artefact |
| `ImportError: cryptography`          | Python `cryptography` package missing on control node | Install from OS packages or a pre-built wheel in the bundle            |
| HTTP 404 from internal repository    | Artefact path does not match expected URL        | Compare the URL in your inventory vars with the actual file path on the repo server |
| "Collection not found" error         | Ansible collection not installed on control node | Install the collection from a tarball: `ansible-galaxy collection install ./osodevops-kafka_platform-*.tar.gz` |
| SSH connection timeout               | Firewall blocking port 22 or SSH not running     | Verify `sshd` is running on target; check firewall rules for port 22   |
| Kafka broker fails to start          | JMX exporter JAR not found at expected path      | Verify `jmx_exporter_download_url` points to correct repo path; re-run `kafka_install` role |
| Prometheus scrape targets down       | Firewall blocking port 7071                      | Open port 7071 from the Prometheus host to all Kafka nodes             |

### Diagnostic Commands

```bash
# Verify internal repo is reachable from a managed node
curl -sf http://repo.internal:8080/ && echo "OK" || echo "UNREACHABLE"

# List artefacts served by the internal repo
curl -s http://repo.internal:8080/ | grep -oP 'href="\K[^"]+'

# Check if a specific artefact exists
curl -sI http://repo.internal:8080/kafka/kafka_2.13-3.9.0.tgz | head -1

# Validate SHA-256 checksum of a downloaded artefact
sha256sum /opt/kafka/kafka_2.13-3.9.0.tgz
# Compare with value in checksums/SHA256SUMS

# Test YUM repo on RHEL/Rocky
yum repolist | grep kafka-airgap

# Test APT repo on Ubuntu/Debian
apt-cache policy openjdk-21-jdk-headless

# Check that required ports are open (from control node)
for port in 22 8080 9092 9093 9094 7071 9090 3000; do
  nc -z -w2 target-host "$port" && echo "Port $port: OPEN" || echo "Port $port: CLOSED"
done

# Verify Ansible can reach all hosts
ansible all -i inventory/hosts.yml -m ping

# Check installed collection version
ansible-galaxy collection list | grep osodevops.kafka_platform
```

---

## Further Reading

- [docs/ARCHITECTURE.md](ARCHITECTURE.md) -- collection architecture and role dependency graph
- [docs/VARIABLES.md](VARIABLES.md) -- complete variable reference for all roles
- [examples/inventory/](../examples/inventory/) -- example inventory layouts
- [Confluent Platform Air-Gap Guide](https://docs.confluent.io/platform/current/installation/disconnected.html) -- upstream reference for disconnected Confluent deployments
