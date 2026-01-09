{
  config,
  pkgs,
  ...
}: let
  alloy = pkgs.stdenv.mkDerivation rec {
    pname = "alloy";
    version = "6.2.0";

    src = pkgs.fetchurl {
      url = "https://github.com/AlloyTools/org.alloytools.alloy/releases/download/v${version}/org.alloytools.alloy.dist.jar";
      sha256 = "13dpxl0ri6ldcaaa60n75lj8ls3fmghw8d8lqv3xzglkpjsir33b";
    };

    nativeBuildInputs = [pkgs.makeWrapper];
    buildInputs = [pkgs.jre];

    dontUnpack = true;

    installPhase = ''
      mkdir -p $out/share/java $out/bin
      cp $src $out/share/java/alloy.jar

      makeWrapper ${pkgs.jre}/bin/java $out/bin/alloy \
        --add-flags "-jar $out/share/java/alloy.jar"
    '';

    meta = with pkgs.lib; {
      description = "Alloy Analyzer - a tool for software modeling and verification";
      homepage = "https://github.com/AlloyTools/org.alloytools.alloy";
      license = licenses.mit;
      platforms = platforms.unix;
      maintainers = [];
    };
  };
in {
  home.packages = [alloy];
}
