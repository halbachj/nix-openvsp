{
  description = "OpenVSP (Vehicle Sketch Pad) packaged for Nix";

  # OpenVSP ships prebuilt binaries that link against specific SONAMEs
  # (libGLEW.so.2.2, libxml2.so.2), so pin the release whose nixpkgs provides
  # them instead of floating with unstable.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # NOSA 1.3 is not on nixpkgs' free-license list, so allow just the
      # OpenVSP packages instead of flipping the global unfree switch.
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfreePredicate =
            pkg:
            builtins.elem (nixpkgs.lib.getName pkg) [
              "openvsp"
              "openvsp-python"
            ];
        };

      # The prebuilt _vsp extension is compiled against Python 3.12, which is
      # not the default python3 in nixos-26.05, so build the bindings against
      # python312 explicitly.
      openvspFor =
        pkgs:
        let
          openvsp = pkgs.callPackage ./package.nix { };
          openvsp-python = pkgs.python312.pkgs.callPackage ./python.nix { inherit openvsp; };
          python-env = pkgs.python312.withPackages (_: [ openvsp-python ]);
        in
        {
          inherit openvsp openvsp-python python-env;
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          inherit (openvspFor (pkgsFor system)) openvsp openvsp-python python-env;
        in
        {
          inherit openvsp openvsp-python;

          openvsp-python-env = python-env;

          default = openvsp;
        }
      );

      overlays.default = final: _prev: {
        openvsp = final.callPackage ./package.nix { };
        openvsp-python = final.python312.pkgs.callPackage ./python.nix {
          openvsp = final.openvsp;
        };
        openvsp-python-env = final.python312.withPackages (_: [ final.openvsp-python ]);

        # Expose the bindings as `python312Packages.openvsp` as well.  A plain
        # overrideScope of python312Packages does not feed into
        # python312.withPackages, so extend the package set instead and gate it
        # on Python 3.12: the prebuilt extension is not loadable by 3.13.
        pythonPackagesExtensions = _prev.pythonPackagesExtensions ++ [
          (
            python-final: python-prev:
            nixpkgs.lib.optionalAttrs python-prev.python.isPy312 {
              openvsp = python-final.callPackage ./python.nix {
                openvsp = final.openvsp;
              };
            }
          )
        ];
      };

      checks = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          inherit (openvspFor pkgs) openvsp openvsp-python;
          python-env = pkgs.python312.withPackages (_: [ openvsp-python ]);
        in
        {
          openvsp-python-tools =
            pkgs.runCommand "openvsp-python-tools-check"
              {
                nativeBuildInputs = [ python-env ];
                OPENVSP_VERSION = openvsp.version;
                OPENVSP_BIN = "${openvsp}/bin";
              }
              ''
                cd "$TMPDIR"
                python ${./tests/python-tools.py}
                touch "$out"
              '';
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
