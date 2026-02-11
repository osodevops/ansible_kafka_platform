# common

Prepares the operating system with prerequisites for Kafka deployment including package installation, Java runtime, kernel tuning, and system limits configuration.

## Requirements

None - this is typically the first role to run.

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `common_packages` | `[openjdk-21-jdk-headless, xfsprogs, acl, chrony, net-tools, curl, openssl, ca-certificates, gnupg, lsb-release]` | List of system packages to install |
| `kafka_sysctl_params` | See defaults | Dictionary of kernel parameters for network and memory tuning |
| `kafka_nofile_limit` | `128000` | Maximum number of open files for Kafka user |
| `kafka_nproc_limit` | `65536` | Maximum number of processes for Kafka user |

## Dependencies

None

## Example Playbook

```yaml
- hosts: kafka_controller:kafka_broker
  roles:
    - osodevops.kafka_platform.common
```

## License

Apache-2.0
