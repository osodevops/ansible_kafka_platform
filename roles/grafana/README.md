# grafana

Deploys Grafana with pre-configured dashboards for Kafka cluster monitoring and visualization.

## Requirements

Requires Prometheus to be deployed and collecting Kafka metrics.

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `grafana_user` | `grafana` | System user for running Grafana |
| `grafana_group` | `grafana` | System group for running Grafana |
| `grafana_config_dir` | `/etc/grafana` | Configuration directory |
| `grafana_provisioning_dir` | `/etc/grafana/provisioning` | Directory for datasources and dashboard provisioning |
| `grafana_apt_key_url` | `https://apt.grafana.com/gpg.key` | APT repository GPG key URL |
| `grafana_apt_repo` | `deb https://apt.grafana.com stable main` | APT repository configuration |

## Dependencies

- osodevops.kafka_platform.prometheus (recommended)

## Example Playbook

```yaml
- hosts: monitoring
  roles:
    - osodevops.kafka_platform.grafana
```

## License

Apache-2.0
