{ config, lib, pkgs, modulesPath, ... }:

{
  environment.systemPackages = with pkgs; [
    # jdk17_headless
    # maven
  ];

  # Ref: https://nixos.wiki/wiki/ACME
  # Ref: https://nixos.org/manual/nixos/stable/index.html#module-security-acme
  # Note: the below will fail to get a cert as is; however, it allows you to use ssl
  # Note: you do not need acme if you are using a cloudflare tunnel
  # Use the following to create your first page
    # mkdir -p /var/www/blog/; echo "hello world" > /var/www/blog/index.html

  # Example: ssl certification
  security.acme.acceptTerms = true;
  security.acme.defaults.email = "chuck@chuboe.com";
  services.nginx = {
    enable = true;
    virtualHosts = {
      #"localhost" = {
      #  locations."/" = {
      #    proxyPass = "http://localhost:3000";
      #    #proxyWebsockets = true;
      #  };
      #};
      "blog.example.com" = {
        forceSSL = true;
        enableACME = true;
        serverAliases = [ "myblog.example.com" ];
        locations = {

          # Example: nginx configuration
          # Action: update (uncomment or add) nginx paths according to your needs
          # Root "/" path
          "/" = {
            #return = "404";   # Uncomment "/" if you wish to block the root url access - openapi/swagger
            proxyPass = "http://localhost:3000";
            #proxyWebsockets = true;   # Uncomment if needed
          };

          ## Allow access to any non-empty path (any table) - use if root url is blocked above
          #"~ ^/(?!$).*" = {
          #  proxyPass = "http://localhost:3000";
          #  return = "404"; # Uncomment "/" if you wish to block
          #};

          ## Allow access to a specific path - use if root url is blocked above and you want the most strict/limiting rules
          #"/stk_wf_request" = {
          #  proxyPass = "http://localhost:3000";
          #};

          ## Allow access to functions - use if root url is blocked above and you want to grant access to one or more functions
          #"/rpc" = {
          #  proxyPass = "http://localhost:3000";
          #};

        };
      };
    };

    # Enable access and error logging
    appendHttpConfig = ''
      access_log /var/log/nginx/access.log;
      error_log /var/log/nginx/error.log;
    '';
  };

  # Action: updated ssl acme cert for production if needed
  # staging server used for testing
  security.acme.defaults.server = "https://acme-staging-v02.api.letsencrypt.org/directory";

  environment.shellAliases = {
    "j" = "javac"; # Example: of defining an alias within a specific config
  };

  # Example: Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 80 443 ];
  # networking.firewall.allowedUDPPorts = [ ... ];
}
