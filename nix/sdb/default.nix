{ lib
, stdenv
, gnumake
, ncurses
, fetchgit
}:

stdenv.mkDerivation {
  pname = "sdb";
  version = "master";

  src = fetchgit {
    url = "git://git.tizen.org/sdk/tools/sdb";
    rev = "b7954d2a3c580003aadc589d2a5082a87ac5af0f";
    sha256 = "sha256-gmoS2r9u+S8n6FjcdxX1mjFmwm3rIfLw+Jp0dpiCDKo=";
  };
  patches = [
    ./0001-Fix-build-of-SDB-client.patch
    ./0002-Do-not-hardcode-bash-path-in-build-script.patch
  ];

  buildInputs = [ ncurses ];
  nativeBuildInputs = [ gnumake ];

  buildPhase = ''
    make MODULE=sdb sdb
    make MODULE=sdbd sdbd
  '';

  installPhase = ''
    mkdir -p $out/bin
    install -m755 -t $out/bin bin/sdb
    install -m755 -t $out/bin bin/sdbd
  '';

  meta = with lib; {
    homepage =
      "https://developer.tizen.org/dev-guide/2.4/org.tizen.devtools/html/common_tools/smart_dev_bridge.htm";
    description = "Tool for interacting with Tizen devices";
    license = licenses.asl20;
    platforms = platforms.unix;
    mainProgram = "sdb";
  };
}
