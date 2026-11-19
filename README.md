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

`nix flake check` evaluates the package, the overlay, and the Python tool
smoke test.

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

### Python bindings

The Python API ships inside the same `.deb`, including the compiled `_vsp`
extension and copies of the VSPAERO tools. Upstream builds the extension for
Python 3.12, while the default `python3` in nixos-26.05 is 3.13, so the
bindings are exposed for Python 3.12 only.

Two package outputs are available:

- `packages.<system>.openvsp-python` — the bindings, for use with
  `python312Packages`.
- `packages.<system>.openvsp-python-env` — a Python 3.12 environment that
  already has the bindings installed.

```console
$ nix shell github:YOU/nix-openvsp#openvsp-python-env
$ python -c 'import openvsp; print(openvsp.GetVSPVersion())'
```

With the overlay, add the bindings to an existing Python 3.12 environment:

```nix
{ inputs, pkgs, ... }:
{
  nixpkgs.overlays = [ inputs.openvsp.overlays.default ];

  environment.systemPackages = [
    (pkgs.python312.withPackages (ps: [ ps.openvsp ]))
  ];
}
```

The overlay exposes `pkgs.openvsp-python`, `pkgs.openvsp-python-env`, and
`pkgs.python312Packages.openvsp`. It deliberately does not add `openvsp` to
`python313Packages`, since the prebuilt extension will not load there.

The bindings keep upstream's `openvsp` package directory intact so that
`openvsp.GetVSPAEROPath()` finds the bundled VSPAERO solver, viewer, and loads
executables. The flake check runs a `VSPAEROComputeGeometry` and
`VSPAEROSweep` analysis through the Python API, and also checks that every
tool in `$out/bin` is executable:

```console
$ nix build .#checks.x86_64-linux.openvsp-python-tools -L
```

### Overlay (optional)

If you would rather have `pkgs.openvsp` available everywhere, use the overlay.
In that case the package is built against *your* nixpkgs, so your pin must
provide the expected library SONAMEs, and NOSA 1.3 has to be allowed:

```nix
{ inputs, pkgs, ... }:
{
  nixpkgs.overlays = [ inputs.openvsp.overlays.default ];
  nixpkgs.config.allowUnfreePackages = [ "openvsp" "openvsp-python" ];
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
