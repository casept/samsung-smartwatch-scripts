{ lib
, stdenv
, fetchFromSourcehut
, cmake
, zlib
, libusb1
, pkg-config
, enableGUI ? false
, qtbase ? null
}:

stdenv.mkDerivation {
  pname = "heimdall-grimler${lib.optionalString enableGUI "-gui"}";
  version = "master";

  src = fetchFromSourcehut {
    owner = "~grimler";
    repo = "Heimdall";
    rev = "d9554e7fa30a00abed7f0ac86b10e63c2c3b8e20";
    sha256 = "sha256-ga2hAZhsKosEG//qXEf+1vhJYtsHwyq6QvMlZaSFIgQ=";
  };

  buildInputs = [
    zlib
    libusb1
  ] ++ lib.optional enableGUI qtbase;
  nativeBuildInputs = [ cmake pkg-config ];

  cmakeFlags = [
    "-DDISABLE_FRONTEND=${if enableGUI then "OFF" else "ON"}"
    "-DLIBUSB_LIBRARY=${libusb1}"
  ];

  preConfigure = ''
    # Give ownership of the Galaxy S USB device to the logged in user.
    substituteInPlace heimdall/60-heimdall.rules --replace 'MODE="0666"' 'TAG+="uaccess"'
  '' + lib.optionalString stdenv.hostPlatform.isDarwin ''
    substituteInPlace libpit/CMakeLists.txt --replace "-std=gnu++11" ""
  '';

  installPhase = lib.optionalString (stdenv.hostPlatform.isDarwin && enableGUI) ''
    mkdir -p $out/Applications
    mv bin/heimdall-frontend.app $out/Applications/heimdall-frontend.app
    wrapQtApp $out/Applications/heimdall-frontend.app/Contents/MacOS/heimdall-frontend
  '' + ''
    mkdir -p $out/{bin,share/doc/heimdall,lib/udev/rules.d}
    install -m755 -t $out/bin                bin/*
    install -m644 -t $out/lib/udev/rules.d   ../heimdall/60-heimdall.rules
  '';

  meta = with lib; {
    homepage = "http://www.glassechidna.com.au/products/heimdall/";
    description = "Cross-platform tool suite to flash firmware onto Samsung Galaxy S devices";
    license = licenses.mit;
    platforms = platforms.unix;
    mainProgram = "heimdall";
  };
}
