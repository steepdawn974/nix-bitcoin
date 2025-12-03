# Nodeinfo
Run `nodeinfo` to see onion addresses and local addresses for enabled services.

# Managing services

NixOS uses the [systemd](https://wiki.archlinux.org/title/systemd) service manager.

Usage:
```shell
# Show service status
systemctl status bitcoind

# Show the last 100 log messages
journalctl -u bitcoind -n 100
# Show all log messages since the last system boot
journalctl -b -u bitcoind

# These commands require root permissions
systemctl stop bitcoind
systemctl start bitcoind
systemctl restart bitcoind

# Show the service definition
systemctl cat bitcoind
# Show all service parameters
systemctl show bitcoind
```

# clightning database replication

The clightning database can be replicated to a local path
or to a remote SSH target.\
When remote replication is enabled, nix-bitcoin mounts a SSHFS to a local path.\
Optionally, backups can be encrypted via `gocryptfs`.

Note: You should also backup the static file `hsm_secret` (located at
`/var/lib/clightning/bitcoin/hsm_secret` by default), either manually
or via the `services.backups` module.

## Remote target via SSHFS

1. Add this to your `configuration.nix`:
   ```nix
   services.clightning.replication = {
     enable = true;
     sshfs.destination = "user@hostname:directory";
     # This is optional
     encrypt = true;
   };
   programs.ssh.knownHosts."hostname".publicKey = "<ssh public key from running `ssh-keyscan` on the host>";
   ```

   Leave out the `encrypt` line if you want to store data on your destination
   in plaintext.\
   Adjust `user`, `hostname` and `directory` as necessary.

2. Deploy

3. To allow SSH access from the nix-bitcoin node to the target node, either
   use the remote node config below, or copy the contents of `$secretsDir/clightning-replication-ssh.pub`
   to the `authorized_keys` file of `user` (or use `ssh-copy-id`).

4. You can restrict the nix-bitcoin node's capabilities on the SSHFS target
   using OpenSSH's builtin features, as detailed
   [here](https://serverfault.com/questions/354615/allow-sftp-but-disallow-ssh).

   To implement this on NixOS, add the following to the NixOS configuration of
   the SSHFS target node:
   ```nix
   systemd.tmpfiles.rules = [
     # Because this directory is chrooted by sshd, it must only be writable by user/group root
     "d /var/backup/nb-replication 0755 root root - -"
     "d /var/backup/nb-replication/writable 0700 nb-replication - - -"
   ];

   services.openssh = {
     extraConfig = ''
       Match user nb-replication
         ChrootDirectory /var/backup/nb-replication
         AllowTcpForwarding no
         AllowAgentForwarding no
         ForceCommand internal-sftp
         PasswordAuthentication no
         X11Forwarding no
     '';
   };

   users.users.nb-replication = {
     isSystemUser = true;
     group = "nb-replication";
     shell = "${pkgs.coreutils}/bin/false";
     openssh.authorizedKeys.keys = [ "<contents of $secretsDir/clightning-replication-ssh.pub>" ];
   };
   users.groups.nb-replication = {};
   ```

   With this setup, the corresponding `sshfs.destination` on the nix-bitcoin
   node is `"nb-replication@hostname:writable"`.

## Local directory target

1. Add this to your `configuration.nix`
   ```nix
   services.clightning.replication = {
     enable = true;
     local.directory = "/var/backup/clightning";
     encrypt = true;
   };
   ```

   Leave out the `encrypt` line if you want to store data in
   `local.directory` in plaintext.

2. Deploy

clightning will now replicate database files to `local.directory`. This
can be used to replicate to an external HDD by mounting it at path
`local.directory`.

## Custom remote destination

Follow the steps in section "Local directory target" above and mount a custom remote
destination (e.g., a NFS or SMB share) to `local.directory`.\
You might want to disable `local.setupDirectory` in order to create the mount directory
yourself with custom permissions.

# Connect to RTL
Normally you would connect to RTL via SSH tunneling with a command like this

```
ssh -L 3000:127.0.0.1:3000 root@bitcoin-node
```

Or like this, if you are using `netns-isolation`

```
ssh -L 3000:169.254.1.29:3000 root@bitcoin-node
```

Otherwise, you can access it via Tor Browser at `http://<onion-address>`.
You can find the `<onion-address>` with command `nodeinfo`.
The default password location is `$secretsDir/rtl-password`.
See: [Secrets dir](./configuration.md#secrets-dir)

# Use Zeus (mobile lightning wallet) via Tor
1. Install [Zeus](https://zeusln.app) (version ≥ 0.9.0)

2. Edit your `configuration.nix`

   ##### For lnd

   Add the following config:
   ```nix
   services.lnd.lndconnect = {
     enable = true;
     onion = true;
   };
   ```

   ##### For clightning

   Add the following config:
   ```nix
   services.clightning.plugins.clnrest = {
     enable = true;
     lnconnect = {
       enable = true;
       onion = true;
     };
   };
   ```

3. Deploy your configuration

4. Run the following command on your node (as user `operator`) to create a QR code
   with address and authentication information:

   ##### For lnd
   ```
   lndconnect
   ```

   ##### For clightning
   ```
   lnconnect-clnrest
   ```

5. Configure Zeus
   - Add a new node and scan the QR code
   - Click `Save node config`
   - Start sending and stacking sats privately

### Additional lndconnect features
- Create a plain text URL:
  ```bash
  lndconnect --url
  ```
- Set a custom host. By default, `lndconnect` detects the system's external IP and uses it as the host.
  ```bash
  lndconnect --host myhost
  ```

# Use Zeus (mobile lightning wallet) via WireGuard

Connecting Zeus directly to your node is much faster than using Tor, but a bit more complex to setup.

There are two ways to establish a secure, direct connection:

- Connecting via TLS. This requires installing your lightning app's
  TLS Certificate on your mobile device.

- Connecting via WireGuard. This approach is simpler and more versatile, and is
  described in this guide.

1. Install [Zeus](https://zeusln.app) (version ≥ 0.9.0) and
   [WireGuard](https://www.wireguard.com/install/) on your mobile device.

2. Add the following to your `configuration.nix`:
   ```nix
   imports = [
     # Use this line when using the default deployment method
     <nix-bitcoin/modules/presets/wireguard.nix>

     # Use this line when using Flakes
     (nix-bitcoin + /modules/presets/wireguard.nix)
   ]

   # For lnd
   services.lnd.lndconnect.enable = true;

   # For clightning
   services.clightning = {
     plugins.clnrest = {
       enable = true;
       lnconnect.enable = true;
     };
   };
   ```
3. Deploy your configuration.

4. If your node is behind an external firewall or NAT (e.g. a router), add the following port forwarding
   rule to the external device:
   - Port: 51820 (the default value of option `networking.wireguard.interfaces.wg-nb.listenPort`)
   - Protocol: UDP
   - Destination: IP of your node

5. Setup WireGuard on your mobile device.

   Run the following command on your node (as user `operator`) to create a QR code
   for WireGuard:
   ```bash
   nix-bitcoin-wg-connect

   # For debugging: Show the WireGuard config as text
   nix-bitcoin-wg-connect --text
   ```
   The above commands automatically detect your node's external IP.\
   To set a custom IP or hostname, run the following:
   ```
   nix-bitcoin-wg-connect 93.184.216.34
   nix-bitcoin-wg-connect mynode.org
   ```

   Configure WireGuard:
   - Press the `+` button in the bottom right corner
   - Scan the QR code
   - Add the tunnel

6. Setup Zeus

   Run the following command on your node (as user `operator`) to create a QR code for Zeus:

   ##### For lnd
   ```
   lndconnect-wg
   ```

   ##### For clightning
   ```
   lnconnect-clnrest-wg
   ```

   Configure Zeus:
   - Add a new node and scan the QR code
   - Click `Save node config`
   - On the certificate warning screen, click `I understand, save node config`.\
     Certificates are not needed when connecting via WireGuard.
   - Start sending and stacking sats privately

### Additional lndconnect features
Create a plain text URL:
```bash
lndconnect-wg --url
``````

# Connect to electrs
### Requirements Android
* Android phone
* [Orbot](https://guardianproject.info/apps/orbot/) installed from [F-Droid](https://guardianproject.info/fdroid) (recommended) or [Google Play](https://play.google.com/store/apps/details?id=org.torproject.android&hl=en)
* [Electrum mobile app](https://electrum.org/#home) 4.0.1 and newer installed from [direct download](https://electrum.org/#download) or [Google Play](https://play.google.com/store/apps/details?id=org.electrum.electrum)

### Requirements Desktop
* [Tor](https://www.torproject.org/) installed from [source](https://www.torproject.org/docs/tor-doc-unix.html.en) or [repository](https://www.torproject.org/docs/debian.html.en)
* [Electrum](https://electrum.org/#download) installed

1. Enable electrs in `configuration.nix`

    Change
    ```
    # services.electrs.enable = true;
    ```
    to
    ```
    services.electrs.enable = true;
    ```

2. Deploy new `configuration.nix`

3. Get electrs onion address with format `<onion-address>:<port>`

    ```
    nodeinfo | jq -r .electrs.onion_address
    ```

4. Connect to electrs

    Make sure Tor is running on Desktop or as Orbot on Android.

    On Desktop
    ```
    electrum --oneserver -1 -s "<electrs onion address>:t" -p socks5:127.0.0.1:9050
    ```

    On Android
    ```
    Three dots in the upper-right-hand corner
    Network > Proxy mode: socks5, Host: 127.0.0.1, Port: 9050
    Network > Auto-connect: OFF
    Network > One-server mode: ON
    Network > Server: <electrs onion address>:t
    ```

# Connect to nix-bitcoin node through the SSH onion service
1. Get the SSH onion address (excluding the port suffix)

    ```
    ssh operator@bitcoin-node
    nodeinfo | jq -r .sshd.onion_address | sed 's/:.*//'
    ```

2. Create a SSH key

    ```
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
    ```

3. Place the ed25519 key's fingerprint in the `configuration.nix` `openssh.authorizedKeys.keys` field like so

    ```
    # FIXME: Add your SSH pubkey
    services.openssh.enable = true;
    users.users.root = {
      openssh.authorizedKeys.keys = [ "<contents of ~/.ssh/id_ed25519.pub>" ];
    };
    ```

4. Connect to your nix-bitcoin node's SSH onion service, forwarding a local port to the nix-bitcoin node's SSH server

    ```
    ssh -i ~/.ssh/id_ed25519 -L <random port of your choosing>:127.0.0.1:22 root@<SSH onion address>
    ```

5. Edit your deployment tool's configuration and change the node's address to `127.0.0.1` and the ssh port to `<random port of your choosing>`.
   If you use krops as described in the [installation tutorial](./install.md), set `target = "127.0.0.1:<random port of your choosing>";` in `krops/deploy.nix`.

6. After deploying the new configuration, it will connect through the SSH tunnel you established in step iv. This also allows you to do more complex SSH setups that some deployment tools don't support. An example would be authenticating with [Trezor's SSH agent](https://github.com/romanz/trezor-agent), which provides extra security.

# Initialize a Trezor for Bitcoin Core's Hardware Wallet Interface

1. Enable Trezor in `configuration.nix`

    Change
    ```
    # services.hardware-wallets.trezor = true;
    ```
    to
    ```
    services.hardware-wallets.trezor = true;
    ```

2. Deploy new `configuration.nix`

3. Check that your nix-bitcoin node recognizes your Trezor

    ```
    ssh operator@bitcoin-node
    lsusb
    ```
    Should show something relating to your Trezor

4. If your Trezor has outdated firmware or is not yet initialized: Start your Trezor in bootloader mode

    Trezor v1
    ```
    Plug in your Trezor with both buttons depressed
    ```

    Trezor v2
    ```
    Start swiping your finger across your Trezor's touchscreen and plug in the USB cable when your finger is halfway through
    ```

5. If your Trezor's firmware is outdated: Update your Trezor's firmware

    ```
    trezorctl firmware-update
    ```
    Follow the on-screen instructions

    **Caution: This command _will_ wipe your Trezor. If you already store Bitcoin on it, only do this with the recovery seed nearby.**

6. If your Trezor is not yet initialized: Set up your Trezor

    ```
    trezorctl reset-device -p
    ```
    Follow the on-screen instructions

7. Find your Trezor

    ```
    hwi enumerate
    hwi -t trezor -d <path from previous command> promptpin
    hwi -t trezor -d <path> sendpin <number positions for the PIN as displayed on your device's screen>
    hwi enumerate
    ```

8. Follow Bitcoin Core's instructions on [Using Bitcoin Core with Hardware Wallets](https://github.com/bitcoin-core/HWI/blob/master/docs/bitcoin-core-usage.md) to use your Trezor with `bitcoin-cli` on your nix-bitcoin node

# JoinMarket

## Diff to regular JoinMarket usage

For clarity reasons, nix-bitcoin renames all scripts to `jm-*` without `.py`, for
example `wallet-tool.py` becomes `jm-wallet-tool`. The rest of this section
details nix-bitcoin specific workflows for JoinMarket.

## Wallets

By default, a wallet is automatically generated at service startup.
It's stored at `/var/lib/joinmarket/wallets/wallet.jmdat`, and its mnmenoic recovery
seed phrase is stored at `/var/lib/joinmarket/jm-wallet-seed`.

A missing wallet file is automatically recreated if the seed file is still present.

If you want to manually initialize your wallet instead, follow these steps:

1. Enable JoinMarket in your node configuration

    ```
    services.joinmarket.enable = true;
    ```

2. Move the automatically generated `wallet.jmdat`

    ```console
    mv /var/lib/joinmarket/wallet.jmdat /var/lib/joinmarket/bak.jmdat
    ```

3. Generate wallet on your node

    ```console
    jm-wallet-tool generate
    ```
    Follow the on-screen instructions and write down your seed.

    In order to use nix-bitcoin's `joinmarket.yieldgenerator`, use the password
    from `$secretsDir/jm-wallet-password` and use the suggested default wallet name
    `wallet.jmdat`. If you want to use your own `jm-wallet-password`, simply
    replace the password string in your local secrets directory.
    See: [Secrets dir](./configuration.md#secrets-dir)

## Run the tumbler

The tumbler needs to be able to run in the background for a long time, use screen
to run it accross SSH sessions. You can also use tmux in the same fashion.

1. Add screen to your `environment.systemPackages`, for example

    ```
    environment.systemPackages = with pkgs; [
      vim
      screen
    ];
    ```

2. Start the screen session

    ```console
    screen -S "tumbler"
    ```

3. Start the tumbler

    Example: Tumbling into your wallet after buying from an exchange to improve privacy:

    ```console
    jm-tumbler wallet.jmdat <addr1> <addr2> <addr3>
    ```

    After tumbling your bitcoin end up in these three addresses. You can now
    spend them without the exchange collecting data on your purchases.

    Get more information [here](https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/docs/tumblerguide.md)

4. Detach the screen session to leave the tumbler running in the background

    ```
    Ctrl-a d or Ctrl-a Ctrl-d
    ```

5. Re-attach to the screen session

    ```console
    screen -r tumbler
    ```

6. End screen session

    Type exit when tumbler is done

    ```console
    exit
    ```

## Run a "maker" or "yield generator"

The maker/yield generator in nix-bitcoin is implemented using a systemd service.

See [here](https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/docs/YIELDGENERATOR.md) for more yield generator information.

1. Enable yield generator bot in your node configuration

    ```
    services.joinmarket.yieldgenerator = {
      enable = true;
      # Optional: Add custom parameters
      cjfee_a = 300;
      cjfee_r = 0.00003;
    };
    '';
    ```

2. Check service status

    ```console
    systemctl status joinmarket-yieldgenerator
    ```

3. Profit

# clightning

## Plugins
There is a number of [plugins](https://github.com/lightningd/plugins) available for clightning.
See [`Readme: Features → clightning`](../README.md#features) or [search.nixos.org][1] for a complete list.

[1]: https://search.nixos.org/flakes?channel=unstable&from=0&size=30&sort=relevance&type=options&query=services.clightning.plugins

You can activate and configure these plugins like so:

```nix
services.clightning = {
    enable = true;
    plugins = {
        clboss.enable = true;
        clboss.min-onchain = 40000;
    };
};
```

Please have a look at the module for a plugin (e.g. [clboss.nix](../modules/clightning-plugins/clboss.nix)) to learn its configuration options.

### Trustedcoin
When `services.clightning.tor.proxy` is enabled, [trustedcoin](https://github.com/nbd-wtf/trustedcoin)
also uses Tor for all external connections by default.
In this case, connections to block explorers can sometimes get blocked.

An example of clightning log error output when connections are getting blocked:
```
lightningd[5138]: plugin-trustedcoin estimatefees error: https://blockstream.info/api error: 403 Forbidden
lightningd[4933]: plugin-trustedcoin getblock error: got something that isn't a block hash: <html><head>...
```

To work around this and connect via clearnet instead, set this option:
```nix
services.clightning.plugins.trustedcoin.tor.proxy = false;
```

# DATUM Gateway

DATUM Gateway is a decentralized mining gateway for the [OCEAN pool](https://ocean.xyz).
It allows you to mine with your own Bitcoin node while participating in pooled mining,
giving you control over your block templates.

## Requirements

- A fully synced Bitcoin node (Bitcoin Knots recommended)
- A Bitcoin address for mining rewards
- Mining hardware that supports Stratum protocol

## Basic Setup

1. Enable DATUM Gateway in your `configuration.nix`:

   ```nix
   services.datum-gateway = {
     enable = true;
     settings.mining.pool_address = "YOUR_BITCOIN_ADDRESS";
   };
   ```

   Replace `YOUR_BITCOIN_ADDRESS` with your Bitcoin address for receiving mining rewards.

2. Deploy your configuration

3. Point your mining hardware to the DATUM Gateway's Stratum server:
   - Host: Your node's IP address
   - Port: 23334 (default)
   - Username: Your Bitcoin address or worker name
   - Password: Can be left empty or set to `x`

## Configuration Options

### Using Bitcoin Knots (Recommended)

When using Bitcoin Knots, the module automatically configures:
- `blockmaxsize=3985000` to reserve space for the pool's generation transaction
- `blocknotify` to efficiently notify DATUM Gateway of new blocks

```nix
services.bitcoind.implementation = "knots";
services.datum-gateway = {
  enable = true;
  settings.mining.pool_address = "YOUR_BITCOIN_ADDRESS";
};
```

### Custom Stratum Settings

The canonical way to configure Stratum settings is via the `settings.stratum` submodule, which matches the JSON config structure:

```nix
services.datum-gateway = {
  enable = true;
  settings = {
    mining = {
      pool_address = "YOUR_BITCOIN_ADDRESS";
      coinbase_tag_primary = "My Mining Operation";
      coinbase_tag_secondary = "Node1";
      coinbase_unique_id = 1234;  # Unique ID (1-65535)
    };
    stratum = {
      listen_addr = "0.0.0.0";  # IP address to listen on
      listen_port = 23334;       # Port to listen on
      max_clients = 1024;
      max_clients_per_thread = 128;
      max_threads = 8;
      vardiff_min = 16384;
      vardiff_target_shares_min = 8;
      trust_proxy = -1;  # Disable PROXY protocol (-1)
      username_modifiers = {
        "mod1" = {
          percentage = 10;
        };
      };
    };
  };
};
```

#### Deprecated Top-Level Options

For backward compatibility, the following top-level options are still supported but deprecated:
- `services.datum-gateway.listenAddress` → use `settings.stratum.listen_addr` instead
- `services.datum-gateway.listenPort` → use `settings.stratum.listen_port` instead

If you're using an existing configuration with these options, it will continue to work, but you should migrate to the canonical form for new configurations.

### Enable Web Dashboard/API

```nix
services.datum-gateway.settings.api = {
  listen_addr = "127.0.0.1";
  listen_port = 7152;
  admin_password = "your-secure-password";
};
```

Access the dashboard at `http://127.0.0.1:7152` via SSH tunnel:
```bash
ssh -L 7152:127.0.0.1:7152 root@your-node
```

### Solo Mining Fallback

By default, if the DATUM pool connection is lost, miners are disconnected.
To enable solo mining fallback instead:

```nix
services.datum-gateway.settings.datum.pooled_mining_only = false;
```

### Logging

```nix
services.datum-gateway.settings.logger = {
  log_to_console = true;
  log_to_stderr = false;  # Log to stdout instead of stderr
  log_to_file = true;
  log_file = "/var/log/datum-gateway/datum.log";
  log_rotate_daily = true;
  log_calling_function = true;
  log_level_console = 2;  # 0=All, 1=Debug, 2=Info, 3=Warn, 4=Error, 5=Fatal
  log_level_file = 1;
};
```

## Service Management

```bash
# Check service status
systemctl status datum-gateway

# View logs
journalctl -u datum-gateway -f

# Restart service
systemctl restart datum-gateway
```

## Connecting Miners

Configure your mining hardware with:
- **Pool URL**: `stratum+tcp://YOUR_NODE_IP:23334`
- **Username**: Your Bitcoin address (or any worker name if using `pool_pass_full_users = false`)
- **Password**: `x` (or empty)

### Worker Names

By default, miner usernames are passed to the pool as sub-worker names.
This allows tracking individual miners on the pool dashboard.

```nix
services.datum-gateway.settings.datum = {
  pool_pass_workers = true;      # Pass as pool_username.miner_username
  pool_pass_full_users = true;   # Pass raw usernames (for multiple payout addresses)
  always_pay_self = true;       # Include your payout in blocks when possible
  pooled_mining_only = true;     # Disconnect miners if pool unavailable
  protocol_global_timeout = 60;  # Seconds before reconnecting to pool
};
```

### Advanced Bitcoin RPC Configuration

For custom Bitcoin node setups:

```nix
services.datum-gateway.settings.bitcoind = {
  rpccookiefile = "/var/lib/bitcoind/.cookie";  # Custom RPC cookie path
  work_update_seconds = 40;                     # Template update interval
  notify_fallback = false;                      # Use blocknotify only
};
```

## Troubleshooting

### Stale Shares

If you see many stale shares:
1. Ensure your Bitcoin node is well-connected to the network
2. Check that `blocknotify` is working (logs should show "New block notification")
3. Consider reducing `work_update_seconds` for faster template updates

### Connection Issues

Check that:
1. The Bitcoin node is fully synced
2. RPC credentials are correct (nix-bitcoin handles this automatically)
3. The Stratum port (23334) is accessible from your miners

### Pool Connection

If the pool connection fails:
- Check your internet connection
- Verify the pool host/port settings
- Check logs for specific error messages

### PROXY Protocol Support

If you're running behind a proxy (like HAProxy), you can enable PROXY protocol support:

```nix
services.datum-gateway.settings.stratum.trust_proxy = 1;  # Trust 1 level of proxy
```

Set to `-1` to disable (default), or a positive number to trust that many proxy levels.

### Share Redirection

Redirect a portion of shares to alternate usernames using username modifiers:

```nix
services.datum-gateway.settings.stratum.username_modifiers = {
  "backup" = {
    percentage = 5;  # Redirect 5% of shares to "backup" user
  };
};
```

For more information, see the [DATUM Gateway documentation](https://github.com/OCEAN-xyz/datum_gateway).
