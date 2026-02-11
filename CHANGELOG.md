# Changelog

All notable changes to this collection will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-02-11

### Fixed

- Corrected repository and documentation URLs in Galaxy metadata
- Set homepage to https://oso.sh/fully-managed-kafka/

## [1.0.0] - 2026-02-11

### Added

- **Roles:**
  - `common` - OS prerequisites (packages, Java 21, storage, kernel tuning, NTP)
  - `ssl` - TLS certificate generation (self-signed CA, per-node keystores, truststores)
  - `kafka_install` - Apache Kafka binary download, extraction, and JMX exporter setup
  - `kafka_controller` - KRaft controller node deployment with quorum management
  - `kafka_broker` - Kafka broker deployment with SSL, SASL/SCRAM-SHA-512 support
  - `kafka_topics` - Declarative Kafka topic creation and management
  - `kafka_ui` - Kafbat UI deployment for cluster management
  - `prometheus` - Prometheus deployment with Kafka-specific scrape and alert rules
  - `grafana` - Grafana deployment with pre-built Kafka dashboards
  - `kafka_analysis` - Read-only topic configuration analysis and reporting

- **Playbooks:**
  - `site.yml` - Full cluster deployment with greenfield/brownfield detection
  - `common.yml` - OS prerequisites only
  - `kafka_controller.yml` - Controller deployment
  - `kafka_broker.yml` - Broker deployment
  - `monitoring.yml` - Prometheus + Grafana + Kafka UI
  - `create_topics.yml` - Topic provisioning
  - `create_acls.yml` - ACL provisioning
  - `create_scram_users.yml` - SCRAM user creation
  - `health_check.yml` - Full cluster health verification
  - `rolling_restart.yml` - Zero-downtime rolling restart
  - `upgrade.yml` - Rolling Kafka version upgrade
  - `analysis.yml` - Topic configuration analysis

- **Testing:**
  - Molecule `default` scenario (single-node PLAINTEXT)
  - Molecule `kraft-tls` scenario (multi-node SSL + SCRAM)

- **Monitoring:**
  - Grafana dashboards: Kafka Overview, Broker Metrics, Controller Metrics, JVM Metrics
  - Prometheus alert rules for Kafka health

- **Documentation:**
  - Complete example inventory with RFC 5737 documentation IPs
  - Variable reference (docs/VARIABLES.md)
  - Architecture guide (docs/ARCHITECTURE.md)
  - Per-role README files
