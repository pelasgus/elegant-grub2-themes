# flake.nix
# Author: D.A.Pelasgus

{ description = "Flake to manage grub2 themes for Elegant Themes"; 
  inputs = { nixpkgs.url = "github:NixOS/nixpkgs/master"; }; 
  outputs = { self, nixpkgs }: let 
    system = "x86_64-linux"; 
    pkgs = import nixpkgs { inherit system; }; 
  in with nixpkgs.lib; rec { 
    nixosModules.default = { config, ... }: let 
      cfg = config.boot.loader.grub2-theme; 
      splashImage = if cfg.splashImage == null then "" else cfg.splashImage; 
      hasBootMenuConfig = cfg.bootMenuConfig != null; 
      hasTerminalConfig = cfg.terminalConfig != null; 
      
      resolutions = { 
        "1080p" = "1920x1080"; 
        "2k" = "2560x1440"; 
        "4k" = "3840x2160"; 
      }; 
      
      grub2-theme = pkgs.stdenv.mkDerivation { 
        name = "grub2-theme"; 
        src = "${self}"; 
        buildInputs = [ pkgs.imagemagick ]; 
        installPhase = ''
          mkdir -p $out/grub/themes # Create placeholder terminal box PNGs that install.sh expects
          mkdir -p common 
          for box in c e n ne nw s se sw w; do 
            touch common/terminal_box_$box.png 
          done 
          
          # Run the install script with Elegant Theme options
          bash ./install.sh \ 
          -t ${cfg.theme} \ 
          -p ${cfg.type} \ 
          -i ${cfg.side} \ 
          -c ${cfg.color} \ 
          -s ${cfg.screen} \ 
          ${if cfg.logo != null then "-l ${cfg.logo}" else ""} 
          ${if cfg.remove then "-r" else ""} 
          -b 
          
          if [ -n "${splashImage}" ]; then 
            rm $out/grub/themes/${cfg.theme}/background.jpg; 
            ${pkgs.imagemagick}/bin/magick ${splashImage} $out/grub/themes/${cfg.theme}/background.jpg; 
          fi; 
          
          if [ ${pkgs.lib.trivial.boolToString cfg.footer} == "false" ]; then 
            sed -i ':again;$!N;$!b again; s/\+ image {[^}]*}//g' $out/grub/themes/${cfg.theme}/theme.txt; 
          fi; 
          
          if [ ${pkgs.lib.trivial.boolToString hasBootMenuConfig} == "true" ]; then 
            sed -i ':again;$!N;$!b again; s/\+ boot_menu {[^}]*}//g' $out/grub/themes/${cfg.theme}/theme.txt; 
            cat << EOF >> $out/grub/themes/${cfg.theme}/theme.txt 
            + boot_menu { ${if cfg.bootMenuConfig == null then "" else cfg.bootMenuConfig} } 
            EOF 
          fi; 
          
          if [ ${pkgs.lib.trivial.boolToString hasTerminalConfig} == "true" ]; then 
            sed -i 's/^terminal-.*$//g' $out/grub/themes/${cfg.theme}/theme.txt 
            cat << EOF >> $out/grub/themes/${cfg.theme}/theme.txt 
            ${if cfg.terminalConfig == null then "" else cfg.terminalConfig} 
            EOF 
          fi; 
        ''; 
      }; 
      
      resolution = if cfg.customResolution != null then cfg.customResolution else resolutions."${cfg.screen}"; 
    in rec { 
      options = { 
        boot.loader.grub2-theme = { 
          enable = mkOption { default = true; example = true; type = types.bool; description = "Enable grub2 theming for Elegant Themes"; }; 
          theme = mkOption { default = "forest"; example = "forest"; type = types.enum [ "forest" "mojave" "mountain" "wave" ]; description = "Background theme variant to use for grub2."; }; 
          type = mkOption { default = "window"; example = "window"; type = types.enum [ "window" "float" "sharp" "blur" ]; description = "Theme style variant."; }; 
          side = mkOption { default = "left"; example = "left"; type = types.enum [ "left" "right" ]; description = "Picture display side."; }; 
          color = mkOption { default = "dark"; example = "dark"; type = types.enum [ "dark" "light" ]; description = "Background color variant."; }; 
          screen = mkOption { default = "1080p"; example = "1080p"; type = types.enum [ "1080p" "2k" "4k" ]; description = "Screen display variant."; }; 
          logo = mkOption { default = "mountain"; example = "mountain"; type = types.enum [ "mountain" "system" ]; description = "Logo to display on the picture."; }; 
          remove = mkOption { default = false; example = false; type = types.bool; description = "Whether to remove/uninstall the theme."; }; 
          splashImage = mkOption { default = null; example = "/my/path/background.jpg"; type = types.nullOr types.path; description = "The path of the image to use for background (must be jpg or png)."; }; 
          bootMenuConfig = mkOption { default = null; example = "left = 30%"; type = types.nullOr types.str; description = "Grub theme definition for boot_menu."; }; 
          terminalConfig = mkOption { default = null; example = "terminal-font: \"Terminus Regular 18\""; type = types.nullOr types.str; description = "Grub theme definition for terminal."; }; 
          footer = mkOption { default = true; example = true; type = types.bool; description = "Whether to include the image footer."; }; 
        }; 
      }; 
      
      config = mkIf cfg.enable (mkMerge [{ 
        environment.systemPackages = [ grub2-theme ]; 
        boot.loader.grub = { 
          theme = "${grub2-theme}/grub/themes/${cfg.theme}"; 
          splashImage = "${grub2-theme}/grub/themes/${cfg.theme}/background.jpg"; 
          gfxmodeEfi = "${resolution},auto"; 
          gfxmodeBios = "${resolution},auto"; 
          extraConfig = '' 
            insmod gfxterm 
            insmod png 
            set icondir=($root)/theme/icons 
          ''; 
        }; 
      }]); 
    }; 
  }; 
}

