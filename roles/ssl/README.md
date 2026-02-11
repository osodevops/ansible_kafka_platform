# ssl

Generates TLS certificates including Certificate Authority, keystores, and truststores for secure Kafka communication.

## Requirements

Requires the `common` role to be run first for OpenSSL and CA certificate packages.

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ssl_ca_dir` | `{{ kafka_ssl_dir }}/ca` | Directory for Certificate Authority files |
| `ssl_ca_key` | `{{ ssl_ca_dir }}/ca-key.pem` | Path to CA private key |
| `ssl_ca_cert` | `{{ ssl_ca_dir }}/ca-cert.pem` | Path to CA certificate |
| `ssl_keystore_type` | `PKCS12` | Keystore format type |
| `ssl_truststore_file` | `{{ kafka_ssl_dir }}/kafka.truststore.p12` | Path to truststore file |

## Dependencies

- osodevops.kafka_platform.common

## Example Playbook

```yaml
- hosts: kafka_controller:kafka_broker
  roles:
    - osodevops.kafka_platform.ssl
```

## License

Apache-2.0
