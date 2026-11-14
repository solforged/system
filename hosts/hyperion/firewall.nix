# First phase: enable filtering without changing working remote-access rules.
{ ... }:

{
  networking.applicationFirewall = {
    enable = true;
    blockAllIncoming = false; # Keep AirPlay Receiver and remote access available.
    allowSigned = true; # Preserve built-in Apple services, including AirPlay.
    # Tighten only after live exceptions for Rex Server and Tailscale are proven.
    allowSignedApp = true;
    enableStealthMode = false; # Preserve the current discovery behavior.
  };
}
