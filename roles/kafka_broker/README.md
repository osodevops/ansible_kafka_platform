# kafka_broker

Deploys and configures Kafka broker nodes with SASL/SCRAM authentication and SSL encryption.

## Requirements

Requires `common`, `ssl`, and `kafka_install` roles to be run first. Controller nodes must be deployed and running.

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `kafka_broker_health_check_retries` | `15` | Number of health check attempts during startup |
| `kafka_broker_health_check_delay` | `10` | Delay in seconds between health check retries |
| `kafka_broker_port_timeout` | `120` | Timeout in seconds for broker port to become available |
| `kafka_health_check_address` | `{{ ansible_host }}` | Address to use for health checks |
| `kafka_broker_client_port` | `{{ kafka_broker_ssl_port }}` | Client connection port for the broker |

## Dependencies

- osodevops.kafka_platform.common
- osodevops.kafka_platform.ssl
- osodevops.kafka_platform.kafka_install
- osodevops.kafka_platform.kafka_controller (must be running)

## Example Playbook

```yaml
- hosts: kafka_broker
  roles:
    - osodevops.kafka_platform.kafka_broker
```

## License

Apache-2.0
