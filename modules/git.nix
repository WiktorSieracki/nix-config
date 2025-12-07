{
  inputs,
  pkgs,
  ...
}: {
  programs.git = {
    enable = true;

    settings.user = {
      email = "w.sieracki.643@studms.ug.edu.pl";
      name = "Wiktor Sieracki";
    };
  };
}
