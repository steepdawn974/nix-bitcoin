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
  version = "28.1-lnhance-b4bc500";

  src = fetchFromGitHub {
    owner = "lnhance";
    repo = "bitcoin";
    rev = "b4bc50067644ef18d5043ce547e905c7c482a601";
    sha256 = "sha256-KHT8Jsq5mNS9l0lvi9+2v5ZUzar+0HWMNQrWKnW7hFE=";
  };

  # Fix fuzz test compilation error by adding missing LockInOnTimeout() implementation
  # The LNhance fork added LockInOnTimeout() pure virtual function but didn't update the test mock
  # See: docs/lnhance-fuzz-test-bug-report.md
  postPatch = ''
    # Add the missing LockInOnTimeout() method to TestConditionChecker class
    sed -i '/int MinActivationHeight(const Consensus::Params& params) const override/i\
    bool LockInOnTimeout(const Consensus::Params\& params) const override\
    {\
        return m_lock_in_on_timeout;\
    }\
' src/test/fuzz/versionbits.cpp

    # Add the member variable
    sed -i '/int64_t m_min_activation_height;/a\    bool m_lock_in_on_timeout;' src/test/fuzz/versionbits.cpp
    
    # Update the constructor signature and initializer list
    sed -i 's/TestConditionChecker(int64_t begin, int64_t end, int period, int threshold, int min_activation_height, int bit)/TestConditionChecker(int64_t begin, int64_t end, int period, int threshold, int min_activation_height, int bit, bool lock_in_on_timeout = false)/' src/test/fuzz/versionbits.cpp
    sed -i 's/: m_begin{begin}, m_end{end}, m_period{period}, m_threshold{threshold}, m_min_activation_height{min_activation_height}, m_bit{bit}/: m_begin{begin}, m_end{end}, m_period{period}, m_threshold{threshold}, m_min_activation_height{min_activation_height}, m_lock_in_on_timeout{lock_in_on_timeout}, m_bit{bit}/' src/test/fuzz/versionbits.cpp
  '';

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
    # Tests are disabled by default for faster builds, but the patch above
    # ensures they will compile if doCheck is set to true
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

  # Tests are disabled by default for production builds
  # The patch above fixes the fuzz test compilation, so tests can be enabled if needed
  doCheck = false;

  meta = with lib; {
    description = "Bitcoin Core with LNHANCE softfork activation parameters";
    homepage = "https://github.com/lnhance/bitcoin";
    license = licenses.mit;
    platforms = platforms.unix;
    maintainers = [ maintainers.erikarvstedt ];
  };
}
