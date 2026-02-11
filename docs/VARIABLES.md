# Variable Reference

Complete reference for all variables used by the `osodevops.kafka_platform` collection, organized by role.

Variables are set in your inventory's `group_vars/` and `host_vars/` files. See `examples/inventory/` for a fully documented example.

---

## Global Variables

These variables are used across multiple roles. Define them in `group_vars/all/main.yml`.

| Variable | Default | Description | Required |
|----------|---------|-------------|----------|
| `kafka_version` | — | Apache Kafka version to install (e.g., `"4.0.0"`) | Yes |
| `kafka_scala_version` | — | Scala version for Kafka package (e.g., `"2.13"`) | Yes |
| `kafka_user` | — | System user for Kafka processes | Yes |
| `kafka_group` | — | System group for Kafka processes | Yes |
| `kafka_base_dir` | — | Base directory for Kafka installations (e.g., `/opt/kafka`) | Yes |
| `kafka_config_dir` | — | Configuration directory (e.g., `/etc/kafka`) | Yes |
| `kafka_log_dir` | — | Log file directory (e.g., `/var/log/kafka`) | Yes |
| `kafka_ssl_dir` | — | SSL certificate directory (e.g., `/etc/kafka/ssl`) | Yes |
| `kafka_current_dir` | — | Symlink to active Kafka installation | Yes |
| `kafka_data_dirs` | — | List of data directories (one per disk for JBOD) | Yes |
| `kafka_data_filesystem` | — | Filesystem type for data volumes (e.g., `xfs`) | No |
| `kafka_cluster_id` | — | Cluster UUID (from `kafka-storage.sh random-uuid`) | Yes |
| `kafka_controller_quorum_voters` | — | Controller quorum voters string (`"id@host:port,..."`) | Yes |
| `kafka_controller_quorum_bootstrap_servers` | — | Controller bootstrap servers (`"host:port,..."`) | Yes |
| `kafka_heap_opts` | — | JVM heap options (e.g., `"-Xms1g -Xmx1g"`) | No |
| `java_package` | — | Java package name (e.g., `"openjdk-21-jre-headless"`) | No |

---

## Role: common

OS prerequisites including packages, Java, storage, kernel tuning, and NTP.

| Variable | Default | Description | Required |
|----------|---------|-------------|----------|
| `common_packages` | `[openjdk-21-jdk-headless, xfsprogs, acl, chrony, ...]` | List of OS packages to install | No |
| `kafka_sysctl_params` | *(see defaults)* | Map of sysctl parameters for kernel tuning | No |
| `kafka_nofile_limit` | `128000` | Max open files (nofile) for kafka user | No |
| `kafka_nproc_limit` | `65536` | Max processes (nproc) for kafka user | No |

---

## Role: ssl

TLS certificate generation with self-signed CA.

| Variable | Default | Description | Required |
|----------|---------|-------------|----------|
| `ssl_ca_dir` | `"{{ kafka_ssl_dir }}/ca"` | Directory for CA certificate and key | No |
| `ssl_ca_key` | `"{{ ssl_ca_dir }}/ca-key.pem"` | Path to CA private key | No |
| `ssl_ca_cert` | `"{{ ssl_ca_dir }}/ca-cert.pem"` | Path to CA certificate | No |
| `ssl_keystore_type` | `"PKCS12"` | Keystore format | No |
| `ssl_truststore_file` | `"{{ kafka_ssl_dir }}/kafka.truststore.p12"` | Path to shared truststore | No |
| `ssl_ca_common_name` | — | CA certificate common name | Yes (when SSL enabled) |
| `ssl_ca_organization` | — | CA certificate organization | Yes (when SSL enabled) |
| `ssl_ca_validity_days` | — | CA certificate validity in days | No |
| `ssl_cert_validity_days` | — | Node certificate validity in days | No |
| `ssl_keystore_password` | — | Keystore password | Yes (when SSL enabled) |
| `ssl_truststore_password` | — | Truststore password | Yes (when SSL enabled) |
| `ssl_key_password` | — | Private key password | Yes (when SSL enabled) |

---

## Role: kafka_install

Downloads and installs Apache Kafka binaries.

| Variable | Default | Description | Required |
|----------|---------|-------------|----------|
| `kafka_download_dest` | `"/tmp/{{ kafka_package }}.tgz"` | Temporary download path | No |
| `kafka_force_download` | `false` | Force re-download even if already present | No |

---

## Role: kafka_controller

KRaft controller node deployment.

| Variable | Default | Description | Required |
|----------|---------|-------------|----------|
| `kafka_controller_health_check_retries` | `15` | Health check retry count after deployment | No |
| `kafka_controller_health_check_delay` | `10` | Seconds between health check retries | No |
| `kafka_controller_port_timeout` | `120` | Seconds to wait for controller port to open | No |
| `kafka_health_check_address` | `"{{ ansible_host }}"` | Address for health check connections | No |
| `kafka_controller_port` | — | Controller listener port (typically `9093`) | Yes |
| `kafka_jmx_exporter_port` | — | JMX exporter HTTP port (typically `7071`) | Yes |
| `kafka_controller_properties` | — | Map of controller server.properties entries | Yes |
| `node_id` | — | Unique node ID (set in host_vars) | Yes |

---

## Role: kafka_broker

Kafka broker node deployment with SASL/SCRAM support.

