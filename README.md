# nix-openvsp

[OpenVSP](https://openvsp.org) (Vehicle Sketch Pad) packaged for Nix.

OpenVSP has no package in nixpkgs and its source build pulls in a large set of
bundled dependencies, so this flake repackages the official Ubuntu `.deb`
published by upstream. Binaries are not redistributed here; they are fetched
from `openvsp.org` at build time.

Only `x86_64-linux` is supported, matching the upstream package.

The pinned nixpkgs is `nixos-26.05` on purpose: the prebuilt binaries link
against `libGLEW.so.2.2` and `libxml2.so.2`, and newer nixpkgs bumped those
SONAMEs. Consuming the package straight from `packages.<system>.default` uses
this flake's pinned nixpkgs and is therefore unaffected by your own pin
(see below). If you force `openvsp.inputs.nixpkgs.follows = "nixpkgs"` on an
unstable system, expect the build to fail until those libraries are
overridden.

## Run without installing

```console
$ nix run github:YOU/nix-openvsp
```

## Build from a checkout

```console
$ git clone https://github.com/YOU/nix-openvsp
$ cd nix-openvsp
$ nix build
$ ./result/bin/vsp
```

`nix flake check` evaluates the package and overlay.

## Use as a flake input

The simplest integration does not touch your nixpkgs at all: reference the
package output directly. It is built with this flake's pinned nixpkgs, and the
package already allows itself through nixpkgs' unfree check, so no
`allowUnfree` setting is needed.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    openvsp.url = "github:YOU/nix-openvsp";
  };

  outputs = { nixpkgs, openvsp, ... }: {
    nixosConfigurations.host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [ openvsp.packages.${pkgs.system}.default ];
        })
      ];
    };
  };
}
```

For Home Manager, the equivalent is `home.packages = [ openvsp.packages.${pkgs.system}.default ];`
in a `home-manager.users.<name>` module.

### Overlay (optional)

If you would rather have `pkgs.openvsp` available everywhere, use the overlay.
In that case the package is built against *your* nixpkgs, so your pin must
provide the expected library SONAMEs, and NOSA 1.3 has to be allowed:

```nix
{ inputs, pkgs, ... }:
{
  nixpkgs.overlays = [ inputs.openvsp.overlays.default ];
  nixpkgs.config.allowUnfreePackages = [ "openvsp" ];
  environment.systemPackages = [ pkgs.openvsp ];
}
```

## What gets installed

`package.nix` unpacks the `.deb`, patches the ELF dependencies with
`autoPatchelfHook`, and keeps upstream's on-disk layout under
`$out/lib/openvsp` because OpenVSP resolves its help, airfoil, and script data
relative to the real path of the executable. Wrappers in `$out/bin` expose:

- `vsp` — the GUI
- `vspscript` — batch/script runner
- `vspviewer`, `vspaero`, `vspaero_opt`, `vsploads`

The desktop entry and icon are not included; packages generally should not
install them into a user profile. Add one yourself if needed:

```nix
xdg.desktopEntries.openvsp = {
  name = "OpenVSP";
  exec = "${pkgs.openvsp}/bin/vsp %f";
  icon = "${pkgs.openvsp}/share/pixmaps/openvsp.png";
  categories = [ "Science" "Engineering" "Graphics" ];
};
```

The GUI needs a working OpenGL stack. It can be smoke-tested headlessly with
`xvfb-run -a vsp -snap 1`.

## Updating

1. Change `version` in `package.nix`.
2. Leave the old `hash` in place and run `nix build`; Nix prints the expected
   hash, which you copy back.

The `.deb` URL uses upstream's `current` directory, so old versions disappear
when NASA publishes a release.

## License

The Nix expressions in this repository are MIT licensed (see `LICENSE`).
OpenVSP itself is distributed under the NASA Open Source Agreement (NOSA) 1.3;
see [openvsp.org/license.shtml](https://openvsp.org/license.shtml).
