{inputs, ...}: {
  # import the home manager module
  imports = [
    inputs.noctalia.homeModules.default
  ];

  # enable the systemd service
  programs.noctalia-shell.systemd.enable = true;

  # configure options
  programs.noctalia-shell = {
    enable = true;
    settings = {
      # configure noctalia here
      bar = {
        density = "compact";
        position = "top";
        showCapsule = false;
        widgets = {
          left = [
            {
              id = "ControlCenter";
              useDistroLogo = true;
            }
            {
              id = "Network";
            }
            {
              id = "Bluetooth";
            }
          ];
          center = [
            {
              hideUnoccupied = false;
              id = "Workspace";
              labelMode = "none";
            }
          ];
          right = [
            {
              alwaysShowPercentage = false;
              id = "Battery";
              warningThreshold = 30;
            }
            {
              formatHorizontal = "HH:mm:ss";
              formatVertical = "HH mm";
              id = "Clock";
              useMonospacedFont = true;
              usePrimaryColor = true;
            }
          ];
        };
      };
      colorSchemes.predefinedScheme = "Monochrome";
      # general = {
      #   avatarImage = "/home/drfoobar/.face";
      #   radiusRatio = 0.2;
      # };
      location = {
        monthBeforeDay = true;
        name = "Gdańsk, Poland";
      };
    };
    # this may also be a string or a path to a JSON file.
  };
}
