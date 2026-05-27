{ lib
, stdenv
, fetchurl
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
  pname = if withGui then "bitcoin-knots" else "bitcoind-knots";
  version = "29.3.knots20260508";

  src = fetchurl {
    url = "https://bitcoinknots.org/files/29.x/29.3.knots20260508/bitcoin-29.3.knots20260508.tar.gz";
    sha256 = "sha256-jjrr2sqzL29rZdkMmKGIlSVToSpXfgtY0TUlv9Wd1jA=";
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

  # Explicit CMake feature toggles per upstream options
  cmakeFlags = [
    "-DBUILD_TESTS=OFF"
    "-DBUILD_BENCH=OFF"
    "-DRDTS_CONSENT=RUNTIME_CHECK"
  ]
  ++ [ ("-DWITH_MINIUPNPC=" + (if withUpnp then "ON" else "OFF")) ]
  ++ [ ("-DWITH_SODIUM=ON") ]
  ++ [ ("-DWITH_ZMQ=" + "ON") ]
  ++ [ ("-DBUILD_GUI=" + (if withGui then "ON" else "OFF")) ]
  ++ [ ("-DBUILD_BITCOIN_WALLET=" + (if withWallet then "ON" else "OFF")) ];

  enableParallelBuilding = true;
  doCheck = false;

  meta = with lib; {
    description = "Derivative of Bitcoin Core with a collection of improvements";
    homepage = "https://bitcoinknots.org/";
    changelog = "https://github.com/bitcoinknots/bitcoin/blob/v${version}/doc/release-notes.md";
    license = licenses.mit;
    platforms = platforms.unix;
  };
}
