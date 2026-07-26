{ lib
, python3Packages
, fetchFromGitHub
, nix-update-script
}:
with python3Packages;
buildPythonApplication rec {
  pname = "allyourbase";
  version = "git";
  src = fetchFromGitHub {
    owner = "8051Enthusiast";
    repo = pname;
    rev = "78e98f7a592c5bfdb52590bdd26139202b602100";
    hash = "sha256-CIeet51wG6daSn5Ek4mB9uQqqDOoYdYOv/qdgTcWpHk=";
  };

  pyproject = false;

  propagatedBuildInputs = [ numpy ];

  passthru.updateScript = nix-update-script { };

  installPhase = ''
    mkdir -p "$out/bin"
    install -m 755 ./allyourbase.py "$out/bin/allyourbase"
  '';

  meta = {
    description = "Finds the base address of a firmware by comparing string addresses with target pointer addresses";
    homepage = "https://github.com/8051Enthusiast/allyourbase";
    license = lib.licenses.mit;
  };
}
