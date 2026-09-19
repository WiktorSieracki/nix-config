{
  # Where the live sandbox VM shows up on this machine. Host data, not feature
  # data: the connector name below only exists here, and the laptop has no
  # second monitor to park anything on — on any other machine both entries are
  # inert, which is the same property that lets monitors.nix be shared.
  #
  # The point is that the agent's VM never steals the screen you are working on:
  # it opens on the right monitor, unfocused, and you watch it click itself.
  flake.niriWorkspaces.sandbox = _: {
    content = {
      open-on-output = "Ancor Communications Inc ASUS VX239 G6LMTJ040329";
    };
  };

  # `-name nix-sandbox` (and the matching SDL_VIDEO_WAYLAND_WMCLASS) in the
  # sandbox runner is what makes this window identifiable — matching on "qemu"
  # would also catch any other VM you happen to be running.
  flake.niriWindowRules.sandbox = _: {
    matches = [
      {app-id = "^nix-sandbox$";}
      {title = "^nix-sandbox";}
    ];
    open-on-workspace = "sandbox";
    open-focused = false;
  };
}
