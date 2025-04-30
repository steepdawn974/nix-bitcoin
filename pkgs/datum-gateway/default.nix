{ lib
, stdenv
, fetchFromGitHub
, pkgs
, cmake
, pkg-config
, jansson
, libmicrohttpd
, libsodium
, libcurl
, psmisc
, ...
}:

let
  # Source version information from pinned.nix
  sources = import ../pinned.nix { inherit (pkgs) fetchFromGitHub; };
  source = sources.datum-gateway;
in
stdenv.mkDerivation rec {
  pname = "datum-gateway";
  version = source.version;

  src = fetchFromGitHub {
    owner = source.owner;
    repo = source.repo;
    rev = source.rev;
    sha256 = source.sha256;
  };

  nativeBuildInputs = [ cmake pkg-config ];
  buildInputs = [ jansson libmicrohttpd libsodium libcurl psmisc ];

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
