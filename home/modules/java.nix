{pkgs, ...}: {
  home.packages = with pkgs; [
    zulu25
    gradle_9
  ];

  home.sessionVariables = {
    JAVA_HOME = "${pkgs.zulu25}";
  };
}
# Look for JDK in /nix/store e.g. /nix/store/18gajbv2vyygbd5dg8znw6gwrgb3ncsi-zulu-ca-jdk-23.0.0
# readlink -f $(which java)
# Open idea in WSL
# idea64.exe .

