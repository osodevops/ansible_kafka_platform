# kafka_analysis

Analyzes Kafka cluster configuration and generates reports on topic settings, identifying read-only topics and configuration drift.

## Requirements

Requires Kafka brokers to be deployed and accessible. Read-only access to cluster is sufficient.

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `kafka_analysis_bootstrap_server` | `{{ groups['kafka_broker'][0] }}:{{ kafka_broker_client_port }}` | Bootstrap server for cluster analysis |
| `kafka_analysis_client_config` | `{{ kafka_config_dir }}/client.properties` | Path to client configuration with authentication |
| `kafka_analysis_report_dir` | `{{ playbook_dir }}/../reports` | Directory to save analysis reports |
| `kafka_analysis_include_internal_topics` | `false` | Whether to include internal topics in analysis |
| `kafka_analysis_auto_detect` | `false` | Enable auto-detection for unknown/legacy clusters |
| `kafka_analysis_zookeeper_connect` | `""` | ZooKeeper connection string (only for Kafka < 2.6 when auto-detected) |

## Dependencies

- osodevops.kafka_platform.kafka_broker (must be running)

## Example Playbook

```yaml
- hosts: kafka_broker[0]
  roles:
    - osodevops.kafka_platform.kafka_analysis
```

## License

Apache-2.0
