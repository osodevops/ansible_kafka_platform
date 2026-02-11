# kafka_topics

Creates and manages Kafka topics with specified configurations including partitions, replication factors, and topic-level settings.

## Requirements

Requires Kafka brokers to be deployed and running.

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `kafka_topics_bootstrap_server` | `{{ groups['kafka_broker'][0] }}:{{ kafka_broker_client_port }}` | Bootstrap server address for topic operations |
| `kafka_topics_client_config` | `{{ kafka_config_dir }}/client.properties` | Path to client configuration file with authentication settings |

## Dependencies

- osodevops.kafka_platform.kafka_broker (must be running)

## Example Playbook

```yaml
- hosts: kafka_broker[0]
  roles:
    - osodevops.kafka_platform.kafka_topics
```

## License

Apache-2.0
