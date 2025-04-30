{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.datum-gateway;
  # Example: inherit (config.services) bitcoind; # Uncomment and adapt if needed
in {
  options.services.datum-gateway = {
    enable = mkEnableOption "DATUM Gateway service";
    # TODO: Add other configuration options specific to DATUM Gateway
    # Example: package = mkOption { ... };
    # Example: dataDir = mkOption { ... };
  };

  config = mkIf cfg.enable {
    # TODO: Define systemd service and other configurations
    # Example: 
    # systemd.services.datum-gateway = {
    #   description = "DATUM Gateway";
    #   after = [ "network.target" ]; # Add dependencies like bitcoind if needed
    #   wantedBy = [ "multi-user.target" ];
    #   serviceConfig = {
    #     User = "datum-gateway"; # Consider creating a dedicated user
    #     Group = "datum-gateway";
    #     ExecStart = ''
    #       ${pkgs.datum-gateway}/bin/datum-gateway \
    #         # Add command line arguments based on cfg options
    #     '';
    #     # Add other service config options: Restart, WorkingDirectory, etc.
    #   };
    # };

    # Example: Create user/group
    # users.users.datum-gateway = {
    #   isSystemUser = true;
    #   group = "datum-gateway";
    #   # home = cfg.dataDir; # If dataDir is defined
    # };
    # users.groups.datum-gateway = {};
  };
}
