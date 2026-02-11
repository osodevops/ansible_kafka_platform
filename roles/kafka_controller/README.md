# kafka_controller

Deploys and configures Kafka KRaft controller nodes for cluster metadata management.

## Requirements

Requires `common`, `ssl`, and `kafka_install` roles to be run first.

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `kafka_controller_health_check_retries` | `15` | Number of health check attempts during startup |
| `kafka_controller_health_check_delay` | `10` | Delay in seconds between health check retries |
| `kafka_controller_port_timeout` | `120` | Timeout in seconds for controller port to become available |
| `kafka_health_check_address` | `{{ ansible_host }}` | Address to use for health checks |

## Dependencies

- osodevops.kafka_platform.common
- osodevops.kafka_platform.ssl
- osodevops.kafka_platform.kafka_install

## Example Playbook

```yaml
- hosts: kafka_controller
  roles:
    - osodevops.kafka_platform.kafka_controller
```

## License

Apache-2.0
