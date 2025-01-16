{
  description = "Dev env for AsteroidOS rinato port";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
    rinato-kernel-build = {
      url = "github:casept/rinato-kernel-build";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rinato-kernel-build }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };
          downstreamKernelInputs = [ rinato-kernel-build.packages.${system}.default pkgs.bash pkgs.gnumake pkgs.ncurses ];
          # Add ccache wrapper to GCC
          cachedArmGcc =
            (pkgs.gcc-arm-embedded-13.overrideAttrs (final: previous: {
              buildInputs = [ pkgs.bash pkgs.coreutils pkgs.ccache ];
              postFixup = previous.postFixup + ''
                mv $out/bin/arm-none-eabi-gcc $out/bin/arm-none-eabi-gcc-unwrapped
                cat <<'_EOF' >"$out/bin/arm-none-eabi-gcc"
                #!${pkgs.bash}/bin/bash -e
                path=$(${pkgs.coreutils}/bin/dirname "$0")
                exec ${pkgs.ccache}/bin/ccache "$path/arm-none-eabi-gcc-unwrapped" "$@"
                _EOF
                chmod 0755 "$out/bin/arm-none-eabi-gcc"
              '';
            }));
          kernelInputs = [
            cachedArmGcc
            pkgs.gdb
            pkgs.gnumake
            pkgs.ncurses
            pkgs.flex
            pkgs.bison
            pkgs.bc
            pkgs.openssl
            pkgs.gcc
            pkgs.zlib
            pkgs.elfutils
          ];
          toolingInputs = [ pkgs.usbutils pkgs.just pkgs.python3 pkgs.zellij (pkgs.callPackage ./heimdall.nix { }) (pkgs.callPackage ./sboot_upload.nix { }) pkgs.dtc pkgs.tio ];
        in
        with pkgs;
        {
          devShells.default = mkShell {
            buildInputs = kernelInputs ++ toolingInputs;
          };
          # Dowstream kernel requires ancient toolchain and harcodes e.g. /bin/bash
          devShells.downstream = (buildFHSUserEnv {
            name = "dowstream-fhs";
            targetPkgs = pkgs: downstreamKernelInputs;
          }).env;

          # Yocto has special needs
          devShells.asteroid = (buildFHSUserEnv {
            name = "asteroid-fhs";
            targetPkgs =
              let
                ncurses' = pkgs.ncurses5.overrideAttrs
                  (old: {
                    configureFlags = old.configureFlags ++ [ "--with-termlib" ];
                    postFixup = "";
                  });
              in
              (with pkgs; [
                attr
                bc
                binutils
                bzip2
                chrpath
                cpio
                diffstat
                expect
                file
                gcc
                gdb
                git
                gnumake
                hostname
                kconfig-frontends
                libxcrypt
                lz4
                # https://github.com/NixOS/nixpkgs/issues/218534
                # postFixup would create symlinks for the non-unicode version but since it breaks
                # in buildFHSUserEnv, we just install both variants
                ncurses'
                (ncurses'.override { unicodeSupport = false; })
                patch
                perl
                (python3.withPackages (ps: [ ps.setuptools ps.pyaml ]))
                rpcsvc-proto
                unzip
                util-linux
                wget
                which
                xz
                zlib
                zstd
                bison
                flex
                pkg-config
              ] ++ (with pkgs.xorg; [
                libX11
                libXext
                libXrender
                libXi
                libXtst
                libxcb
              ]));
            multiPkgs = ps: [ ];
            extraOutputsToInstall = [ "dev" ];
            profile =
              let
                inherit (pkgs) lib;

                setVars = {
                  "NIX_DONT_SET_RPATH" = "1";
                };

                exportVars = [
                  "LOCALE_ARCHIVE"
                  "NIX_CC_WRAPPER_TARGET_HOST_${pkgs.stdenv.cc.suffixSalt}"
                  "NIX_CFLAGS_COMPILE"
                  "NIX_CFLAGS_LINK"
                  "NIX_LDFLAGS"
                  "NIX_DYNAMIC_LINKER_${pkgs.stdenv.cc.suffixSalt}"
                ];

                exports =
                  (builtins.attrValues (builtins.mapAttrs (n: v: "export ${n}= \"${v}\"") setVars)) ++
                  (builtins.map (v: "export ${v}") exportVars);

                passthroughVars = (builtins.attrNames setVars) ++ exportVars;

                # TODO limit export to native pkgs?
                nixconf = pkgs.writeText "nixvars.conf" ''
                  # This exports the variables to actual build environments
                  # From BB_ENV_PASSTHROUGH_ADDITIONS
                  ${lib.strings.concatStringsSep "\n" exports}

                  # Exclude these when hashing
                  # the packages in yocto
                  BB_BASEHASH_IGNORE_VARS += "${lib.strings.concatStringsSep " " passthroughVars}"
                '';
              in
              ''
                # buildFHSUserEnvBubblewrap configures ld.so.conf while buildFHSUserEnv additionally sets the LD_LIBRARY_PATH.
                # This is redundant, and incorrectly overrides the RPATH of yocto-built binaries causing the dynamic loader
                # to load libraries from the host system that they were not built against, instead of those from yocto.
                unset LD_LIBRARY_PATH

                # By default gcc-wrapper will compile executables that specify a dynamic loader that will ignore the FHS
                # ld-config causing unexpected libraries to be loaded when when the executable is run.
                export NIX_DYNAMIC_LINKER_${pkgs.stdenv.cc.suffixSalt}="/lib/ld-linux-x86-64.so.2"

                # These are set by buildFHSUserEnvBubblewrap
                export BB_ENV_PASSTHROUGH_ADDITIONS="${lib.strings.concatStringsSep " " passthroughVars}"

                # source the config for bibake equal to --postread
                export BBPOSTCONF="${nixconf}"
              '';
          }).env;
        }
      );
}

