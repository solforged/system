# Check that the user's font directory is prepared before agenix and Home Manager.
{ configuration }:
let
  inherit (configuration) pkgs;
  inherit (pkgs) lib;
  inherit (configuration) config;
  user = config.user.name;
  fontsDir = "${config.users.users.${user}.home}/Library/Fonts";
  prepare = "install -d -m 0755 -o ${lib.escapeShellArg user} -g staff ${lib.escapeShellArg fontsDir}";
  activation = config.system.activationScripts.script.text;
  beforeServices = builtins.head (
    lib.splitString (builtins.unsafeDiscardStringContext config.system.activationScripts.launchd.text) activation
  );
  beforeHomeManager = builtins.head (
    lib.splitString (builtins.unsafeDiscardStringContext config.system.activationScripts.postActivation.text) activation
  );
  disabled =
    (configuration.extendModules {
      modules = [ { modules.fonts.berkeley.enable = lib.mkForce false; } ];
    }).config;
in
assert config.age.secrets.berkeley-mono.path == "${fontsDir}/Berkeley Mono Variable.otf";
assert lib.hasInfix prepare config.system.activationScripts.preActivation.text;
assert lib.hasInfix prepare beforeServices;
assert lib.hasInfix prepare beforeHomeManager;
assert !(lib.hasInfix prepare disabled.system.activationScripts.preActivation.text);
pkgs.runCommand "berkeley-fonts-check" { } ''
  ${pkgs.stdenv.shell} -n ${pkgs.writeText "berkeley-fonts-activation.sh" activation}
  touch "$out"
''
