{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.datum-gateway;
  bitcoind = config.services.bitcoind;
  nbLib = config.nix-bitcoin.lib;
  types = lib.types;

  # JSON format definition for the config file
  format = pkgs.formats.json {};

  # Helper to get RPC credentials
  rpcCreds = nbLib.getBitcoinRpcCreds cfg.rpc bitcoind;

  # Generate the actual configuration content based on module options
  # Filter out null/empty string options where appropriate to match datum defaults
  filterAttrs = lib.filterAttrs (n: v: v != null && v != "");
  configFileContent = {
    bitcoind = filterAttrs {
      rpcurl = "http://${nbLib.address bitcoind.rpc.address}:${toString bitcoind.rpc.port}";
      rpccookiefile = rpcCreds.cookieFile;
      rpcuser = rpcCreds.user;
      rpcpassword = cfg.settings.bitcoind.rpcpassword;
      work_update_seconds = cfg.settings.bitcoind.work_update_seconds;
      notify_fallback = cfg.settings.bitcoind.notify_fallback;
    };
    stratum = filterAttrs {
      listen_addr = cfg.listenAddress;
      listen_port = cfg.listenPort;
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
    };
    mining = filterAttrs {
      pool_address = cfg.settings.mining.pool_address;
      coinbase_tag_primary = cfg.settings.mining.coinbase_tag_primary;
      coinbase_tag_secondary = cfg.settings.mining.coinbase_tag_secondary;
      coinbase_unique_id = cfg.settings.mining.coinbase_unique_id;
      save_submitblocks_dir = cfg.settings.mining.save_submitblocks_dir;
    };
    api = filterAttrs {
      admin_password = cfg.settings.api.admin_password;
      listen_addr = cfg.settings.api.listen_addr;
      listen_port = cfg.settings.api.listen_port;
      modify_conf = cfg.settings.api.modify_conf;
    };
    extra_block_submissions = filterAttrs {
      urls = cfg.settings.extra_block_submissions.urls;
    };
    logger = filterAttrs {
      log_to_console = cfg.settings.logger.log_to_console;
      log_to_stderr = cfg.settings.logger.log_to_stderr;
      log_to_file = cfg.settings.logger.log_to_file;
      log_file = cfg.settings.logger.log_file;
      log_rotate_daily = cfg.settings.logger.log_rotate_daily;
      log_calling_function = cfg.settings.logger.log_calling_function;
      log_level_console = cfg.settings.logger.log_level_console;
      log_level_file = cfg.settings.logger.log_level_file;
    };
    datum = filterAttrs {
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

  # Generate the config file in the Nix store
  configFile = format.generate "datum-gateway-config.json" configFileContent;

in {
  options.services.datum-gateway = {
    enable = mkEnableOption "DATUM Gateway service";

    package = mkOption {
      type = types.package;
      default = pkgs.datum-gateway;
      defaultText = literalExpression "pkgs.datum-gateway";
      description = "The DATUM Gateway package to use.";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/datum-gateway";
      description = "The directory where DATUM Gateway stores its runtime data (like generated config, logs if not specified elsewhere).";
    };

    # Renamed listenAddress/Port to match config file structure (used under stratum)
    listenAddress = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "IP address for the Stratum Gateway connections to listen on (maps to settings.stratum.listen_addr).";
    };

    listenPort = mkOption {
      type = types.port;
      default = 23334;
      description = "Port for the Stratum Gateway connections (maps to settings.stratum.listen_port).";
    };

    user = mkOption {
      type = types.str;
      default = "datum-gateway";
      description = "User account under which DATUM Gateway runs.";
    };

    group = mkOption {
      type = types.str;
      default = "datum-gateway";
      description = "Group under which DATUM Gateway runs.";
    };

    # Options for connecting to bitcoind RPC (feeds into settings.bitcoind)
    rpc = nbLib.mkBitcoinRpcOptions "datum-gateway";

    # Nested options mirroring the JSON config structure
    settings = mkOption {
      type = types.submoduleWith {
        modules = [{
          options = {
            bitcoind = mkOption {
            type = types.submodule {
              options = {
                # rpcurl, rpccookiefile, rpcuser are derived automatically
                rpcpassword = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "RPC password for communication with local bitcoind. Used only if cookie file is not available/configured.";
                };
                work_update_seconds = mkOption {
                  type = types.int;
                  default = 40;
                  description = "How many seconds between normal work updates? (5-120, 40 suggested)";
                };
                notify_fallback = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Fall back to less efficient methods for new block notifications. Can disable if you use blocknotify.";
                };
              };
            };
            default = {};
            description = "Settings related to bitcoind connection.";
          };

          stratum = mkOption {
            type = types.submodule {
              options = {
                # listen_addr and listen_port are derived from top-level options
                max_clients_per_thread = mkOption {
                  type = types.int;
                  default = 128;
                  description = "Maximum clients per Stratum server thread";
                };
                max_threads = mkOption {
                  type = types.int;
                  default = 8;
                  description = "Maximum Stratum server threads";
                };
                max_clients = mkOption {
                  type = types.int;
                  default = 1024;
                  description = "Maximum total Stratum clients before rejecting connections";
                };
                vardiff_min = mkOption {
                  type = types.int;
                  default = 16384;
                  description = "Work difficulty floor";
                };
                vardiff_target_shares_min = mkOption {
                  type = types.int;
                  default = 8;
                  description = "Adjust work difficulty to target this many shares per minute";
                };
                vardiff_quickdiff_count = mkOption {
                  type = types.int;
                  default = 8;
                  description = "How many shares before considering a quick diff update";
                };
                vardiff_quickdiff_delta = mkOption {
                  type = types.int;
                  default = 8;
                  description = "How many times faster than our target does the miner have to be before we enforce a quick diff bump";
                };
                share_stale_seconds = mkOption {
                  type = types.int;
                  default = 120;
                  description = "How many seconds after a job is generated before a share submission is considered stale?";
                };
                fingerprint_miners = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Attempt to fingerprint miners for better use of coinbase space";
                };
                idle_timeout_no_subscribe = mkOption {
                  type = types.int;
                  default = 15;
                  description = "Seconds we allow a connection to be idle without seeing a work subscription? (0 disables)";
                };
                idle_timeout_no_shares = mkOption {
                  type = types.int;
                  default = 7200;
                  description = "Seconds we allow a subscribed connection to be idle without seeing at least one accepted share? (0 disables)";
                };
                idle_timeout_max_last_work = mkOption {
                  type = types.int;
                  default = 0;
                  description = "Seconds we allow a subscribed connection to be idle since its last accepted share? (0 disables)";
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
                  default = ""; # REQUIRED, but default empty to force user input
                  description = "Bitcoin address used for mining rewards. REQUIRED.";
                };
                coinbase_tag_primary = mkOption {
                  type = types.str;
                  default = "DATUM Gateway (nix-bitcoin)";
                  description = "Text to have in the primary coinbase tag when not using pool (overridden by DATUM Pool)";
                };
                coinbase_tag_secondary = mkOption {
                  type = types.str;
                  default = "DATUM User";
                  description = "Text to have in the secondary coinbase tag (Short name/identifier)";
                };
                coinbase_unique_id = mkOption {
                  type = types.int;
                  default = 4242;
                  description = "A unique ID between 1 and 65535. Appended to coinbase. Make unique per instance with same tags.";
                };
                save_submitblocks_dir = mkOption {
                  type = types.nullOr types.path;
                  default = null;
                  description = "Directory to save all submitted blocks to as submitblock JSON files (null or empty string disables)";
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
                  description = mdDoc ''
                    API password for administrative actions/changes (username 'admin').
                    Set to a non-empty string to enable password protection.
                    If set to `null` or an empty string, the API (if enabled via `listen_port`)
                    will be accessible without a password (potentially dangerous).

                    **Note:** This password is set directly by the user.
                    Unlike service-to-service RPC passwords, it is **not** auto-generated
                    by the nix-bitcoin secrets mechanism because the user needs to know
                    this password to interact with the API.

                    Users are responsible for securing their Nix configuration if they
                    set a sensitive password here (e.g., using `sops-nix`).
                  '';
                };
                listen_addr = mkOption {
                  type = types.nullOr types.str;
                  default = null; # Default disabled
                  description = "IP address to listen for API/dashboard requests (null/empty disables).";
                };
                listen_port = mkOption {
                  type = types.port;
                  default = 0;
                  description = "Port to listen for API/dashboard requests (0=disabled).";
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
                  description = "Log console messages to stderr *instead* of stdout.";
                };
                log_to_file = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Enable logging of messages to a file.";
                };
                log_file = mkOption {
                  type = types.nullOr types.path;
                  default = null;
                  description = "Path to file to write log messages, when enabled (null/empty disables). Relative paths are based on dataDir.";
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
                  description = "Remote DATUM server host/ip for pooled mining (null/empty disables).";
                };
                pool_port = mkOption {
                  type = types.port;
                  default = 28915;
                  description = "Remote DATUM server port.";
                };
                pool_pubkey = mkOption {
                  type = types.nullOr types.str;
                  default = "f21f2f0ef0aa1970468f22bad9bb7f4535146f8e4a8f646bebc93da3d89b1406f40d032f09a417d94dc068055df654937922d2c89522e3e8f6f0e649de473003";
                  description = "Public key of DATUM server for encrypted connection (null/empty to auto-fetch).";
                };
                pool_pass_workers = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Pass stratum miner usernames as sub-worker names to the pool (pool_username.miner_username).";
                };
                pool_pass_full_users = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Pass stratum miner usernames as raw usernames to the pool (use if multiple payout addresses behind gateway).";
                };
                always_pay_self = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Always include my datum.pool_username payout in my blocks if possible.";
                };
                pooled_mining_only = mkOption {
                  type = types.bool;
                  default = true;
                  description = "If DATUM pool unavailable, terminate miner connections (otherwise, solo mine to mining.pool_address).";
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
      }]; # Close modules array
      }; # Close type
      description = "Configuration settings written to the DATUM Gateway JSON config file.";
      default = {};
      # Example becomes less critical as options are defined with defaults/descriptions
      example = literalExpression ''
        {
          mining.pool_address = "YOUR_MINING_REWARD_ADDRESS";
          # logger.log_level_console = 1; # Enable debug logging
          # api = { listen_addr = "0.0.0.0"; listen_port = 8339; }; # Enable API
        }
      '';
    };
  }; # End of the 'options.services.datum-gateway' attribute set

  config = mkIf cfg.enable {

    # Ensure secrets needed for RPC are created
    secrets.secrets."bitcoin-rpcpassword-${cfg.rpc.user}" = nbLib.mkRpcPasswordSecret cfg.rpc;

    systemd.services.datum-gateway = {
      description = "DATUM Gateway";
      after = [ "network.target" "bitcoind.service" "nix-bitcoin-secrets.target" ];
      requires = [ "bitcoind.service" ];
      wantedBy = [ "multi-user.target" ];

      # No preStart needed, config is generated declaratively

      serviceConfig = nbLib.defaultHardening // {
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";
        # WorkingDirectory should be dataDir for relative paths in config (e.g., log_file)
        WorkingDirectory = cfg.dataDir;
        ExecStart = ''
          ${cfg.package}/bin/datum_gateway --config ${configFile}
        '';
        # Config file needs to be readable by the user
        # SupplementaryGroups = [ config.users.groups.${rpcCreds.group}.name ]; # Might be needed if cookie is restrictive
        # Consider LoadCredential= for the password if not using cookie?

        # State directory for runtime data
        StateDirectory = baseNameOf cfg.dataDir;
        StateDirectoryMode = "0750";
        LogsDirectory = "datum-gateway"; # Separate logs dir if needed
        LogsDirectoryMode = "0750";
        ConfigurationDirectory = "datum-gateway"; # For config snippets?
        ConfigurationDirectoryMode = "0750";
        ReadWritePaths = [ cfg.dataDir ]; # Ensure write access to dataDir
      };
    };

    # Create user/group
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      extraGroups = nbLib.bitcoinRpcExtraGroups cfg.rpc; # For cookie access
    };
    users.groups.${cfg.group} = {};
  };
}