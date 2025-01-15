{ lib
, stdenv
, fetchFromGitHub
, python3Packages
}:

with python3Packages;

stdenv.mkDerivation
{
  pname = "sboot_upload";
  version = "master";

  src = fetchFromGitHub {
    owner = "bkerler";
    repo = "sboot_dump";
    rev = "3abc2cfd4c7d89c382122e65f0c8ad9bdb9116e4";
    sha256 = "sha256-8pKYHuHNKP7idJCHKElwg5Byvb55grrJQAt84eniTuM=";
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp samupload.py $out/bin/samupload
    chmod +x $out/bin/samupload
    runHook postInstall
  '';

  propagatedBuildInputs = [ pyusb ];

  meta = with lib;
    {
      homepage = "https://github.com/bkerler/sboot_dump";
      description = "SUC - A tool to dump RAM using Samsung S-Boot Upload Mode ";
      license = licenses.mit;
      platforms = platforms.unix;
      mainProgram = "samupload";
    };
}
