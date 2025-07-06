{ lib
, stdenv
, gnumake
, ncurses
, fetchgit
}:

stdenv.mkDerivation {
  pname = "agent-proxy";
  version = "master";

  src = fetchgit {
    url = "http://git.kernel.org/pub/scm/utils/kernel/kgdb/agent-proxy.git";
    rev = "468fe4c31e6c62c9bbb328b06ba71eaf7be0b76a";
    sha256 = "sha256-Li6glbnOHHhcEqP7JzDmoU+0QNLTfLzVP5D+ZZs7yA0=";
  };

  nativeBuildInputs = [ gnumake ];

  buildPhase = ''
    make
    make -C kdmx
  '';
  installPhase = ''
    mkdir -p $out/bin
    install -m755 -t $out/bin agent-proxy
    install -m755 -t $out/bin kdmx/kdmx
  '';

  meta = with lib; {
    homepage =
      "http://git.kernel.org/pub/scm/utils/kernel/kgdb/agent-proxy.git";
    description = "Small proxy for sharing a serial port between KGDB and a console";
    license = licenses.gpl2;
    platforms = platforms.unix;
    mainProgram = "agent-proxy";
  };
}
