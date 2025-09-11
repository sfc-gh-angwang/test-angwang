# Vault Secrets Buildkite Plugin

A Buildkite plugin that fetches secrets from HashiCorp Vault using Snowflake's `setup_rt_vault_credentials.sh` logic. This plugin handles authentication automatically based on the user context and provides robust retry mechanisms.

## Features

- **Smart Authentication**: Automatically detects Jenkins vs non-Jenkins environments
- **Jenkins AppRole**: Uses Vault AppRole authentication for Jenkins users
- **Token Validation**: Validates existing Vault tokens for non-Jenkins users
- **Robust Retry Logic**: Built-in retry mechanisms for all Vault operations
- **Atomic Output**: Thread-safe output using flock to prevent interleaved logs
- **Flexible Secret Fetching**: Support for both individual fields and full JSON secrets

## Example

### Mixed Secret Fetching (Field and JSON)

```yaml
steps:
  - label: "Run Tests with Secrets"
    command: "./run_tests.sh"
    env:
      VAULT_ADDR: "https://vault.ci1.private.app.snowflake.com:8200"
      VAULT_ROLE_ID: "your-role-id"
      VAULT_SECRET_ID: "your-secret-id"
    plugins:
      - vault-secrets:
          secrets:
            # Field-based fetching (default)
            - path: "secret/jenkins/rt-tests/database-creds"
              env_name: "DB_PASSWORD"
              field: "password"
            - path: "secret/jenkins/rt-tests/database-creds"
              env_name: "DB_USERNAME"
              field: "username"
            # JSON-based fetching
            - path: "secret/jenkins/rt-tests/api-config"
              env_name: "API_CONFIG_JSON"
              use_json: true
            - path: "secret/data/certificates"
              env_name: "CERTS_JSON"
              use_json: true
```

## Configuration

### Required

- `secrets` (array): List of secrets to fetch from Vault

### Optional

None - all configuration is handled via environment variables.

### Environment Variables

The plugin uses these environment variables:

- `VAULT_ADDR`: Vault server address (default: "https://vault.ci1.private.app.snowflake.com:8200")
- `VAULT_PATH`: Path to Vault binary directory (default: "/opt/sfc/vault/")
- `VAULT_SKIP_VERIFY`: Skip TLS verification (default: "1")
- `VAULT_ROLE_ID`: Vault AppRole role ID (for Jenkins users)
- `VAULT_SECRET_ID`: Vault AppRole secret ID (for Jenkins users)
- `VAULT_TOKEN`: Valid Vault token (for non-Jenkins users)
- `USERNAME`: Username for manual token instructions

### Secrets Configuration

Each secret in the `secrets` array supports:

- `path` (string, required): Full Vault secret path (e.g., "secret/jenkins/rt-tests/database-creds")
- `env_name` (string, required): Environment variable name to store the secret value
- `field` (string, optional): Field name within the secret (default: "data") - ignored when `use_json` is true
- `use_json` (boolean, optional): Whether to read this secret in JSON format (default: false)

## Authentication

The plugin automatically detects the runtime environment and uses the appropriate authentication method:

### Jenkins Users (`$USER == jenkins`)

Uses **Vault AppRole** authentication via environment variables:

```yaml
env:
  VAULT_ADDR: "https://vault.ci1.private.app.snowflake.com:8200"
  VAULT_ROLE_ID: "your-vault-role-id"
  VAULT_SECRET_ID: "your-vault-secret-id"

steps:
  - plugins:
      - vault-secrets:
          secrets:
            - path: "secret/jenkins/rt-tests/my-secret"
              env_name: "MY_SECRET"
```

### Non-Jenkins Users

Requires a **valid VAULT_TOKEN** environment variable:

```yaml
env:
  VAULT_ADDR: "https://vault.ci1.private.app.snowflake.com:8200"
  VAULT_TOKEN: "your-valid-vault-token"

steps:
  - plugins:
      - vault-secrets:
          secrets:
            - path: "secret/jenkins/rt-tests/my-secret"
              env_name: "MY_SECRET"
```

**Token Validation**: The plugin will check if the provided `VAULT_TOKEN` is valid and not expired. If the token is invalid or expired, the plugin will fail with an error message instructing you to obtain a new token.

## Security Considerations

- Never hardcode Vault credentials in your pipeline configuration
- Use environment variables to pass sensitive authentication data
- AppRole credentials are automatically managed for Jenkins users
- Non-Jenkins users must provide valid tokens externally
- All output is handled securely to prevent credential leakage

## Requirements

- `vault`: Vault CLI binary (expected at `/opt/sfc/vault/` by default)
- `jq`: For parsing JSON responses from Vault

## Error Handling

The plugin includes robust error handling based on Snowflake's production setup:

- **Retry Logic**: All Vault operations use 3-retry logic with 5-second intervals
- **Token Validation**: Automatic token TTL checking with fail-fast on expiration
- **Environment Detection**: Smart authentication method selection
- **Secure Output**: Safe credential export to temporary files
- **Clear Error Messages**: Detailed troubleshooting information

## Troubleshooting

### Common Issues

1. **"vault CLI is not installed"**: Ensure Vault binary is available at the configured path
2. **"VAULT_ROLE_ID is required"**: For Jenkins users, ensure AppRole credentials are set
3. **"Vault token is expired or not found"**: For non-Jenkins users, provide a valid `VAULT_TOKEN` environment variable
4. **"Vault login failed"**: Check your AppRole configuration for Jenkins users
5. **"Failed to fetch secret"**: Verify the secret exists at `/secret/jenkins/rt-tests/{kv_name}`

### Getting a Valid Token (Non-Jenkins Users)

To obtain a valid Vault token for non-Jenkins users:

```bash
# Login with Okta and get a token
vault login -method=okta username=your-username

# Or get just the token
export VAULT_TOKEN=$(vault login -token-only -method=okta username=your-username)
```

### Secret Path Format

All secrets are fetched from the path: `/secret/jenkins/rt-tests/{kv_name}`

For example, if `kv_name` is "database-creds", the full path will be:
`/secret/jenkins/rt-tests/database-creds`

### Debug Mode

To enable more verbose logging, you can modify the hook script to include debug output by setting `set -x` at the beginning of the script.
