{
  lib,
  stdenv,
  fetchFromGitHub,
  autoreconfHook,
  pkg-config,
  installShellFiles,
  util-linux,
  hexdump,
  autoSignDarwinBinariesHook ? null,
  wrapQtAppsHook ? null,
  boost,
  libevent,
  miniupnpc,
  zeromq,
  zlib,
  libsodium,
  db48,
  sqlite,
  qrencode,
  qtbase ? null,
  qttools ? null,
  python3,
  withGui ? false,
  withWallet ? true,
  withUpnp ? false
}:

stdenv.mkDerivation rec {
  pname = if withGui then "bitcoin-core-lnhance" else "bitcoind-core-lnhance";
  version = "28.1-lnhance-790f5e0";

  src = fetchFromGitHub {
    owner = "lnhance";
    repo = "bitcoin";
    rev = "790f5e0eb610cdfe6cae7971d7b07b5b190cc649";
    sha256 = "sha256-n75e0xdfnMivPQ2FkOZItq5mC2/JLhoGMqAyizsodJE==";
  };

  nativeBuildInputs = [
    autoreconfHook
    pkg-config
    installShellFiles
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ util-linux ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [ hexdump ]
  ++ lib.optionals (stdenv.hostPlatform.isDarwin && autoSignDarwinBinariesHook != null) [ autoSignDarwinBinariesHook ]
  ++ lib.optionals withGui [ wrapQtAppsHook ];

  buildInputs = [
    boost
    libevent
    zeromq
    zlib
    libsodium
  ]
  ++ lib.optionals withUpnp [ miniupnpc ]
  ++ lib.optionals withWallet [ sqlite ]
  ++ lib.optionals (withWallet && !stdenv.hostPlatform.isDarwin) [ db48 ]
  ++ lib.optionals withGui [ qrencode qtbase qttools ];

  postInstall = ''
    installShellCompletion --bash contrib/completions/bash/bitcoin-cli.bash
    installShellCompletion --bash contrib/completions/bash/bitcoind.bash
    installShellCompletion --bash contrib/completions/bash/bitcoin-tx.bash

    installShellCompletion --fish contrib/completions/fish/bitcoin-cli.fish
    installShellCompletion --fish contrib/completions/fish/bitcoind.fish
    installShellCompletion --fish contrib/completions/fish/bitcoin-tx.fish
  '';

  configureFlags = [
    "--with-boost-libdir=${boost.out}/lib"
    "--disable-bench"
    "--disable-tests"
    "--disable-gui-tests"
  ]
  ++ lib.optionals (!withWallet) [
    "--disable-wallet"
  ]
  ++ lib.optionals withGui [
    "--with-gui=qt5"
    "--with-qt-bindir=${qtbase.dev}/bin:${qttools.dev}/bin"
  ];

  enableParallelBuilding = true;

  doCheck = false;

  meta = with lib; {
    description = "Bitcoin Core with LNHANCE softfork activation parameters";
    homepage = "https://github.com/lnhance/bitcoin";
    license = licenses.mit;
    platforms = platforms.unix;
    maintainers = [ maintainers.erikarvstedt ];
  };
}
