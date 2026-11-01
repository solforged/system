# Herdr's native theme format. Reuse the pinned palette for UI roles and the
# Ghostty export for terminal colors (including its contrast-tuned ANSI greys).
{ lib, theme }:
variant:
let
  palette = builtins.fromTOML (
    builtins.readFile "${theme}/omarchy-solforge-${variant}-theme/colors.toml"
  );
  terminal = lib.listToAttrs (
    lib.concatMap (
      line:
      let
        ansi = builtins.match "palette = ([0-9]+)=(#[0-9a-fA-F]{6})" line;
        color = builtins.match "([a-z-]+) = (#[0-9a-fA-F]{6})" line;
      in
      if ansi != null then
        [ (lib.nameValuePair "ansi${builtins.head ansi}" (builtins.elemAt ansi 1)) ]
      else if color != null then
        [ (lib.nameValuePair (builtins.head color) (builtins.elemAt color 1)) ]
      else
        [ ]
    ) (lib.splitString "\n" (builtins.readFile "${theme}/ghostty/solforge-${variant}"))
  );
in
{
  inherit (terminal) background foreground;
  selection = terminal."selection-background";
  cursor = terminal."cursor-color";
  ansi = builtins.genList (index: terminal."ansi${toString index}") 16;

  # Override Herdr's derived neutral chrome and blue accent, not its layout.
  colors = {
    foreground = palette.foreground;
    surface = palette.background;
    canvas = palette.darker_background;
    chrome = palette.dark_background;
    popover = palette.background;
    raised = palette.lighter_background;
    hover = palette.lighter_background;
    selected = palette.selection;
    border = terminal."split-divider-color";
    input = palette.muted;
    muted = palette.light_foreground;
    dim = palette.muted;
    accent = palette.accent;
    accent_foreground = palette.background;
    solid = palette.accent;
    solid_foreground = palette.background;
    ring = palette.accent;
    working = palette.yellow;
    blocked = palette.red;
    done = palette.green;
    idle = palette.muted;
    unknown = palette.muted;
  };
}
