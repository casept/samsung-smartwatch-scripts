{ lib
, stdenv
, fetchFromSourcehut
, cmake
, zlib
, libusb1
, enableGUI ? false
, qtbase ? null
}:

stdenv.mkDerivation {
  pname = "heimdall-grimler${lib.optionalString enableGUI "-gui"}";
  version = "master";

  src = fetchFromSourcehut {
    owner = "~grimler";
    repo = "Heimdall";
    rev = "1afaefb3fd5e03614e7810388d335f88c75ac3f6";
    sha256 = "sha256-DiHaht+gZ8Ot6hMbY8BtNaNnsgalkX5tcJ8Fe6WYtyk=";
  };

  buildInputs = [
    zlib
    libusb1
  ] ++ lib.optional enableGUI qtbase;
  nativeBuildInputs = [ cmake ];

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
