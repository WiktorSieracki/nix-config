{...}: {
  programs.nixvim = {
    enable = true;

    colorschemes.gruvbox.enable = true;

    # Basic vim settings
    opts = {
      number = true;
      relativenumber = true;
    };

    # Plugins
    plugins = {
      lsp = {
        enable = true;
        servers = {
          # Add LSP servers as needed
          # Example: nixd.enable = true;
          # typescript-language-server.enable = true;
        };
      };
    };
  };
}
