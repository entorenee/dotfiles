{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.firefox = {
    enable = true;

    # Darwin gets Firefox from the Homebrew cask, so null means config-only.
    # Policies still apply there through
    # `targets.darwin.defaults."org.mozilla.firefox.plist"`
    # (EnterprisePoliciesEnabled), which Firefox honors however it was
    # installed. Linux keeps the package so policies.json is baked into the
    # wrapper.
    package = lib.mkIf pkgs.stdenv.isDarwin null;

    policies = {
      DnsOverHttps = {
        Enabled = true;
        Provider = "cloudflare";
        Url = "https://mozilla.cloudflare-dns.com/dns-query";
      };

      SanitizeOnShutdown = {
        Cookies = true;
        Cache = true;
        FormData = true;
        Sessions = true; # TODO: Explore allowlist of sites to not clear sessions on.
      };

      DisableTelemetry = true;
      DisableDataReporting = true;

      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
        SuspectedFingerprinting = true;
        EmailTracking = true;
      };

      HttpsOnlyMode = {
        Enabled = true;
        EnableForAllSites = true;
      };

      GenerativeAI.Enabled = false;
      PasswordManagerEnabled = false;

      Homepage = {
        StartPage = "previous-session";
        URL = "about:blank";
      };
      NewTabPage = false;

      Preferences = {
        #  WebRTC: keep peer connections enabled so web calls work, but limit
        #  ICE to the default route address and obfuscate host candidates behind
        #  mDNS so sites can't enumerate local network IPs.
        "media.peerconnection.enabled" = true;
        "media.peerconnection.ice.default_address_only" = true;
        "media.peerconnection.ice.obfuscate_host_addresses" = true;

        #  Block third‑party cookies (0=allow all, 1=block third‑party, 2=block all)
        "network.cookie.cookieBehavior" = 1;

        #  Disable pre‑fetching
        "network.prefetch-next" = false;
        "network.http.speculative-parallel-limit" = 0;
        "network.dns.disablePrefetch" = true;
        "network.dns.disablePrefetchFromHTTPS" = true;

        # Misc privacy‑related tweaks
        "signon.rememberSignons" = false; # no built‑in password manager
        "browser.formfill.enable" = false; # no form autofill
        "browser.sessionstore.restore_on_demand" = true;
        "browser.startup.homepage_override.mstone" = "ignore";

        "network.dns.disableIPv6" = false;
      };

      SearchEngines = {
        Add = [
          {
            Name = "SearXNG";
            Alias = "@s";
            URLTemplate = "https://searxng.culturegremlin.club/search?q={searchTerms}";
          }
          {
            Name = "Nix Packages";
            Alias = "@np";
            URLTemplate = "https://search.nixos.org/packages?query={searchTerms}";
          }
          {
            Name = "Nix Home Manager";
            Alias = "@nh";
            URLTemplate = "https://home-manager-options.extranix.com/?query={searchTerms}";
          }
          {
            Name = "GitHub";
            Alias = "@gh";
            URLTemplate = "https://github.com/search?q={searchTerms}";
          }
        ];
        Default = "SearXNG";
        Remove = [
          "Bing"
          "eBay"
          "Google"
          "Amazon.com"
        ];
      };
      SearchSuggestEnabled = false;

      Extensions.Install =
        [
          "https://addons.mozilla.org/firefox/downloads/latest/react-devtools/latest.xpi"
          "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"
        ]
        # The browser extension is only useful alongside the native KeePassXC it
        # talks to, so it follows that module rather than an identity role.
        ++ lib.optional config.programs.keepassxc.enable "https://addons.mozilla.org/firefox/downloads/latest/keepassxc-browser/latest.xpi";
    };
  };
}
