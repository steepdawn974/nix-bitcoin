{ config, lib, pkgs, ... }:

with lib;

let
  options.services.datum-gateway = {
    enable = mkEnableOption "DATUM Gateway, a decentralized mining gateway for OCEAN pool";

    package = mkOption {
      type = types.package;
      default = config.nix-bitcoin.pkgs.datum-gateway;
      defaultText = literalExpression "config.nix-bitcoin.pkgs.datum-gateway";
      description = "The DATUM Gateway package to use.";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/datum-gateway";
      description = "The directory where DATUM Gateway stores its runtime data.";
    };

    listenAddress = mkOption {
      type = types.str;
      default = "127.0.0.1";
      visible = false;  # Hide from documentation
      description = ''
        Deprecated: Use `settings.stratum.listen_addr` instead.
        IP address for the Stratum server to listen on.
      '';
    };

    listenPort = mkOption {
      type = types.port;
      default = 23334;
      visible = false;  # Hide from documentation
      description = ''
        Deprecated: Use `settings.stratum.listen_port` instead.
        Port for the Stratum server.
      '';
    };

    user = mkOption {
      type = types.str;
      default = "datum-gateway";
      description = "User account under which DATUM Gateway runs.";
    };

    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = "Group under which DATUM Gateway runs.";
    };

    tor.enforce = nbLib.tor.enforce;

    # Nested options mirroring the JSON config structure
    settings = mkOption {
      type = types.submodule {
        options = {
          bitcoind = mkOption {
            type = types.submodule {
              options = {
                rpccookiefile = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Path to file to read RPC cookie from for communication with local bitcoind.";
                };
                work_update_seconds = mkOption {
                  type = types.int;
                  default = 40;
                  description = "How many seconds between normal work updates? (5-120, 40 suggested)";
                };
                notify_fallback = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Fall back to less efficient methods for new block notifications. Disabled by default since we use blocknotify.";
                };
              };
            };
            default = {};
            description = "Settings related to bitcoind connection.";
          };

          stratum = mkOption {
            type = types.submodule {
              options = {
                max_clients_per_thread = mkOption {
                  type = types.int;
                  default = 128;
                  description = "Maximum clients per Stratum server thread.";
                };
                max_threads = mkOption {
                  type = types.int;
                  default = 8;
                  description = "Maximum Stratum server threads.";
                };
                max_clients = mkOption {
                  type = types.int;
                  default = 1024;
                  description = "Maximum total Stratum clients before rejecting connections.";
                };
                vardiff_min = mkOption {
                  type = types.int;
                  default = 16384;
                  description = "Work difficulty floor.";
                };
                vardiff_target_shares_min = mkOption {
                  type = types.int;
                  default = 8;
                  description = "Adjust work difficulty to target this many shares per minute.";
                };
                vardiff_quickdiff_count = mkOption {
                  type = types.int;
                  default = 8;
                  description = "How many shares before considering a quick diff update.";
                };
                vardiff_quickdiff_delta = mkOption {
                  type = types.int;
                  default = 8;
                  description = "How many times faster than our target does the miner have to be before we enforce a quick diff bump.";
                };
                share_stale_seconds = mkOption {
                  type = types.int;
                  default = 120;
                  description = "How many seconds after a job is generated before a share submission is considered stale.";
                };
                fingerprint_miners = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Attempt to fingerprint miners for better use of coinbase space.";
                };
                idle_timeout_no_subscribe = mkOption {
                  type = types.int;
                  default = 15;
                  description = "Seconds we allow a connection to be idle without seeing a work subscription (0 disables).";
                };
                idle_timeout_no_shares = mkOption {
                  type = types.int;
                  default = 7200;
                  description = "Seconds we allow a subscribed connection to be idle without seeing at least one accepted share (0 disables).";
                };
                idle_timeout_max_last_work = mkOption {
                  type = types.int;
                  default = 0;
                  description = "Seconds we allow a subscribed connection to be idle since its last accepted share (0 disables).";
                };
                trust_proxy = mkOption {
                  type = types.int;
                  default = -1;
                  description = "Enable support for the PROXY protocol, trusting up to the specified number of levels deep of proxies (-1 to disable entirely).";
                };
                username_modifiers = mkOption {
                  type = types.attrsOf (types.attrsOf types.int);
                  default = {};
                  description = "Modifiers to redirect some portion of shares to alternate usernames. Format: { modifierName = { percentage = 10; }; }";
                  example = {
                    "mod1" = {
                      percentage = 10;
                    };
                  };
                };
                listen_addr = mkOption {
                  type = types.str;
                  default = "127.0.0.1";
                  description = "IP address for the Stratum server to listen on. Maps to JSON config field `stratum.listen_addr`.";
                };
                listen_port = mkOption {
                  type = types.port;
                  default = 23334;
                  description = "Port for the Stratum server. Maps to JSON config field `stratum.listen_port`.";
                };
              };
            };
            default = {};
            description = "Settings related to the Stratum server.";
          };

          mining = mkOption {
            type = types.submodule {
              options = {
                pool_address = mkOption {
                  type = types.str;
                  description = "Bitcoin address used for mining rewards. REQUIRED.";
                };
                coinbase_tag_primary = mkOption {
                  type = types.str;
                  default = "DATUM Gateway";
                  description = "Text to have in the primary coinbase tag when not using pool (overridden by DATUM Pool).";
                };
                coinbase_tag_secondary = mkOption {
                  type = types.str;
                  default = "nix-bitcoin";
                  description = "Text to have in the secondary coinbase tag (short name/identifier).";
                };
                coinbase_unique_id = mkOption {
                  type = types.int;
                  default = 4242;
                  description = "A unique ID between 1 and 65535. Appended to coinbase. Make unique per instance with same tags.";
                };
                save_submitblocks_dir = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Directory to save all submitted blocks to as submitblock JSON files (null disables).";
                };
              };
            };
            default = {};
            description = "Settings related to mining configuration.";
          };

          api = mkOption {
            type = types.submodule {
              options = {
                admin_password = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = ''
                    API password for administrative actions/changes (username 'admin').
                    Set to a non-empty string to enable password protection.
                  '';
                };
                listen_addr = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "IP address to listen for API/dashboard requests (null disables).";
                };
                listen_port = mkOption {
                  type = types.port;
                  default = 0;
                  description = "Port to listen for API/dashboard requests (0 disables).";
                };
                modify_conf = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Enable modifying the config file from API/dashboard.";
                };
              };
            };
            default = {};
            description = "Settings for the administrative API/dashboard.";
          };

          extra_block_submissions = mkOption {
            type = types.submodule {
              options = {
                urls = mkOption {
                  type = types.listOf types.str;
                  default = [];
                  description = "Array of bitcoind RPC URLs (including auth: http://user:pass@IP) to submit found blocks to directly.";
                };
              };
            };
            default = {};
            description = "Settings for submitting blocks to additional bitcoind instances.";
          };

          logger = mkOption {
            type = types.submodule {
              options = {
                log_to_console = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Enable logging of messages to the console.";
                };
                log_to_stderr = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Log console messages to stderr instead of stdout.";
                };
                log_to_file = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Enable logging of messages to a file.";
                };
                log_file = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Path to file to write log messages (null disables).";
                };
                log_rotate_daily = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Rotate the message log file at midnight.";
                };
                log_calling_function = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Log the name of the calling function when logging.";
                };
                log_level_console = mkOption {
                  type = types.enum [ 0 1 2 3 4 5 ];
                  default = 2;
                  description = "Minimum log level for console messages (0=All, 1=Debug, 2=Info, 3=Warn, 4=Error, 5=Fatal).";
                };
                log_level_file = mkOption {
                  type = types.enum [ 0 1 2 3 4 5 ];
                  default = 1;
                  description = "Minimum log level for log file messages (0=All, 1=Debug, 2=Info, 3=Warn, 4=Error, 5=Fatal).";
                };
              };
            };
            default = {};
            description = "Logging configuration.";
          };

          datum = mkOption {
            type = types.submodule {
              options = {
                pool_host = mkOption {
                  type = types.nullOr types.str;
                  default = "datum-beta1.mine.ocean.xyz";
                  description = "Remote DATUM server host/ip for pooled mining (null disables).";
                };
                pool_port = mkOption {
                  type = types.port;
                  default = 28915;
                  description = "Remote DATUM server port.";
                };
                pool_pubkey = mkOption {
                  type = types.nullOr types.str;
                  default = "f21f2f0ef0aa1970468f22bad9bb7f4535146f8e4a8f646bebc93da3d89b1406f40d032f09a417d94dc068055df654937922d2c89522e3e8f6f0e649de473003";
                  description = "Public key of DATUM server for encrypted connection (null to auto-fetch).";
                };
                pool_pass_workers = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Pass stratum miner usernames as sub-worker names to the pool.";
                };
                pool_pass_full_users = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Pass stratum miner usernames as raw usernames to the pool (use if putting multiple payout addresses on miners behind this gateway).";
                };
                always_pay_self = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Always include my payout in my blocks if possible.";
                };
                pooled_mining_only = mkOption {
                  type = types.bool;
                  default = true;
                  description = "If DATUM pool unavailable, terminate miner connections (otherwise, solo mine).";
                };
                protocol_global_timeout = mkOption {
                  type = types.int;
                  default = 60;
                  description = "If no valid messages from DATUM server in this many seconds, reconnect.";
                };
              };
            };
            default = {};
            description = "Settings related to DATUM decentralized pooled mining.";
          };
        };
      };
      default = {};
      description = "Configuration settings written to the DATUM Gateway JSON config file.";
    };
  };

  cfg = config.services.datum-gateway;
  nbLib = config.nix-bitcoin.lib;
  secretsDir = config.nix-bitcoin.secretsDir;
  bitcoind = config.services.bitcoind;

  # Filter out null/empty values
  filterEmpty = lib.filterAttrs (n: v: v != null && v != "" && v != []);

  # Generate the config file content
  configFileContent = {
    bitcoind = filterEmpty {
      rpcurl = "http://${nbLib.address bitcoind.rpc.address}:${toString bitcoind.rpc.port}";
      rpcuser = bitcoind.rpc.users.public.name;
      # Password is injected at runtime via preStart
      rpccookiefile = cfg.settings.bitcoind.rpccookiefile;
      work_update_seconds = cfg.settings.bitcoind.work_update_seconds;
      notify_fallback = cfg.settings.bitcoind.notify_fallback;
    };
    stratum = filterEmpty {
      # Use canonical values from settings.stratum
      # If deprecated top-level options are used, they take precedence for backward compatibility
      listen_addr = if cfg.listenAddress != "127.0.0.1" 
                    then cfg.listenAddress 
                    else cfg.settings.stratum.listen_addr;
      listen_port = if cfg.listenPort != 23334 
                    then cfg.listenPort 
                    else cfg.settings.stratum.listen_port;
      max_clients_per_thread = cfg.settings.stratum.max_clients_per_thread;
      max_threads = cfg.settings.stratum.max_threads;
      max_clients = cfg.settings.stratum.max_clients;
      vardiff_min = cfg.settings.stratum.vardiff_min;
      vardiff_target_shares_min = cfg.settings.stratum.vardiff_target_shares_min;
      vardiff_quickdiff_count = cfg.settings.stratum.vardiff_quickdiff_count;
      vardiff_quickdiff_delta = cfg.settings.stratum.vardiff_quickdiff_delta;
      share_stale_seconds = cfg.settings.stratum.share_stale_seconds;
      fingerprint_miners = cfg.settings.stratum.fingerprint_miners;
      idle_timeout_no_subscribe = cfg.settings.stratum.idle_timeout_no_subscribe;
      idle_timeout_no_shares = cfg.settings.stratum.idle_timeout_no_shares;
      idle_timeout_max_last_work = cfg.settings.stratum.idle_timeout_max_last_work;
      trust_proxy = cfg.settings.stratum.trust_proxy;
      username_modifiers = cfg.settings.stratum.username_modifiers;
    };
    mining = filterEmpty {
      pool_address = cfg.settings.mining.pool_address;
      coinbase_tag_primary = cfg.settings.mining.coinbase_tag_primary;
      coinbase_tag_secondary = cfg.settings.mining.coinbase_tag_secondary;
      coinbase_unique_id = cfg.settings.mining.coinbase_unique_id;
      save_submitblocks_dir = cfg.settings.mining.save_submitblocks_dir;
    };
    api = filterEmpty {
      admin_password = cfg.settings.api.admin_password;
      listen_addr = cfg.settings.api.listen_addr;
      listen_port = cfg.settings.api.listen_port;
      modify_conf = cfg.settings.api.modify_conf;
    };
    extra_block_submissions = filterEmpty {
      urls = cfg.settings.extra_block_submissions.urls;
    };
    logger = filterEmpty {
      log_to_console = cfg.settings.logger.log_to_console;
      log_to_stderr = cfg.settings.logger.log_to_stderr;
      log_to_file = cfg.settings.logger.log_to_file;
      log_file = cfg.settings.logger.log_file;
      log_rotate_daily = cfg.settings.logger.log_rotate_daily;
      log_calling_function = cfg.settings.logger.log_calling_function;
      log_level_console = cfg.settings.logger.log_level_console;
      log_level_file = cfg.settings.logger.log_level_file;
    };
    datum = filterEmpty {
      pool_host = cfg.settings.datum.pool_host;
      pool_port = cfg.settings.datum.pool_port;
      pool_pubkey = cfg.settings.datum.pool_pubkey;
      pool_pass_workers = cfg.settings.datum.pool_pass_workers;
      pool_pass_full_users = cfg.settings.datum.pool_pass_full_users;
      always_pay_self = cfg.settings.datum.always_pay_self;
      pooled_mining_only = cfg.settings.datum.pooled_mining_only;
      protocol_global_timeout = cfg.settings.datum.protocol_global_timeout;
    };
  };

  # Generate base config file (password placeholder will be replaced at runtime)
  configFileBase = pkgs.writeText "datum-gateway-config.json" (builtins.toJSON (
    configFileContent // {
      bitcoind = configFileContent.bitcoind // {
        rpcpassword = "@rpcpassword@";
      };
    }
  ));

