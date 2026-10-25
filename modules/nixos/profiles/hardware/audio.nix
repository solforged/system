# modules/nixos/profiles/hardware/audio.nix
{ config, lib, ... }:

{
  config = lib.mkIf (lib.elem "audio" config.modules.profiles.hardware) {
    security.rtkit.enable = true;
    services.pulseaudio.enable = false;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };
}
