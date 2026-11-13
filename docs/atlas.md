# atlas

atlas is the work Mac. This repo gives it the shared tools, editors and the
work-safe agents (Pi and omp, with the shared policy, commands and skills). It
signs commits with its own key but cannot log in to personal hosts.

Work-only configuration stays out of this public repo. A private work flake
takes this flake as an input and builds atlas with `lib.mkHost`, adding its own
modules on top:

```nix
darwinConfigurations.atlas = system.lib.mkHost {
  name = "atlas";
  host = import "${system}/hosts/atlas" {
    inherit (system.inputs.nixpkgs) lib;
    inherit (system) inputs;
  };
  extraModules = [ ./work.nix ];
};
```

Point `NH_FLAKE` at the work flake on atlas, for example with
`programs.nh.flake` in `work.nix`. The work modules own:

- `GH_HOST` and other Enterprise GitHub settings, through
  `modules.env.variables` so launchd apps see them too;
- the work Git identity, if it differs from `secrets/git-work-identity.age`;
- the memory wiki's work bundle, linked from the work repository into
  `~/.local/share/wiki/work`. The `work` scope is set here already
  (`modules.agents.wiki.scope`);
- work-only agent commands, skills and project secrets.
