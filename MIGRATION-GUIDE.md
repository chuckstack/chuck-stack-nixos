# Migration Guide: From sqlx to chuck-stack-nushell-psql-migration

This guide documents the migration process from sqlx-cli to chuck-stack-nushell-psql-migration for managing database migrations in chuck-stack-nixos.

## Overview

Chuck-stack has moved from using sqlx-cli to a custom nushell-based migration utility. This change provides better integration with the chuck-stack ecosystem and more flexibility in migration management.

## Breaking Changes

### 1. Environment Variables
- **Before**: Used `DATABASE_URL` format
- **After**: Uses individual PostgreSQL environment variables:
  - `PGHOST` - PostgreSQL host (typically `/run/postgresql` for Unix sockets)
  - `PGUSER` - PostgreSQL user
  - `PGDATABASE` - Database name

### 2. Migration Command Syntax
- **Before**: `sqlx migrate run`
- **After**: `migrate run ./migrations`

### 3. Required Dependencies
- **Removed**: `pkgs.sqlx-cli`
- **Added**: 
  - `pkgs.nushell` - Required for running the migration utility
  - `chuck-stack-nushell-psql-migration` - Fetched from GitHub

### 4. Additional Configuration
- Added `.psqlrc-nu` file for nushell-compatible psql output
- PSQLRC must be disabled during migrations to avoid role errors

## Migration Steps

### 1. Backup Your Current Configuration
```bash
cp /etc/nixos/chuck-stack-nixos/nixos/stk-app.nix /etc/nixos/chuck-stack-nixos/nixos/stk-app.nix.backup
```

### 2. Update stk-app.nix
Replace your current `stk-app.nix` with the updated version that uses chuck-stack-nushell-psql-migration.

Key changes in the file:
- Added fetching of migration utility from GitHub
- Updated `run-migrations` script to use nushell
- Added proper environment variable setup
- Added `.psqlrc-nu` configuration

### 3. Test the Migration
Before applying to production:

```bash
# Test in a NixOS container or VM
nixos-rebuild test

# Verify migration service
systemctl status stk-db-migrations

# Check logs if needed
journalctl -u stk-db-migrations
```

### 4. Apply Changes
```bash
nixos-rebuild switch
```

## Verification

After migration, verify:

1. **Database migrations ran successfully**:
   ```bash
   su - stk_superuser
   psql
   # Check migration history table
   ```

2. **PostgREST is running**:
   ```bash
   systemctl status postgrest
   curl http://localhost:3000/stk_request
   ```

3. **No error in logs**:
   ```bash
   journalctl -u stk-db-migrations -u postgrest
   ```

## Rollback Procedure

If issues occur:

1. Restore the backup configuration:
   ```bash
   cp /etc/nixos/chuck-stack-nixos/nixos/stk-app.nix.backup /etc/nixos/chuck-stack-nixos/nixos/stk-app.nix
   ```

2. Rebuild NixOS:
   ```bash
   nixos-rebuild switch
   ```

## Troubleshooting

### Common Issues

1. **"role stk_api_role does not exist" error**
   - Ensure PSQLRC is set to /dev/null during migrations
   - This role is created by the migrations themselves

2. **Migration utility not found**
   - Check that the GitHub fetch succeeded
   - Verify the SHA256 hash is correct

3. **Nushell command not found**
   - Ensure `pkgs.nushell` is in environment.systemPackages

### Debug Commands

```bash
# Test migration manually
su - stk_superuser
export PGHOST=/run/postgresql
export PGUSER=stk_superuser
export PGDATABASE=stk_db
export PSQLRC=/dev/null

# Clone and run migrations manually
git clone https://github.com/chuckstack/chuck-stack-nushell-psql-migration /tmp/migration-util
git clone https://github.com/chuckstack/chuck-stack-core /tmp/chuck-stack-core
cd /tmp/chuck-stack-core
nu -c "use /tmp/migration-util/src/mod.nu *; migrate status ./migrations"
```

## Repository Change Notice

**Important**: The migrations have moved from the separate `stk-app-sql` repository to the main `chuck-stack-core` repository in the `migrations/` subdirectory. This consolidation simplifies the development workflow.

## Additional Notes

- The migration utility provides better error messages and status tracking
- Migrations are now sourced from the chuck-stack-core repository
- The pg_jsonschema extension files are included in chuck-stack-core
- The new setup aligns with chuck-stack-core's test environment pattern
- Consider pinning the chuck-stack-core revision for production stability