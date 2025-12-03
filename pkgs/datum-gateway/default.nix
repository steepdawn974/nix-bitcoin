{
  lib
, stdenv
, fetchFromGitHub
, pkgs
, cmake
, pkg-config
, jansson
, libmicrohttpd
, libsodium
, curl
, psmisc
, datum-gateway-src-attrs
, ...
}:

stdenv.mkDerivation rec {
  pname = "datum-gateway";
  version = datum-gateway-src-attrs.version;

  src = fetchFromGitHub {
    owner = datum-gateway-src-attrs.owner;
    repo = datum-gateway-src-attrs.repo;
    rev = datum-gateway-src-attrs.rev;
    sha256 = datum-gateway-src-attrs.sha256;
  };

  # Apply patch to disable the problematic Jansson check
  patches = [ ./0001-disable-jansson-long-long-check.patch ];

  nativeBuildInputs = [ cmake pkg-config ];
  buildInputs = [ jansson libmicrohttpd libsodium curl psmisc ];

  cmakeFlags = [ "-DCMAKE_C_STANDARD=17" ];

  buildPhase = "make";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp datum_gateway $out/bin/
    runHook postInstall
  '';

  meta = with lib; {
    description = "DATUM Gateway - a gateway for bitcoin and Nostr-related applications";
    homepage = "https://github.com/OCEAN-xyz/datum_gateway";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = with maintainers; [ ];
  };
}
