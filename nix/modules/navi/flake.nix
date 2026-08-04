# Example flake for bundling navi cheatsheets with native directory structure
# This would typically be a separate repository/gist that you reference as a flake input
{
  description = "Navi cheatsheets bundle with native directory structure";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    forAllSystems = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
  in {
    packages = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};

      # Define cheatsheet repositories you want to include
      cheatsheetRepos = [
        {
          owner = "denisidoro";
          repo = "cheats";
          rev = "master";
          sha256 = "sha256-wPsAazAGKPhu0MZfZbZ0POUBEMg95frClAQERTDFXUg="; # Replace with actual hash
        }
      ];

      # Create individual repository derivations
      fetchRepo = {
        owner,
        repo,
        rev,
        sha256,
      }:
        pkgs.fetchFromGitHub {
          inherit owner repo rev sha256;
        };

      # Bundle all repositories with navi's native directory structure
      naviCheatsheets = pkgs.runCommand "navi-cheatsheets" {} ''
        mkdir -p $out
        ${pkgs.lib.concatMapStrings (
            repoSpec: let
              src = fetchRepo repoSpec;
              dirName = "${repoSpec.owner}__${repoSpec.repo}";
            in ''
              echo "Adding ${dirName}..."
              cp -r "${src}" "$out/${dirName}"
              chmod -R u+w "$out/${dirName}"
            ''
          )
          cheatsheetRepos}

        echo "Created navi cheatsheets with native directory structure:"
        ls -la $out/
      '';
    in {
      default = naviCheatsheets;
    });
  };
}
