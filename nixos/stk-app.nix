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
  # Example: bash/bin script for service
  run-migrations = pkgs.writeScriptBin "run-migrations" ''
    #!${pkgs.bash}/bin/bash
    set -e

    # Set your database URL
    export DATABASE_URL="postgresql://stk_superuser/stk_db?host=/run/postgresql"

    # Set the Git repository URL and the local path where it should be cloned
    REPO_URL="https://github.com/chuckstack/stk-app-sql.git"
    CLONE_PATH="/tmp/db-migrations"

    # Ensure the clone directory is empty
    rm -rf "$CLONE_PATH"

    # Clone the repository
    ${pkgs.git}/bin/git clone "$REPO_URL" "$CLONE_PATH"

    # Change to the cloned directory
    cd "$CLONE_PATH"

    # Run the migrations
    ${pkgs.sqlx-cli}/bin/sqlx migrate run

    # Clean up
    cd /
    rm -rf "$CLONE_PATH"
  '';
in
{
  # PostgreSQL configuration
  services.postgresql = {
    #ensureDatabases = [ "stk_db" ];
    #ensureUsers = [
    #  {
    #    name = "stk_superuser";
    #  }
    #];
    # This will set the owner of the database after it's created
    # Note: this section needs stay in sync with stk-app-sql => test => shell.nix
    # Example: of a sql script that is only run once
    initialScript = pkgs.writeText "stk-init.sql" ''
      CREATE ROLE stk_superuser LOGIN CREATEROLE; 
      COMMENT ON ROLE stk_superuser IS 'superuser role to administer the stk_db database';
      CREATE DATABASE stk_db OWNER stk_superuser;
    '';
  };

  environment.systemPackages = [ run-migrations pkgs.git pkgs.sqlx-cli ];

  # Action: to re-run migrations, simply restart this service
  systemd.services.stk-db-migrations = {
    description = "Clone migration repo and run database migrations";
    after = [ "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "stk_superuser";
      ExecStart = "${run-migrations}/bin/run-migrations";
    };
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
