# lib/modules.nix
#
# Directory walkers, after hlissner's lib/modules.nix. Files and directories
# whose names start with "_" are skipped.
{ lib, ... }:

let
  inherit (builtins) attrValues pathExists readDir;
  inherit (lib)
    attrNames
    concatMap
    concatMapAttrs
    filter
    hasPrefix
    hasSuffix
    id
    removeSuffix
    ;

  # A plain .nix file other than a directory's own default.nix.
  isModuleFile = name: type: type == "regular" && name != "default.nix" && hasSuffix ".nix" name;
in
rec {
  # mapModules :: path -> (path -> a) -> { name = a; }
  #
  # Maps every module directly under DIR through FN. A directory counts as a
  # module only when it holds a default.nix.
  mapModules =
    dir: fn:
    concatMapAttrs (
      name: type:
      let
        path = dir + "/${name}";
      in
      if hasPrefix "_" name then
        { }
      else if type == "directory" then
        (if pathExists (path + "/default.nix") then { ${name} = fn path; } else { })
      else if isModuleFile name type then
        { ${removeSuffix ".nix" name} = fn path; }
      else
        { }
    ) (readDir dir);

  # modulePaths :: path -> [ path ]
  #
  # Every module under DIR, recursively, not counting DIR's own default.nix.
  modulePaths =
    dir:
    let
      entries = readDir dir;
      subdirs = filter (name: entries.${name} == "directory" && !(hasPrefix "_" name)) (
        attrNames entries
      );
    in
    attrValues (mapModules dir id) ++ concatMap (name: modulePaths (dir + "/${name}")) subdirs;
}
