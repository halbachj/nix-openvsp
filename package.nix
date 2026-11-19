{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  libGL,
  libGLU,
  libX11,
  glew,
  # OpenVSP links against the libxml2.so.2 SONAME; libxml2 2.15 in nixpkgs
  # bumped it to .16, so use the still-packaged 2.13 branch.
  libxml2_13,
  cminpack,
  python312,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "openvsp";
  version = "3.56.0";

  # OpenVSP publishes prebuilt Ubuntu packages; no Linux package exists in
  # nixpkgs and the source build pulls a large set of bundled dependencies.
  src = fetchurl {
    url = "https://openvsp.org/zips/current/linux/OpenVSP-${finalAttrs.version}-Ubuntu-24.04_amd64.deb";
    hash = "sha256-ntkz/CD+MFstVDgj/TCm4ds2KM4ZyG1pFf0NXLo6J0Q=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    libGL
    libGLU
    libX11
    glew
    libxml2_13
    cminpack
    python312
    stdenv.cc.cc.lib
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src .
    runHook postUnpack
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # OpenVSP locates help, airfoil and script data relative to the real path
    # of the running executable, so keep the upstream layout intact.
    mkdir -p $out/lib/openvsp $out/bin
    cp -r opt/OpenVSP/. $out/lib/openvsp/

    for exe in vsp vspscript vspviewer vspaero vspaero_opt vsploads; do
      makeWrapper $out/lib/openvsp/$exe $out/bin/$exe
    done

    install -Dm644 $out/lib/openvsp/vspIcon.png $out/share/pixmaps/openvsp.png

    runHook postInstall
  '';

  meta = with lib; {
    description = "Parametric aircraft geometry tool";
    longDescription = ''
      OpenVSP (Vehicle Sketch Pad) lets users create 3D aircraft models from
      engineering parameters and export them for analysis.
    '';
    homepage = "https://openvsp.org";
    license = licenses.nasa13;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
    mainProgram = "vsp";
  };
})
