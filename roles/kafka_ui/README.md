# kafka_ui

Deploys Kafbat UI (formerly known as Kafka UI) for web-based Kafka cluster management and monitoring.

## Requirements

Requires Kafka brokers to be deployed and accessible.

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `kafka_ui_version` | `1.4.2` | Version of Kafbat UI to install |
| `kafka_ui_port` | `8080` | Port for the UI web interface |
| `kafka_ui_user` | `kafkaui` | System user for running Kafbat UI |
| `kafka_ui_group` | `kafkaui` | System group for running Kafbat UI |
| `kafka_ui_jar` | `api-v{{ kafka_ui_version }}.jar` | JAR file name |
| `kafka_ui_download_url` | `https://github.com/kafbat/kafka-ui/releases/download/v{{ kafka_ui_version }}/{{ kafka_ui_jar }}` | Download URL for Kafbat UI JAR |
| `kafka_ui_install_dir` | `/opt/kafka-ui` | Installation directory |
| `kafka_ui_config_dir` | `/etc/kafka-ui` | Configuration directory |
| `kafka_ui_cluster_name` | `kafka-cluster` | Display name for the Kafka cluster |
| `kafka_ui_bootstrap_servers` | `localhost:9092` | Kafka bootstrap servers to connect to |

## Dependencies

- osodevops.kafka_platform.kafka_broker (must be running)

## Example Playbook

```yaml
- hosts: monitoring
  roles:
    - osodevops.kafka_platform.kafka_ui
```

## License

Apache-2.0
