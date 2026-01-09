{pkgs, ...}: let
  nusmv = pkgs.stdenv.mkDerivation rec {
    pname = "nusmv";
    version = "2.7.1";

    src = pkgs.fetchurl {
      url = "https://nusmv.fbk.eu/distrib/${version}/NuSMV-${version}-linux64.tar.xz";
      sha256 = "0g4824nxycbr049yir80jwmy025nlvii4dfwshl3ys4p14gwfkc9";
    };

    nativeBuildInputs = with pkgs; [xz];

    phases = ["unpackPhase" "installPhase"];

    installPhase = ''
      mkdir -p $out/bin
      cp -r bin/* $out/bin/
      cp -r lib $out/ || true
      mkdir -p $out/share
      cp -r share/* $out/share/ || true
    '';

    meta = with pkgs.lib; {
      description = "NuSMV: a symbolic model checker";
      homepage = "https://nusmv.fbk.eu/";
      license = licenses.lgpl21;
      platforms = ["x86_64-linux"];
      maintainers = [];
    };
  };
in {
  home.packages = [nusmv];
}
