{ config, lib, pkgs, modulesPath, ... }:

# Notes:
  # discussed in https://www.chuck-stack.org/ls/stack-architecture.html
  # get list of requests via api from localhost:
    # curl http://localhost:3000/stk_request
  # add request via api from localhost:
    # curl http://localhost:3000/stk_request -X POST -H "Content-Type: application/json" -d '{"name": "do great things"}'
  # submit form - call to function 
    # curl http://localhost:3000/rpc/stk_form_post_fn -X POST -H "Content-Type: application/json" -d '{"name": "you know who"}'
  # get list of requests through nginx via ip -- assumes self signed (insecure)
    # curl --insecure https://10.2.2.2/stk_request

#TODO: need to update this file to better use variables (postgresPort, postgresUser, postgresDb, ...)
let
  postgrestPort = 3000; # Example: variable
  postgresUser = "postgrest";
  postgresDb = "stk_db";
  
  # Fetch chuck-stack-nushell-psql-migration source
  migrationUtilSrc = pkgs.fetchgit {
    url = "https://github.com/chuckstack/chuck-stack-nushell-psql-migration";
    rev = "e67c7c8e5ed411314396585f53106ef51868ac00";  # suppressed migration table not found error
    sha256 = "sha256-EL6GEZ3uvBsnR8170SBY+arVfUsLXPVxKPEOqIVgedA=";
  };
  
  # Fetch chuck-stack-core for pg_jsonschema extension files
  # Using fetchTarball temporarily to avoid hash issues during testing
  # For production, use fetchgit with a pinned revision and correct hash
  chuckStackCoreSrc = pkgs.fetchTarball {
    url = "https://github.com/chuckstack/chuck-stack-core/archive/main.tar.gz";
  };
  
  # Create pg_jsonschema extension package
  # This is needed for chuck-stack's JSON schema validation
  # Note: The extension files in /test/pg_extension/17 are for PostgreSQL 17
  # If using a different PostgreSQL version, you may need different extension files
  pg_jsonschema_ext = pkgs.stdenv.mkDerivation {
    name = "pg_jsonschema-extension";
    src = "${chuckStackCoreSrc}/test/pg_extension/17";
    installPhase = ''
      mkdir -p $out/lib $out/share/postgresql/extension
      cp pg_jsonschema.so $out/lib/
      cp pg_jsonschema.control $out/share/postgresql/extension/
      cp pg_jsonschema--0.3.3.sql $out/share/postgresql/extension/
    '';
  };
  
  # Combine PostgreSQL with extension using buildEnv
  postgresql-with-jsonschema = pkgs.buildEnv {
    name = "postgresql-with-jsonschema";
    paths = [ pkgs.postgresql pg_jsonschema_ext ];
    passthru = {
      # Pass through required attributes from the base PostgreSQL package
      psqlSchema = pkgs.postgresql.psqlSchema;
      version = pkgs.postgresql.version;
    };
  };
  
  # Example: bash/bin script for service
  run-migrations = pkgs.writeScriptBin "run-migrations" ''
    #!${pkgs.bash}/bin/bash
    set -e

    # Set PostgreSQL connection environment variables
    export PGHOST=/run/postgresql
    export PGUSER=stk_superuser
    export PGDATABASE=${postgresDb}
    
    # Disable .psqlrc during migrations to avoid role errors
    export PSQLRC=/dev/null

    # Set the Git repository URL and local paths
    CHUCK_STACK_CORE_URL="https://github.com/chuckstack/chuck-stack-core.git"
    MIGRATION_UTIL_PATH="/tmp/chuck-stack-migration-util"
    CHUCK_STACK_CORE_PATH="/tmp/chuck-stack-core"

    # Ensure directories are clean
    rm -rf "$MIGRATION_UTIL_PATH" "$CHUCK_STACK_CORE_PATH"

    # Setup migration utility
    mkdir -p "$MIGRATION_UTIL_PATH"
    cp -r ${migrationUtilSrc}/src/* "$MIGRATION_UTIL_PATH/"

    # Clone chuck-stack-core repository which contains migrations
    ${pkgs.git}/bin/git clone "$CHUCK_STACK_CORE_URL" "$CHUCK_STACK_CORE_PATH"

    # Change to chuck-stack-core directory
    cd "$CHUCK_STACK_CORE_PATH"

    # Run the migrations using nushell (migrations are in ./migrations subdirectory)
    ${pkgs.nushell}/bin/nu -c "use $MIGRATION_UTIL_PATH/mod.nu *; migrate run ./migrations"

    # Clean up
    cd /
    rm -rf "$MIGRATION_UTIL_PATH" "$CHUCK_STACK_CORE_PATH"
  '';
in
{
  # PostgreSQL configuration
  services.postgresql = {
    # Note: this section needs stay in sync with chuck-stack-core => test => shell.nix
    package = postgresql-with-jsonschema;
    # Example: of a sql script that is only run once
    initialScript = pkgs.writeText "stk-init.sql" ''
      CREATE ROLE stk_superuser LOGIN CREATEROLE; 
      COMMENT ON ROLE stk_superuser IS 'superuser role to administer the stk_db database';
      CREATE DATABASE stk_db OWNER stk_superuser;
    '';
  };

  environment.systemPackages = [ 
    run-migrations 
    pkgs.git 
    pkgs.nushell  # Required for migration utility
    # Remove sqlx-cli as it's no longer needed
  ];

  # Action: to re-run migrations, simply restart this service
  systemd.services.stk-db-migrations = {
    description = "Clone migration repo and run database migrations";
    after = [ "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "stk_superuser";
      ExecStart = "${run-migrations}/bin/run-migrations";
      # Add environment variables that might be needed
      Environment = [
        "PGHOST=/run/postgresql"
        "PGUSER=stk_superuser"
        "PGDATABASE=${postgresDb}"
      ];
    };
  };

  # create a global .psqlrc
  environment.etc.".psqlrc" = {
    text = ''
      \set datetag `date +'%F_%H-%M-%S'`
      \set QUIET 1
      \set PROMPT1 '%[%033[1m%]%M %n@%/%R%[%033[0m%]%# '
      \set PROMPT2 '[more] %R > '
      \pset null '[NULL]'
      \x auto
      \set VERBOSITY verbose
      \set HISTFILE .psql_history
      \set HISTCONTROL ignoredups
      \set COMP_KEYWORD_CASE upper
      \set PSQL_EDITOR ${pkgs.neovim}/bin/nvim
      \set EDITOR ${pkgs.neovim}/bin/nvim
      \set VISUAL ${pkgs.neovim}/bin/nvim
      \set ON_ERROR_ROLLBACK interactive
      \set HISTSIZE 5000

      --TODO: need to figure out a good strategy for the following
          --until then, just comment them out
      --\set STK_PG_ROLE `echo $STK_PG_ROLE`
      --SET ROLE :STK_PG_ROLE;

      --\set STK_PG_SESSION `echo $STK_PG_SESSION`
      --SET stk.session = :STK_PG_SESSION;
    '';
    mode = "0644";  # everyone can read
  };
  
  # Create a nushell-compatible .psqlrc
  environment.etc.".psqlrc-nu" = {
    text = ''
      \pset null 'null'
      \pset format csv
      \pset tuples_only on
    '';
    mode = "0644";
  };

  # Example: showing how to apply bash settings to all users
  programs.bash = {
    shellInit = ''
      # Code to run for all users
    '';
    interactiveShellInit = ''
      # Code to run for all interactive shells
      export PGDATABASE=stk_db
      export PSQLRC=/etc/.psqlrc
      #alias ll='ls -la'
    '';
  };

  users.users = {
    # Service user without login capabilities
    # Example: of a system user for a service
    postgrest = {
      isSystemUser = true;
      group = "postgrest";
      description = "User for running the postgREST service";

      # comment these lines if you do not need the user to have a home
      home = "/var/lib/postgrest";
      createHome = true;
      shell = pkgs.bashInteractive;  # or pkgs.nologin if you want to prevent interactive login

    };
    stk_superuser = {
      isSystemUser = true;
      group = "stk_superuser";
      description = "User for managing stk_db";

      # comment these lines if you do not need the user to have a home
      home = "/var/lib/stk_superuser";
      createHome = true;
      shell = pkgs.bashInteractive;  # or pkgs.nologin if you want to prevent interactive login
    };
  };

  # Create a group for the service user
  users.groups.postgrest = {};
  users.groups.stk_superuser = {};

  # Create Postgrest configuration file directly in the Nix configuration
  # Example: creating a configuration file for services located in /etc
  environment.etc."postgrest.conf" = {
    text = ''
      db-uri = "postgres://${postgresUser}@/${postgresDb}?host=/run/postgresql"
      db-schema = "api"
      db-anon-role = "stk_api_role"
      server-port = ${toString postgrestPort}
      # jwt-secret = "your-jwt-secret"
      # max-rows = 1000

      # Add any other Postgrest configuration options here
    '';
    mode = "0600";  # More restrictive permissions due to sensitive information

  };

  # Example: of how to run a script upon activation
  system.activationScripts = {
    postgrestConf = ''
      chown postgrest:postgrest /etc/postgrest.conf
    '';
  };

  # Example: systemd service configuration file
  systemd.services.postgrest = {
    description = "PostgREST Service";
    after = [ "network.target" "postgresql.service" "stk-db-migrations.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.postgrest}/bin/postgrest /etc/postgrest.conf";
      Restart = "always";
      RestartSec = "10s";
      User = "postgrest";
      Group = "postgrest";
    };
  };

  # Open firewall for PostgREST - only needed if nginx is running on a different machine
  #networking.firewall.allowedTCPPorts = [ postgrestPort ];
}