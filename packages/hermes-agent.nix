# Keep the CLI and every frontend on the same pnpm store. Upstream's current
# pnpm-deps-hash does not match the aarch64-darwin fetch; leave other platforms
# and future upstream hashes alone.
{
  stdenv,
  hermes,
}:
let
  system = stdenv.hostPlatform.system;
  upstreamPkgs = import hermes.inputs.nixpkgs { inherit system; };
  agent = hermes.packages.${system}.default;
in
if stdenv.hostPlatform.isDarwin then
  agent.override {
    callPackage = upstreamPkgs.newScope {
      fetchPnpmDeps =
        args:
        upstreamPkgs.fetchPnpmDeps (
          args
          // {
            hash =
              if args.hash == "sha256-Ez5DyfFuou8SWXaCZFnY+5mpdQ1bBM9jd7ukna4S3ss=" then
                "sha256-0DFhYHo5HDps1hz6Haqv3cQfA1ug10LL/ohxKZGSDlw="
              else
                args.hash;
          }
        );
    };
  }
else
  agent
