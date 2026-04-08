{ lib
, stdenv
, fetchFromGitHub
, cmake
, pkg-config
, util-linux
, hexdump
, autoSignDarwinBinariesHook ? null
, boost
, libevent
, miniupnpc
, zeromq
, zlib
, libsodium
, withWallet ? true
, db48
, sqlite
, qrencode
, withCui ? true
, python3
, withGui ? false
, withUpnp ? false
, qtbase ? null
, qttools ? null
, wrapQtAppsHook ? null
}:

stdenv.mkDerivation rec {
  pname = if withGui then "bitcoin-knots-bip110" else "bitcoind-knots-bip110";
  version = "29.3.knots20260210+bip110-v0.4.1";

  src = fetchFromGitHub {
    owner = "dathonohm";
    repo = "bitcoin";
    rev = "v29.3.knots20260210+bip110-v0.4.1";
    sha256 = "sha256-YoLe0mQN7/SZLnrjYfPxE5cP8yl5DjDuGxBMhOEGRwg=";
  };

  nativeBuildInputs =
    [ cmake pkg-config ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ util-linux ]
    ++ lib.optionals (stdenv.hostPlatform.isDarwin && autoSignDarwinBinariesHook != null) [ autoSignDarwinBinariesHook ]
    ++ lib.optionals withGui [ qttools wrapQtAppsHook ];

  buildInputs = [
    boost
    libevent
    zeromq
    zlib
    libsodium
    qrencode
  ] ++ lib.optionals withWallet [
    db48
    sqlite
  ] ++ lib.optionals withUpnp [ miniupnpc ]
    ++ lib.optional withCui python3
    ++ lib.optional withGui qtbase
    ++ lib.optionals stdenv.hostPlatform.isDarwin [ hexdump ];

  cmakeFlags = [
    "-DBUILD_TESTS=OFF"
    "-DBUILD_BENCH=OFF"
  ]
  ++ [ ("-DWITH_MINIUPNPC=" + (if withUpnp then "ON" else "OFF")) ]
  ++ [ ("-DWITH_SODIUM=ON") ]
  ++ [ ("-DWITH_ZMQ=" + "ON") ]
  ++ [ ("-DBUILD_GUI=" + (if withGui then "ON" else "OFF")) ]
  ++ [ ("-DBUILD_BITCOIN_WALLET=" + (if withWallet then "ON" else "OFF")) ];

  enableParallelBuilding = true;
  doCheck = false;

  meta = with lib; {
    description = "Bitcoin Knots with BIP-110 UASF activation client (fork of Bitcoin Knots v29.3.knots20260210)";
    homepage = "https://github.com/dathonohm/bitcoin";
    changelog = "https://github.com/dathonohm/bitcoin/releases/tag/v${version}";
    license = licenses.mit;
    platforms = platforms.unix;
  };
}
