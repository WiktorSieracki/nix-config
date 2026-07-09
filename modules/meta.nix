{
  flake.meta = {
    programs = {
      editor = "code";
      terminal = "ghostty";
      browser = "firefox";
      chromium-browser = "brave";
      fileManager = "nautilus";
    };

    # Tożsamości kont (ADR 0004). Konto istnieje na hoście ⇔ jego login jest
    # kluczem sekcji `users` w features.json tego hosta; tworzy je loader
    # (hosts/configurations.nix), czytając stąd dane. Feature'y użytkownika
    # dostają ten attrset wstrzyknięty jako `userMeta` (+ `login`) do swojej
    # ewaluacji home-managera i nie hardkodują żadnego loginu.
    #
    # Pola: fullName (git user.name, GECOS), groups, shell (nazwa pakietu),
    # emailSecret / passwordSecret (nazwy sekretów w secrets.yaml; hasło jako
    # hash z `mkpasswd -m sha-512`), authorizedKeys (klucze publiczne sshd).
    users = {
      wiktor = {
        fullName = "Wiktor Sieracki";
        groups = ["networkmanager" "wheel"];
        shell = "fish";
        emailSecret = "studentEmail";
        authorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPDwctBSDTMy2mf8LC0WKXnEbYl5mlBLGmtmEJNBpNXR"
        ];
      };

      # Konto pracowe: separacja danych i tożsamości od `wiktor` (bez wheel,
      # homeMode 700 z NixOS-owego defaultu). Zarządzane przez wiktora.
      work = {
        fullName = "Wiktor Sieracki";
        groups = [];
        shell = "fish";
        emailSecret = "workEmail";
        passwordSecret = "workPasswordHash";
      };
    };
  };
}
