{ config, lib, pkgs, modulesPath, ... }:

{
  #networking.hostName = "nixos"; # Define your hostname - might already be defined.
  # Action: update as needed
  time.timeZone = "America/Chicago";

  # Action: update as needed
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  nixpkgs.config.allowUnfree = true;

  # Example: how to install system-wide packages
  # Action: add additional packages here as needed
  environment.systemPackages = with pkgs; [
    alacritty
    cowsay
    lolcat
    man
    htop
    neovim
    tree
    tmux
    fd
    wget
    sysstat
    curl
    rsync
    zip
    unzip
    pkg-config
    gcc
    cmake
    jc
    jq
    pass
    ripgrep
    bat
  ];

  # zram does NOT work in incus - DOES work in aws
  # uncommend the following lines as is needed
  # Note: the following automatically installs zram-generator
  # Note: consider moving this to its own nix config file for easy inclusion
  #zramSwap.enable = true; 
  #zramSwap.memoryPercent = 90;

  # nix-ld references
  # https://youtu.be/CwfKlX3rA6E?si=wDWkispwUy44yxdq (11:23)
  # https://www.youtube.com/watch?v=Wn-6Ls-yJAQ&t=133
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    # Add any missing dynamic libraries for unpackaged 
    # programs here, NOT in environment.systemPackages
  ];

  # Action: updated git settings as needed
  programs.git = {
    enable = true;
    lfs.enable = true;
    config.credential.helper = "cache --timeout 7200";
    #config.user.email = "chuck@chuboe.com";
    #config.user.name = "Chuck Boecking";
  };

  programs.starship = {
    enable = true;
    settings = {
      container.disabled = true;
    };
  };

  # Example: of how to create aliases
  # Action: add aliases as needed
  environment.shellAliases = {
    "vim" = "nvim";
    "vi" = "nvim";
    "h" = "history";
  };

  # make it easy to nagivate bash history by using a couple of letters and the up arrow
  environment.etc."inputrc" = {
  text = pkgs.lib.mkDefault( pkgs.lib.mkAfter ''
      #  alternate mappings for "page up" and "page down" to search the history
      "\e[A": history-search-backward            # arrow up
      "\e[B": history-search-forward             # arrow down
    '');
  };

  # Enable if ssh service needed 
  # Action: update/enable ssh server as needed
  services.openssh = {
    enable = false;
    # require public key authentication for better security
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
    #settings.PermitRootLogin = "yes";
  };

  # Open ports in the firewall.
  # Or disable the firewall altogether.
  # Action: update firewall as needed
  networking.firewall = {
    enable = true;
    allowPing = false;
    #allowedTCPPorts = [ 99 999 ];
    #allowedUDPPorts = [ ... ];
    #extraCommands = ''
      # add stuff here
    #''
  };
}
