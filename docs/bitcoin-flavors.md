# Bitcoin Implementation Flavors

nix-bitcoin supports multiple Bitcoin implementations, allowing you to choose the variant that best suits your needs. This guide explains how to select and configure different Bitcoin implementations in your NixOS system.

## Available Implementations

### Bitcoin Core (default)
The standard Bitcoin Core implementation maintained by the Bitcoin Core developers.

- **Implementation ID**: `"core"`
- **Package**: `pkgs.bitcoind`
- **Homepage**: https://bitcoincore.org/

### Bitcoin Knots
A derivative of Bitcoin Core with a collection of improvements and additional features.

- **Implementation ID**: `"knots"`
- **Package**: `pkgs.bitcoin-knots`
- **Homepage**: https://bitcoinknots.org/

### Bitcoin Core LNhance
Bitcoin Core with the LNhance softfork activation parameters (BIPs 119, 348, 349, 442: CTV, CSFS, IK, PC).

- **Implementation ID**: `"core-lnhance"`
- **Package**: `pkgs.bitcoin-core-lnhance`
- **Homepage**: https://github.com/lnhance/bitcoin

## Configuration

### Basic Setup

To select a Bitcoin implementation, set the `services.bitcoind.implementation` option in your `configuration.nix`:

```nix
{
  services.bitcoind = {
    enable = true;
    implementation = "core";  # or "knots" or "core-lnhance"
    
    # Standard bitcoind options work with all implementations
    prune = 10000;
    txindex = false;
    
    rpc = {
      address = "0.0.0.0";
      allowip = [ "192.168.10.0/24" ];
    };
  };
}
```

### Using Bitcoin Knots

```nix
{
  services.bitcoind = {
    enable = true;
    implementation = "knots";
    
    # Standard options
    prune = 10000;
    
    # Knots-specific options
    knotsSpecificOptions = {
      datacarriersize = 82;
      mempoolfullrbf = true;
      acceptnonstdtxn = true;
      rejectparasites = true;
      rejecttokens = true;
    };
  };
}
```

### Using Bitcoin Core LNhance

```nix
{
  services.bitcoind = {
    enable = true;
    implementation = "core-lnhance";
    
    # Standard options
    prune = 10000;
    
    # LNhance-specific options (if needed)
    lnhanceSpecificOptions = {
      # Add any LNhance-specific configuration here
    };
  };
}
```

## Integration with NixOS Flakes

If you're using nix-bitcoin as a Flake input in your system configuration, you have two options for accessing the custom Bitcoin packages.

### Option 1: Using the Overlay (Recommended)

Apply the nix-bitcoin overlay to make all packages available through your nixpkgs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-bitcoin.url = "github:fort-nix/nix-bitcoin/release";
    # Or use a local path during development:
    # nix-bitcoin.url = "path:/path/to/your/nix-bitcoin";
  };

  outputs = { self, nixpkgs, nix-bitcoin }: {
    nixosConfigurations.mynode = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nix-bitcoin.nixosModules.default
        
        {
          # Apply the overlay to get custom packages
          nixpkgs.overlays = [ nix-bitcoin.overlays.default ];
          
          # Now you can use any implementation
          services.bitcoind = {
            enable = true;
            implementation = "knots";  # or "core-lnhance"
          };
        }
      ];
    };
  };
}
```

### Option 2: Explicit Package Reference

Set the package explicitly without applying the overlay:

```nix
{
  services.bitcoind = {
    enable = true;
    package = nix-bitcoin.legacyPackages.${pkgs.system}.bitcoin-knots;
    # Or:
    # package = nix-bitcoin.legacyPackages.${pkgs.system}.bitcoin-core-lnhance;
  };
}
```

## Implementation-Specific Options

### Standard Options (All Implementations)

All implementations support the standard `services.bitcoind` options:

- `dataDir` - Data directory location
- `prune` - Pruning configuration
- `txindex` - Transaction index
- `rpc.*` - RPC configuration
- `zmqpubrawblock`, `zmqpubrawtx` - ZMQ notifications
- And many more (see [modules/bitcoind.nix](../modules/bitcoind.nix))

### Knots-Specific Options

Bitcoin Knots supports additional options via `knotsSpecificOptions`:

```nix
knotsSpecificOptions = {
  # Policy options
  datacarriersize = 82;              # Max size for data carrier txns
  mempoolfullrbf = true;             # Full RBF logic
  acceptnonstdtxn = true;            # Accept non-standard transactions
  permitbarepubkey = true;           # Permit bare P2PK outputs
  
  # Knots defaults
  rejectparasites = true;            # Refuse parasitic overlay protocols
  rejecttokens = true;               # Refuse non-bitcoin token transactions
  
  # Network/Performance
  blockmaxsize = 300000;             # Maximum block size (bytes)
  lowmem = 10;                       # Flush caches if memory below N MiB
  
  # See modules/bitcoind.nix for complete list of examples
};
```

### LNhance-Specific Options

Bitcoin Core LNhance supports additional options via `lnhanceSpecificOptions`:

```nix
lnhanceSpecificOptions = {
  # Add any LNhance-specific configuration options here
  # The format is the same as knotsSpecificOptions
};
```

## Troubleshooting

### Build Failures

If a package fails to build:

1. Check the build logs:
   ```bash
   nix log /nix/store/...-bitcoind-*.drv
   ```

2. Verify the source hash is correct in the package definition

3. Ensure all dependencies are available

## Additional Resources

- [Configuration Guide](./configuration.md)
- [Services Documentation](./services.md)
- [Bitcoin Core Documentation](https://bitcoin.org/en/bitcoin-core/)
- [Bitcoin Knots Documentation](https://bitcoinknots.org/)
- [LNhance Proposal](https://github.com/lnhance/bitcoin)
