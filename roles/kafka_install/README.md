# kafka_install

Downloads and installs Apache Kafka binaries to the target hosts.

## Requirements

Requires the `common` role for curl and necessary system utilities.

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `kafka_download_dest` | `/tmp/{{ kafka_package }}.tgz` | Temporary download location for Kafka archive |
| `kafka_force_download` | `false` | Force re-download even if package exists |

## Dependencies

- osodevops.kafka_platform.common

## Example Playbook

```yaml
- hosts: kafka_controller:kafka_broker
  roles:
    - osodevops.kafka_platform.kafka_install
```

## License

Apache-2.0
