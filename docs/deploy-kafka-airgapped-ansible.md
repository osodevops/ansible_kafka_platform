# Air-Gapped Apache Kafka Deployment with Ansible — Complete Guide

> **For oso.sh publication**: The JSON-LD structured data (HowTo, FAQPage, SoftwareApplication, BreadcrumbList schemas) is in the companion file [`deploy-kafka-airgapped-ansible.jsonld.html`](deploy-kafka-airgapped-ansible.jsonld.html). Inject those `<script>` blocks into the `<head>` of the published page.

Deploy a production-grade Apache Kafka cluster with KRaft consensus, TLS/SASL encryption, and full Prometheus/Grafana monitoring in networks with **zero internet access**. This guide uses the open-source [`osodevops.kafka_platform`](https://galaxy.ansible.com/ui/repo/published/osodevops/kafka_platform/) Ansible collection and follows the same proven pattern used by [Confluent's air-gapped Ansible deployment](https://docs.confluent.io/ansible/current/ansible-airgap.html): download everything on a connected machine, transfer to an internal mirror, deploy with Ansible.

**Who this is for**: Platform engineers deploying Kafka in government, defence, finance, healthcare, or critical infrastructure environments where regulatory frameworks (ITAR, PCI-DSS, NIST 800-171, IL4/IL5) mandate network isolation.

---

## Why Deploy Kafka in Air-Gapped Environments?

Air-gapped networks — environments with no outbound internet connectivity — are required in scenarios where data sovereignty, supply chain security, and network isolation are non-negotiable:

| Sector | Regulatory Driver | Requirement |
|--------|-------------------|-------------|
| Government / Defence | ITAR, FedRAMP, IL4-IL6 | Classified networks with no internet egress |
| Financial Services | PCI-DSS, SOX, MAS-TRM | Segregated production zones for payment processing |
| Healthcare | HIPAA, NHS DSPT | Isolated networks for patient data pipelines |
| Critical Infrastructure | NERC CIP, NIS2 | SCADA/OT networks for energy, utilities, transport |
| Telecommunications | GSMA, national security | Core network event streaming |

Apache Kafka is the backbone of real-time data pipelines in all of these sectors. Deploying it in air-gapped environments requires careful pre-staging of every binary, package, and dependency.

---

## Architecture Overview

An air-gapped Kafka deployment has three logical zones:

```
ZONE 1: Distribution Server (Internet-Connected)
  Downloads all artifacts: Kafka, Prometheus, Grafana,
  JMX Exporter, Kafbat UI, OS packages, Ansible collection
                    |
                    | USB / SCP / Secure Transfer
                    v
ZONE 2: Control Node + Internal Repository (Air-Gapped)
  Serves artifacts via HTTP (:8080)
  Runs Ansible playbooks via SSH
                    |
                    | SSH + HTTP
                    v
ZONE 3: Managed Nodes (Air-Gapped Kafka Cluster)
  3x KRaft Controllers (:9093)
  3x Kafka Brokers (:9092, :9094)
  Prometheus (:9090) + Grafana (:3000) + Kafka UI (:8080)
```

### Internal Network Requirements

| Port | Direction | Purpose |
|------|-----------|---------|
| 22 | Control Node -> Managed Nodes | SSH (Ansible) |
| 8080 | Managed Nodes -> Repository | Internal artifact repository |
| 9092 | Clients -> Brokers | Kafka SSL listener |
| 9093 | Controller <-> Controller | KRaft quorum |
| 9094 | Clients -> Brokers | Kafka SASL_SSL listener |
| 7071 | Prometheus -> Kafka Nodes | JMX Exporter metrics |
| 9090 | Internal | Prometheus UI |
| 3000 | Internal | Grafana dashboards |

---

## Prerequisites

| Requirement | Details |
|-------------|---------|
| Distribution server | Internet-connected machine with `curl`, `ansible-galaxy`, and `pip` |
| Control node | Air-gapped machine with Python >= 3.10, Ansible >= 2.16.0, SSH access to all targets |
| Managed nodes | Ubuntu 20.04+, Debian 11+, or RHEL/Rocky 8+ |
| Transfer mechanism | USB drive, SCP via bastion, or secure file transfer |
| Disk space | ~2 GB on distribution server, ~2 GB on repository server |

---

## What Gets Downloaded

Every external artifact the collection uses at deploy time:

| Component | Artifact | Source |
|-----------|----------|--------|
| Apache Kafka | `kafka_2.13-{version}.tgz` | downloads.apache.org |
| JMX Exporter | `jmx_prometheus_javaagent-{version}.jar` | repo1.maven.org |
| Prometheus | `prometheus-{version}.linux-amd64.tar.gz` | github.com/prometheus |
| Grafana | `grafana-{version}.linux-amd64.tar.gz` | dl.grafana.com |
| Kafbat UI | `api-v{version}.jar` | github.com/kafbat |
| OS packages | Java 21, chrony, xfsprogs, acl, openssl | APT/YUM repos |
| Python | `cryptography` pip package | pypi.org |

---

## Step-by-Step Deployment Guide

### Step 1: Download the Air-Gap Bundle

On the internet-connected distribution server:

```bash
# Clone the collection repository (or download the scripts)
git clone https://github.com/osodevops/ansible_kafka_platform.git
cd ansible_kafka_platform

# Download all artifacts with default versions
./scripts/download-airgap-bundle.sh

# Or override versions
KAFKA_VERSION=4.1.1 PROMETHEUS_VERSION=3.2.1 ./scripts/download-airgap-bundle.sh
```

The script creates a `oso-kafka-airgap-bundle-YYYYMMDD/` directory and a `.tar.gz` archive containing every artifact.

### Step 2: Download OS Packages

OS packages must be downloaded on a machine matching the target OS:

**Ubuntu/Debian:**
```bash
apt-get install --download-only -y \
  openjdk-21-jdk-headless chrony xfsprogs acl curl tar \
  openssl ca-certificates gnupg net-tools python3 python3-pip dpkg-dev
cp /var/cache/apt/archives/*.deb oso-kafka-airgap-bundle-*/os-packages/
```

**RHEL/Rocky:**
```bash
yum install --downloadonly --downloaddir=oso-kafka-airgap-bundle-*/os-packages/ \
  java-21-openjdk-headless chrony xfsprogs acl curl tar \
  openssl python3 python3-pip createrepo_c
```

### Step 3: Verify the Bundle

```bash
./scripts/verify-airgap-bundle.sh --bundle-dir oso-kafka-airgap-bundle-*
```

This checks every artifact exists and validates SHA-256 checksums.

### Step 4: Transfer to the Air-Gapped Network

```bash
# Option A: USB drive
cp oso-kafka-airgap-bundle-*.tar.gz /media/usb/

# Option B: SCP via bastion
scp oso-kafka-airgap-bundle-*.tar.gz bastion:/staging/

# On the air-gapped control node:
cd /opt
tar xzf /staging/oso-kafka-airgap-bundle-*.tar.gz
```

### Step 5: Set Up the Internal Repository

```bash
# Generate and install a systemd service (production)
./scripts/setup-airgap-repo.sh --bundle-dir /opt/oso-kafka-airgap-bundle-* --systemd

# Or start a quick HTTP server (testing)
./scripts/setup-airgap-repo.sh --bundle-dir /opt/oso-kafka-airgap-bundle-*

# Set up OS package repo index (if you downloaded OS packages)
./scripts/setup-airgap-repo.sh --bundle-dir /opt/oso-kafka-airgap-bundle-* --setup-os-repo
```

Install the Ansible collection on the control node:

```bash
ansible-galaxy collection install /opt/oso-kafka-airgap-bundle-*/ansible/*.tar.gz \
  -p /opt/ansible/collections/
```

### Step 6: Configure the Ansible Inventory

Generate the air-gap variable overrides automatically:

```bash
./scripts/setup-airgap-repo.sh \
  --bundle-dir /opt/oso-kafka-airgap-bundle-* \
  --generate-inventory > inventory/group_vars/all/airgap.yml
```

Or copy from the example:

```bash
cp examples/inventory/group_vars/all/airgap.yml inventory/group_vars/all/
# Edit airgap_repo_url to match your repository server hostname
```

### Step 7: Run Preflight Validation

```bash
ansible-playbook -i inventory/hosts.yml playbooks/preflight-airgap.yml
```

This verifies: collection dependencies, Python packages, artifact availability on the internal repo, and disk space on all target nodes.

### Step 8: Deploy the Kafka Cluster

```bash
# Full deployment (recommended)
ansible-playbook -i inventory/hosts.yml playbooks/site.yml

# Or deploy in stages
ansible-playbook -i inventory/hosts.yml playbooks/common.yml
ansible-playbook -i inventory/hosts.yml playbooks/kafka_controller.yml
ansible-playbook -i inventory/hosts.yml playbooks/kafka_broker.yml
ansible-playbook -i inventory/hosts.yml playbooks/monitoring.yml
ansible-playbook -i inventory/hosts.yml playbooks/create_topics.yml
ansible-playbook -i inventory/hosts.yml playbooks/health_check.yml
```

---

## Configuration Variables

Complete reference for all air-gap-related variables:

| Variable | Role | Default | Air-Gap Value |
|----------|------|---------|---------------|
| `airgap_enabled` | common | `false` | `true` |
| `airgap_repo_url` | all (group_vars) | `""` | `http://repo-server:8080` |
| `airgap_yum_repofile` | common | `""` | Path to `.repo` file on control node |
| `airgap_apt_sources_list` | common | `""` | Path to `.list` file on control node |
| `kafka_download_url` | kafka_install | Apache mirror | `{{ airgap_repo_url }}/kafka/...` |
| `jmx_exporter_download_url` | kafka_install | Maven Central | `{{ airgap_repo_url }}/jmx/...` |
| `prometheus_binary_url` | prometheus | GitHub Releases | `{{ airgap_repo_url }}/prometheus/...` |
| `grafana_install_method` | grafana | `"apt"` | `"tarball"` |
| `grafana_tarball_url` | grafana | `""` | `{{ airgap_repo_url }}/grafana/...` |
| `kafka_ui_download_url` | kafka_ui | GitHub Releases | `{{ airgap_repo_url }}/kafka-ui/...` |

---

## Day-2 Operations

### Rolling Upgrades

1. Download the new Kafka version on the distribution server
2. Transfer to the internal repository
3. Update `kafka_version` in inventory
4. Run: `ansible-playbook -i inventory/hosts.yml playbooks/upgrade.yml`

The upgrade playbook performs a zero-downtime rolling restart — controllers first (serial:1), then brokers (serial:1) — with health checks between each node.

### Adding Nodes

1. Add the new node to `inventory/hosts.yml`
2. Run: `ansible-playbook -i inventory/hosts.yml playbooks/site.yml --limit new-broker`

### Certificate Rotation

The SSL role generates certificates locally using OpenSSL — no internet required:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags ssl
```

### Monitoring Upgrades

Download new Prometheus/Grafana versions, transfer to the repository, update version variables, re-run:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/monitoring.yml
```

---

## Security Considerations

### Supply Chain Integrity

Verify all artifacts on the distribution server before transfer:

- **Apache Kafka**: SHA-512 checksums + GPG signatures from [kafka.apache.org/downloads](https://kafka.apache.org/downloads)
- **Prometheus**: SHA-256 checksums from GitHub release page
- **Grafana**: Checksums from [grafana.com/grafana/download](https://grafana.com/grafana/download)
- **OS packages**: GPG signature verification via the package manager

The `verify-airgap-bundle.sh` script validates SHA-256 checksums for all downloaded artifacts.

### Repository Hardening

For production environments:

- Serve the internal repository over **HTTPS** with an internal CA certificate
- Add **mutual TLS** or basic authentication
- Restrict network access via **firewall rules** to only cluster nodes
- Run the HTTP server as a **non-root user** with read-only access

### Secrets Management

Encrypt sensitive variables with Ansible Vault:

```bash
ansible-vault encrypt inventory/group_vars/all/security.yml
```

---

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| `apt-get update` fails | External repos still enabled | Ensure `airgap_enabled: true` and `airgap_apt_sources_list` is set |
| `yum install` fails with "No available package" | Missing transitive dependencies | Re-download with `--resolve`; include all deps |
| Kafka checksum mismatch | Corrupted transfer | Re-verify with `verify-airgap-bundle.sh` |
| `ImportError: cryptography` | pip package not installed | `pip install --no-index --find-links=<bundle>/pip/ cryptography` |
| HTTP 404 from repository | Wrong directory structure | Verify HTTP server root matches bundle directory |
| Collection not found | Wrong `collections_path` | Check `ansible-galaxy collection list -p <path>` |
| Connection timeout to repo | Firewall blocking port 8080 | Open port 8080 from managed nodes to repository |

### Diagnostic Commands

```bash
# Verify repository is serving files
curl -v http://repo-server:8080/kafka/

# Check APT repos (Debian/Ubuntu)
apt-cache policy

# Check YUM repos (RHEL/Rocky)
yum repolist

# Verify collection installation
ansible-galaxy collection list | grep osodevops

# Test connectivity to all hosts
ansible -i inventory/hosts.yml all -m ping

# Verify Java on managed nodes
ansible -i inventory/hosts.yml all -m command -a "java -version"
```

---

## Related Resources

- [osodevops.kafka_platform on Ansible Galaxy](https://galaxy.ansible.com/ui/repo/published/osodevops/kafka_platform/)
- [GitHub Repository](https://github.com/osodevops/ansible_kafka_platform)
- [Confluent Air-Gapped Ansible Guide](https://docs.confluent.io/ansible/current/ansible-airgap.html)
- [Red Hat: Install Ansible on a Disconnected Node](https://www.redhat.com/en/blog/install-ansible-disconnected-node)
- [Apache Kafka Downloads](https://kafka.apache.org/downloads)
- [OSO Fully Managed Kafka](https://oso.sh/fully-managed-kafka/)
