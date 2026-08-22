{
  # desktopNixos's physical monitor layout, contributed to the shared niri
  # config via flake.niriOutputs. Host data stays in the host folder: the niri
  # feature itself knows no machine. The single niri config is shared by every
  # host, which is safe because niri matches outputs by connector name — on any
  # machine without these monitors the entries are inert.
  flake.niriOutputs = {
    "HP Inc. HP E243 CNC0171FR8" = {
      mode = "1920x1080@60.000";
      position = _: {
        props = {
          x = 0;
          y = 0;
        };
      };
    };
    "Ancor Communications Inc ASUS VX239 G6LMTJ040329" = {
      mode = "1920x1080@60.000";
      position = _: {
        props = {
          x = 1920;
          y = 0;
        };
      };
    };
  };
}
