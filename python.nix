{
  lib,
  buildPythonPackage,
  python,
  numpy,
  matplotlib,
  openvsp,
}:

buildPythonPackage {
  pname = "openvsp-python";
  version = openvsp.version;

  # The Python bindings are shipped prebuilt in the Ubuntu package. There is
  # nothing for setuptools to configure or compile.
  format = "other";
  dontConfigure = true;
  dontBuild = true;
  dontUnpack = true;

  # Keep the upstream package directory intact instead of flattening it:
  # `openvsp/__init__.py` finds VSPAERO, VSPViewer, and VSPLoads relative to
  # its own __file__. Linking the whole directory preserves both the compiled
  # extensions and those executables (and the help pages).
  installPhase = ''
    runHook preInstall

    site="$out/${python.sitePackages}"
    mkdir -p "$site"

    ln -s "${openvsp}/lib/openvsp/python/openvsp/openvsp" "$site/openvsp"
    ln -s "${openvsp}/lib/openvsp/python/openvsp_config/openvsp_config" "$site/openvsp_config"
    ln -s "${openvsp}/lib/openvsp/python/degen_geom/degen_geom" "$site/degen_geom"
    ln -s "${openvsp}/lib/openvsp/python/utilities/utilities" "$site/utilities"
    ln -s "${openvsp}/lib/openvsp/python/vsp_airfoils/vsp_airfoils" "$site/vsp_airfoils"

    runHook postInstall
  '';

  # numpy is loaded by the _vsp extension itself; matplotlib is needed by the
  # bundled vsp_airfoils helpers used by `export_airfoils`.
  propagatedBuildInputs = [
    numpy
    matplotlib
  ];

  pythonImportsCheck = [ "openvsp" ];

  meta = with lib; {
    description = "Python bindings for OpenVSP";
    homepage = "https://openvsp.org";
    license = licenses.nasa13;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}
