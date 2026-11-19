# nix-openvsp

[OpenVSP](https://openvsp.org) (Vehicle Sketch Pad) packaged for Nix.

OpenVSP has no package in nixpkgs and its source build pulls in a large set of
bundled dependencies, so this flake repackages the official Ubuntu `.deb`
published by upstream. Binaries are not redistributed here; they are fetched
from `openvsp.org` at build time.

Only `x86_64-linux` is supported, matching the upstream package.

The input is pinned to `nixos-26.05` on purpose: the prebuilt binaries link
against `libGLEW.so.2.2` and `libxml2.so.2`, and newer nixpkgs bumped those
SONAMEs. If you override the `nixpkgs` input (for example with
`openvsp.inputs.nixpkgs.follows = "nixpkgs"` on unstable), expect the build to
fail until those libraries are overridden too.

## Run without installing

```console
$ nix run github:YOU/nix-openvsp
```

## Use as a flake input

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    openvsp.url = "github:YOU/nix-openvsp";
    openvsp.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, openvsp, ... }: {
    nixosConfigurations.host = nixpkgs.lib.nixosSystem {
      modules = [
        {
          nixpkgs.overlays = [ openvsp.overlays.default ];
          # NOSA 1.3 is marked unfree by nixpkgs.
          nixpkgs.config.allowUnfreePackages = [ "openvsp" ];
          environment.systemPackages = [ pkgs.openvsp ];
        }
      ];
    };
  };
}
```

With Home Manager, the same applies: add the overlay and
`nixpkgs.config.allowUnfreePackages = [ "openvsp" ]`, then put `pkgs.openvsp`
in `home.packages`.

## Package layout

`package.nix` unpacks the `.deb`, patches the ELF dependencies with
`autoPatchelfHook`, and keeps upstream's on-disk layout under
`$out/lib/openvsp` because OpenVSP resolves its help, airfoil, and script data
relative to the real path of the executable. Wrappers in `$out/bin` expose:

- `vsp` — the GUI
- `vspscript` — batch/script runner
- `vspviewer`, `vspaero`, `vspaero_opt`, `vsploads`

The GUI also needs a working OpenGL stack; under a headless session it can be
smoke-tested with `xvfb-run -a vsp -snap 1`.

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
