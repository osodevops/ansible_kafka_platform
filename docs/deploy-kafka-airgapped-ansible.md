---
title: "Air-Gapped Apache Kafka Deployment with Ansible — Complete Guide"
description: "Deploy Apache Kafka in air-gapped, disconnected, and offline environments using the osodevops.kafka_platform Ansible collection. Step-by-step guide with KRaft, TLS, monitoring, and zero internet access."
author: "OSO DevOps"
date: 2026-03-24
canonical_url: "https://oso.sh/blog/deploy-kafka-airgapped-ansible/"
keywords:
  - air-gapped kafka deployment
  - kafka offline install ansible
  - deploy kafka without internet
  - kafka disconnected environment
  - ansible kafka air gap
  - kafka kraft air gapped
  - offline kafka cluster
  - kafka government deployment
  - kafka defence deployment
  - kafka pci-dss deployment
schema:
  - type: HowTo
  - type: FAQPage
  - type: SoftwareApplication
---

<!-- JSON-LD: HowTo Schema -->
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "HowTo",
  "name": "Deploy Apache Kafka in an Air-Gapped Environment with Ansible",
  "description": "Step-by-step guide to deploying a production Kafka cluster with KRaft consensus, TLS/SASL security, and Prometheus/Grafana monitoring in networks with no internet access.",
  "totalTime": "PT2H",
  "supply": [
    { "@type": "HowToSupply", "name": "Internet-connected machine for downloading artifacts" },
    { "@type": "HowToSupply", "name": "Air-gapped target servers (Ubuntu 20.04+, RHEL 8+, or Debian 11+)" },
    { "@type": "HowToSupply", "name": "Ansible >= 2.16.0" },
    { "@type": "HowToSupply", "name": "Python >= 3.10" }
  ],
  "tool": [
    { "@type": "HowToTool", "name": "osodevops.kafka_platform Ansible collection" },
    { "@type": "HowToTool", "name": "SSH access to target hosts" },
    { "@type": "HowToTool", "name": "USB drive or secure file transfer mechanism" }
  ],
  "step": [
    {
      "@type": "HowToStep",
      "name": "Download the air-gap bundle",
      "text": "Run the download-airgap-bundle.sh script on an internet-connected machine to download Kafka, Prometheus, Grafana, JMX Exporter, and Kafbat UI binaries."
    },
    {
      "@type": "HowToStep",
      "name": "Transfer to the air-gapped network",
      "text": "Copy the bundle archive to the air-gapped network via USB drive, SCP through a bastion host, or secure file transfer."
    },
    {
      "@type": "HowToStep",
      "name": "Set up the internal repository",
      "text": "Run setup-airgap-repo.sh to serve the bundle over HTTP on an internal server accessible by all cluster nodes."
    },
    {
      "@type": "HowToStep",
      "name": "Configure the Ansible inventory",
      "text": "Override download URL variables to point at the internal repository. Set airgap_enabled: true and configure grafana_install_method: tarball."
    },
    {
      "@type": "HowToStep",
      "name": "Run preflight validation",
      "text": "Execute the preflight-airgap.yml playbook to verify all artifacts are reachable and dependencies are installed."
    },
    {
      "@type": "HowToStep",
      "name": "Deploy the Kafka cluster",
      "text": "Run the standard site.yml playbook. The collection deploys KRaft controllers, brokers, TLS certificates, monitoring, and Kafka UI entirely from local artifacts."
    }
  ]
}
</script>

<!-- JSON-LD: FAQPage Schema -->
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "Can I deploy Apache Kafka without internet access?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Yes. The osodevops.kafka_platform Ansible collection supports fully air-gapped deployment. You download all binaries (Kafka, Prometheus, Grafana, JMX Exporter, Kafbat UI) on an internet-connected machine, transfer them to the isolated network, serve them from an internal HTTP repository, and deploy using standard Ansible playbooks. No internet access is required on any target node."
      }
    },
    {
      "@type": "Question",
      "name": "What operating systems support air-gapped Kafka deployment?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "The collection supports Ubuntu 20.04+, Debian 11+, and RHEL/Rocky 8+ for air-gapped deployments. OS packages (Java 21, chrony, xfsprogs) must be pre-downloaded and served from an internal package repository."
      }
    },
    {
      "@type": "Question",
      "name": "How do I upgrade Kafka in an air-gapped environment?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Download the new Kafka version on an internet-connected machine, transfer the tarball to the internal repository server, update the kafka_version variable in your inventory, and run the rolling upgrade playbook. The upgrade proceeds one node at a time with health checks between each restart."
      }
    },
    {
      "@type": "Question",
      "name": "Do I need to mirror APT or YUM repositories for air-gapped Kafka?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "You need to pre-download the OS packages required by the collection (Java 21, chrony, xfsprogs, acl, openssl, etc.) and serve them from an internal APT or YUM repository. The collection provides scripts to set up the package repository index (dpkg-scanpackages for Debian, createrepo for RHEL)."
      }
    },
    {
      "@type": "Question",
      "name": "What is the osodevops.kafka_platform Ansible collection?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "osodevops.kafka_platform is an open-source Ansible collection for deploying production-grade Apache Kafka clusters using KRaft consensus (no ZooKeeper). It includes roles for Kafka controllers, brokers, TLS/SASL security, topic management, Prometheus monitoring, Grafana dashboards, and Kafbat UI. It supports both online and air-gapped deployments."
      }
    },
    {
      "@type": "Question",
      "name": "How does KRaft mode work in disconnected networks?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "KRaft (Kafka Raft) is Kafka's built-in consensus protocol that replaces ZooKeeper for metadata management. It works identically in air-gapped networks because all consensus traffic is internal to the cluster (controller-to-controller on port 9093). No external network connectivity is required for cluster operations."
      }
    },
    {
      "@type": "Question",
      "name": "How much disk space does the air-gap bundle require?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "The air-gap bundle (Kafka, Prometheus, Grafana, JMX Exporter, Kafbat UI, Ansible collection, and Python packages) requires approximately 2 GB on both the distribution server and the internal repository server. OS packages add approximately 500 MB depending on the target distribution."
      }
    }
  ]
}
</script>

<!-- JSON-LD: SoftwareApplication Schema -->
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  "name": "osodevops.kafka_platform",
  "description": "Production-ready Apache Kafka deployment with KRaft consensus, TLS/SASL security, and full monitoring stack via Ansible.",
  "applicationCategory": "DeveloperApplication",
  "operatingSystem": "Linux",
  "softwareVersion": "1.0.1",
  "url": "https://galaxy.ansible.com/ui/repo/published/osodevops/kafka_platform/",
  "codeRepository": "https://github.com/osodevops/ansible_kafka_platform",
  "author": {
    "@type": "Organization",
    "name": "OSO DevOps",
    "url": "https://oso.sh"
  },
  "license": "https://www.apache.org/licenses/LICENSE-2.0"
}
</script>

<!-- JSON-LD: BreadcrumbList Schema -->
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  "itemListElement": [
    { "@type": "ListItem", "position": 1, "name": "OSO", "item": "https://oso.sh" },
    { "@type": "ListItem", "position": 2, "name": "Fully Managed Kafka", "item": "https://oso.sh/fully-managed-kafka/" },
    { "@type": "ListItem", "position": 3, "name": "Air-Gapped Kafka Deployment", "item": "https://oso.sh/blog/deploy-kafka-airgapped-ansible/" }
  ]
}
</script>

# Air-Gapped Apache Kafka Deployment with Ansible — Complete Guide

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
