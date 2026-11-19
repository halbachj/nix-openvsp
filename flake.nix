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

      # NOSA 1.3 is not on nixpkgs' free-license list, so allow just this one
      # package instead of flipping the global unfree switch.
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "openvsp" ];
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          openvsp = pkgs.callPackage ./package.nix { };
          default = self.packages.${system}.openvsp;
        }
      );

      overlays.default = final: _prev: {
        openvsp = final.callPackage ./package.nix { };
      };

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
