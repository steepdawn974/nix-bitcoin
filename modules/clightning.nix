{ config, lib, pkgs, ... }:

with lib;
let
  options.services.clightning = {
    enable = mkEnableOption "clightning, a Lightning Network implementation in C";
    address = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to listen for peer connections.";
    };
    port = mkOption {
      type = types.port;
      default = 9735;
      description = "Port to listen for peer connections.";
    };
    proxy = mkOption {
      type = types.nullOr types.str;
      default = if cfg.tor.proxy then config.nix-bitcoin.torClientAddressWithPort else null;
      description = ''
        Socks proxy for connecting to Tor nodes (or for all connections if option always-use-proxy is set).
      '';
    };
    always-use-proxy = mkOption {
      type = types.bool;
      default = cfg.tor.proxy;
      description = ''
        Always use the proxy, even to connect to normal IP addresses.
        You can still connect to Unix domain sockets manually.
        This also disables all DNS lookups, to avoid leaking address information.
      '';
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/clightning";
      description = "The data directory for clightning.";
    };
    networkDir = mkOption {
      readOnly = true;
      default = "${cfg.dataDir}/${network}";
      description = "The network data directory.";
    };
    wallet = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "sqlite3:///var/lib/clightning/bitcoin/lightningd.sqlite3";
      description = ''
        Wallet data scheme (sqlite3 or postgres) and location/connection
        parameters, as fully qualified data source name.
      '';
    };
    useBcliPlugin = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Use bitcoind (via plugin `bcli`) for getting block data.
        This option is disabled by plugins that use other sources for
        fetching block data, like `trustedcoin`.
      '';
    };
    extraConfig = mkOption {
      type = types.lines;
      default = "";
      example = ''
        alias=mynode
      '';
      description = ''
        Extra lines appended to the configuration file.

        See all available options at
        https://github.com/ElementsProject/lightning/blob/master/doc/lightningd-config.5.md
        or by running {command}`lightningd --help`.
      '';
    };
    user = mkOption {
      type = types.str;
      default = "clightning";
      description = "The user as which to run clightning.";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = "The group as which to run clightning.";
    };
    package = mkOption {
      type = types.package;
      default = nbPkgs.clightning;
      defaultText = "config.nix-bitcoin.pkgs.clightning";
      description = "The package providing clightning binaries.";
    };
    cli = mkOption {
      readOnly = true;
      default = pkgs.writers.writeBashBin "lightning-cli" ''
        ${cfg.package}/bin/lightning-cli --lightning-dir='${cfg.dataDir}' "$@"
      '';
      defaultText = "(See source)";
      description = "Binary to connect with the clightning instance.";
    };
    getPublicAddressCmd = mkOption {
      type = types.str;
      default = "";
      description = ''
        Bash expression which outputs the public service address to announce to peers.
        If left empty, no address is announced.
      '';
    };
    tor = nbLib.tor;
  };

  cfg = config.services.clightning;
  nbLib = config.nix-bitcoin.lib;
  nbPkgs = config.nix-bitcoin.pkgs;

  inherit (config.services) bitcoind;

  network = bitcoind.makeNetworkName "bitcoin" "regtest";
  configFile = pkgs.writeText "config" ''
    network=${network}
    ${optionalString (!cfg.useBcliPlugin) "disable-plugin=bcli"}
    ${optionalString (cfg.proxy != null) "proxy=${cfg.proxy}"}
    always-use-proxy=${boolToString cfg.always-use-proxy}
    bind-addr=${cfg.address}:${toString cfg.port}
    bitcoin-rpcconnect=${nbLib.address bitcoind.rpc.address}
    bitcoin-rpcport=${toString bitcoind.rpc.port}
    bitcoin-rpcuser=${bitcoind.rpc.users.public.name}
    rpc-file-mode=0660
    log-timestamps=false
    ${optionalString (cfg.wallet != null) "wallet=${cfg.wallet}"}
    ${ # TODO-EXTERNAL: When updating from a version of clightning before 22.11
       # to version 22.11.1, then the database upgrade needs to be allowed
       # explicitly. Remove this when it's unlikely that this module is used
       # with a clightning version 22.11.1 package.
      optionalString (cfg.package.version == "22.11.1") "database-upgrade=true"}
    ${cfg.extraConfig}
  '';

  # If a public clightning onion service is enabled, use the onion port as the public port
  publicPort = if (config.nix-bitcoin.onionServices.clightning.enable or false)
                  && config.nix-bitcoin.onionServices.clightning.public
               then
                 (builtins.elemAt config.services.tor.relay.onionServices.clightning.map 0).port
               else
                 cfg.port;
in {
  inherit options;

  config = mkIf cfg.enable {
    services.bitcoind = {
      enable = true;
      # Increase rpc thread count due to reports that lightning implementations fail
      # under high bitcoind rpc load
      rpc.threads = 16;
    };

    environment.systemPackages = [ cfg.package (hiPrio cfg.cli) ];

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.clightning = {
      path  = [ bitcoind.package ];
      wantedBy = [ "multi-user.target" ];
      requires = [ "bitcoind.service" ];
      after = [ "bitcoind.service" "nix-bitcoin-secrets.target" ];
      preStart = ''
        # Remove an existing socket so that `postStart` can detect when when a new
        # socket has been created and clightning is ready to accept RPC connections.
        # This will no longer be needed when clightning supports systemd startup notifications.
        rm -f ${cfg.networkDir}/lightning-rpc

        umask u=rw,g=r,o=
        {
          cat ${configFile}
          echo "bitcoin-rpcpassword=$(cat ${config.nix-bitcoin.secretsDir}/bitcoin-rpcpassword-public)"
          ${optionalString (cfg.getPublicAddressCmd != "") ''
            echo "announce-addr=$(${cfg.getPublicAddressCmd}):${toString publicPort}"
          ''}
        } > '${cfg.dataDir}/config'
      '';
      serviceConfig = nbLib.defaultHardening // {
        ExecStart = "${cfg.package}/bin/lightningd --lightning-dir=${cfg.dataDir}";
        User = cfg.user;
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = [ cfg.dataDir ];
        # DB upgrades or recovery after a crash can take a while
        TimeoutStartSec = "10m";
      } // nbLib.allowedIPAddresses cfg.tor.enforce;
      # Wait until the rpc socket appears
      postStart = ''
        while [[ ! -e ${cfg.networkDir}/lightning-rpc ]]; do
            sleep 0.1
        done
        # Needed to enable lightning-cli for users with group 'clightning'
        chmod g+x ${cfg.networkDir}
      '';
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = [ "bitcoinrpc-public" ];
    };
    users.groups.${cfg.group} = {};
    nix-bitcoin.operator.groups = [ cfg.group ];
  };
}