in {
  inherit options;

  config = mkIf cfg.enable {
    assertions = [
      { assertion = cfg.settings.mining.pool_address != "";
        message = "services.datum-gateway.settings.mining.pool_address must be set to your Bitcoin address.";
      }
    ];

    services.bitcoind = {
      enable = true;
      # Add blocknotify to signal datum_gateway when new blocks arrive
      # This is more efficient than polling for new blocks
      # Note: We use /run/current-system/sw/bin/killall which is available at runtime
      # because builtins.toFile (used by bitcoind.nix) cannot reference derivations
      extraConfig = ''
        blocknotify=/run/current-system/sw/bin/killall -USR1 datum_gateway
      '';
      # Reserve block space for the pool's generation transaction
      # Required for DATUM pooled mining to work properly
      knotsSpecificOptions = mkIf (bitcoind.implementation == "knots") {
        blockmaxsize = mkDefault 3985000;
      };
    };

    # Ensure killall (from psmisc) is available system-wide for blocknotify
    environment.systemPackages = [ pkgs.psmisc ];

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.datum-gateway = {
      description = "DATUM Gateway";
      wantedBy = [ "multi-user.target" ];
      requires = [ "bitcoind.service" ];
      after = [ "bitcoind.service" "nix-bitcoin-secrets.target" ];

      preStart = ''
        # Generate config with RPC password
        ${pkgs.gnused}/bin/sed \
          "s|@rpcpassword@|$(cat ${secretsDir}/bitcoin-rpcpassword-public)|" \
          ${configFileBase} > ${cfg.dataDir}/config.json
      '';

      serviceConfig = nbLib.defaultHardening // {
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";
        RestartSec = "10s";
        WorkingDirectory = cfg.dataDir;
        ExecStart = "${cfg.package}/bin/datum_gateway --config ${cfg.dataDir}/config.json";
        ReadWritePaths = [ cfg.dataDir ];
      } // nbLib.allowedIPAddresses cfg.tor.enforce;
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = [ "bitcoinrpc-public" ];
    };
    users.groups.${cfg.group} = {};
  };
}
