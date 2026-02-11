# prometheus

Deploys Prometheus monitoring server configured to scrape metrics from Kafka brokers and controllers.

## Requirements

Requires JMX exporter to be configured on Kafka nodes.

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `prometheus_user` | `prometheus` | System user for running Prometheus |
| `prometheus_group` | `prometheus` | System group for running Prometheus |
| `prometheus_config_dir` | `/etc/prometheus` | Configuration directory |
| `prometheus_version` | `3.2.1` | Version of Prometheus to install |
| `prometheus_arch` | `{{ 'arm64' if ansible_architecture == 'aarch64' else 'amd64' }}` | Architecture for binary download |
| `prometheus_binary_url` | `https://github.com/prometheus/prometheus/releases/download/v{{ prometheus_version }}/prometheus-{{ prometheus_version }}.linux-{{ prometheus_arch }}.tar.gz` | Download URL for Prometheus binary |

## Dependencies

None (but typically deployed alongside Kafka cluster with JMX exporter enabled)

## Example Playbook

```yaml
- hosts: monitoring
  roles:
    - osodevops.kafka_platform.prometheus
```

## License

Apache-2.0
