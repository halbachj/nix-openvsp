#!/usr/bin/env python3
"""Check that the OpenVSP Python API can reach every bundled tool.

The Python extension locates VSPAERO, VSPViewer, and VSPLoads relative to the
package directory.  These checks fail if the wrapper only installs the .py
files and the compiled extensions but forgets the executables, or if the
solver cannot actually be launched through the Analysis Manager.
"""

import os
import sys
import tempfile

import openvsp

failures = []


def check(condition, message):
    print(("ok: " if condition else "FAIL: ") + message)
    if not condition:
        failures.append(message)


expected_version = os.environ.get("OPENVSP_VERSION")
version = openvsp.GetVSPVersion()
check(
    expected_version is None or expected_version in version,
    f"openvsp reports its version ({version!r})",
)

# VSPAERO, VSPViewer, and VSPLoads must all be reachable from the path the API
# will use when it launches an analysis.
aero_path = openvsp.GetVSPAEROPath()
check(bool(aero_path), f"GetVSPAEROPath() is non-empty ({aero_path!r})")
check(
    openvsp.CheckForVSPAERO(aero_path),
    "CheckForVSPAERO() finds the solver, viewer, and loads tools",
)

for tool in ("vspaero", "vspaero_opt", "vspviewer", "vsploads"):
    path = os.path.join(aero_path, tool)
    check(
        os.path.isfile(path) and os.access(path, os.X_OK),
        f"VSPAERO tool {tool!r} is executable at {path}",
    )

# The main package installs the same tools under $out/bin, alongside vsp and
# vspscript.  Check those too so the Python wrapper cannot silently drift from
# the package it wraps.
bin_dir = os.environ.get("OPENVSP_BIN")
if bin_dir:
    for tool in ("vsp", "vspscript", "vspaero", "vspaero_opt", "vspviewer", "vsploads"):
        path = os.path.join(bin_dir, tool)
        check(os.access(path, os.X_OK), f"{tool!r} is executable at {path}")

# Basic geometry API.
openvsp.ClearVSPModel()
wing_id = openvsp.AddGeom("WING")
openvsp.Update()
check(bool(wing_id), f"AddGeom('WING') returned an id ({wing_id!r})")

# Run VSPAERO for real through the Analysis Manager.  Merely checking that the
# executable exists is not enough: the solver needs its support files and a
# working RPATH, and the API needs to find both.
with tempfile.TemporaryDirectory() as workdir:
    old_cwd = os.getcwd()
    os.chdir(workdir)
    try:
        for analysis in ("VSPAEROComputeGeometry", "VSPAEROSweep"):
            openvsp.SetAnalysisInputDefaults(analysis)
            result_id = openvsp.ExecAnalysis(analysis)
            check(bool(result_id), f"{analysis} returned a result id ({result_id!r})")

        produced = sorted(
            name
            for name in os.listdir(".")
            if name.endswith((".vspgeom", ".vspaero", ".polar"))
        )
        check(bool(produced), f"VSPAERO wrote result files: {produced}")
    finally:
        os.chdir(old_cwd)

if failures:
    print(f"\n{len(failures)} check(s) failed", file=sys.stderr)
    sys.exit(1)

print("\nAll OpenVSP Python tool checks passed")