| Variable | Default | Description | Required |
|----------|---------|-------------|----------|
| `kafka_broker_health_check_retries` | `15` | Health check retry count after deployment | No |
| `kafka_broker_health_check_delay` | `10` | Seconds between health check retries | No |
| `kafka_broker_port_timeout` | `120` | Seconds to wait for broker port to open | No |
| `kafka_health_check_address` | `"{{ ansible_host }}"` | Address for health check connections | No |
| `kafka_broker_client_port` | `"{{ kafka_broker_ssl_port }}"` | Port used for admin client connections | No |
| `kafka_broker_ssl_port` | — | SSL listener port (typically `9092`) | Yes |
| `kafka_broker_sasl_ssl_port` | — | SASL_SSL listener port (typically `9094`) | Yes |
| `kafka_broker_properties` | — | Map of broker server.properties entries | Yes |
| `kafka_scram_users` | `[]` | List of SCRAM users (`[{username, password}]`) | No |
| `node_id` | — | Unique node ID (set in host_vars) | Yes |

---

## Role: kafka_topics

Declarative topic creation.

| Variable | Default | Description | Required |
|----------|---------|-------------|----------|
| `kafka_topics_bootstrap_server` | `"{{ groups['kafka_broker'][0] }}:..."` | Bootstrap server for topic operations | No |
| `kafka_topics_client_config` | `"{{ kafka_config_dir }}/client.properties"` | Client properties file path | No |
| `kafka_topics` | `[]` | List of topics to create (see below) | Yes |

Each topic in `kafka_topics`:

| Field | Description | Required |
|-------|-------------|----------|
| `name` | Topic name | Yes |
| `partitions` | Number of partitions | Yes |
| `replication_factor` | Replication factor | Yes |
| `config` | Map of topic-level config overrides | No |

---

## Role: kafka_ui

Kafbat UI for cluster management.

| Variable | Default | Description | Required |
|----------|---------|-------------|----------|
| `kafka_ui_version` | `"1.4.2"` | Kafbat UI version | No |
| `kafka_ui_port` | `8080` | HTTP port for Kafka UI | No |
| `kafka_ui_user` | `"kafkaui"` | System user for Kafka UI | No |
| `kafka_ui_group` | `"kafkaui"` | System group for Kafka UI | No |
| `kafka_ui_install_dir` | `"/opt/kafka-ui"` | Installation directory | No |
| `kafka_ui_config_dir` | `"/etc/kafka-ui"` | Configuration directory | No |
| `kafka_ui_cluster_name` | `"kafka-cluster"` | Display name in Kafka UI | No |
| `kafka_ui_bootstrap_servers` | `"localhost:9092"` | Broker bootstrap servers | Yes |

---

## Role: prometheus

Prometheus deployment for Kafka monitoring.

| Variable | Default | Description | Required |
|----------|---------|-------------|----------|
| `prometheus_version` | `"3.2.1"` | Prometheus version | No |
| `prometheus_user` | `"prometheus"` | System user | No |
| `prometheus_group` | `"prometheus"` | System group | No |
| `prometheus_config_dir` | `"/etc/prometheus"` | Configuration directory | No |
| `prometheus_port` | — | HTTP port (typically `9090`) | Yes |
| `prometheus_host` | — | Prometheus bind address | Yes |
| `prometheus_retention_days` | — | Data retention in days | No |
| `prometheus_scrape_interval` | — | Scrape interval (e.g., `"15s"`) | No |
| `prometheus_kafka_targets` | — | List of JMX exporter endpoints | Yes |

---

## Role: grafana

Grafana deployment with Kafka dashboards.

| Variable | Default | Description | Required |
|----------|---------|-------------|----------|
| `grafana_user` | `"grafana"` | System user | No |
| `grafana_group` | `"grafana"` | System group | No |
| `grafana_config_dir` | `"/etc/grafana"` | Configuration directory | No |
| `grafana_provisioning_dir` | `"/etc/grafana/provisioning"` | Provisioning directory | No |
| `grafana_version` | — | Grafana version | No |
| `grafana_port` | — | HTTP port (typically `3000`) | Yes |
| `grafana_host` | — | Grafana bind address | Yes |
| `grafana_admin_password` | — | Admin user password | Yes |

---

## Role: kafka_analysis

Read-only topic configuration analysis.

| Variable | Default | Description | Required |
|----------|---------|-------------|----------|
| `kafka_analysis_bootstrap_server` | `"{{ groups['kafka_broker'][0] }}:..."` | Bootstrap server for analysis | No |
| `kafka_analysis_client_config` | `"{{ kafka_config_dir }}/client.properties"` | Client properties file | No |
| `kafka_analysis_report_dir` | `"{{ playbook_dir }}/../reports"` | Output directory for reports | No |
| `kafka_analysis_include_internal_topics` | `false` | Include `__consumer_offsets` etc. | No |
| `kafka_analysis_auto_detect` | `false` | Auto-detect Kafka installation paths | No |
| `kafka_analysis_zookeeper_connect` | `""` | ZooKeeper connection (legacy clusters only) | No |

---

## Host Variables

These are set per-host in `host_vars/<hostname>/main.yml`:

| Variable | Description | Required |
|----------|-------------|----------|
| `node_id` | Unique Kafka node ID (integer) | Yes |
| `monitoring_role` | Monitoring host role: `"prometheus"` or `"grafana"` | For monitoring hosts |
