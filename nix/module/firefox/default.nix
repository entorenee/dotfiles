{...}: {
  programs.firefox = {
    enable = true;
    policies = {
      #  DNS‑over‑HTTPS (Cloudflare – change the URL if you prefer another resolver)
      DnsOverHttps = {
        Enabled = true;
        Provider = "cloudflare";
        Url = "https://mozilla.cloudflare-dns.com/dns-query";
      };

      #  Delete cookies & site data on shutdown
      SanitizeOnShutdown = {
        Cookies = true;
        Cache = true;
        FormData = true;
        Sessions = true; # TODO: Explore allowlist of sites to not clear sessions on.
      };

      #  Turn off telemetry / data collection
      DisableTelemetry = true;
      DisableDataReporting = true;

      # Fingerprinting resistance
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
        SuspectedFingerprinting = true;
        EmailTracking = true;
      };

      #  HTTPS‑Only mode
      HttpsOnlyMode = {
        Enabled = true;
        EnableForAllSites = true;
      };

      # Disable Generative AI
      GenerativeAI.Enabled = false;

      # Disable browser password manager
      PasswordManagerEnabled = false;

      Homepage = {
        StartPage = "previous-session";
        URL = "about:blank";
      };
      NewTabPage = false;

      Preferences = {
        #  Block WebRTC IP leakage
        "media.peerconnection.enabled" = false;

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

        # Optional: disable speculative DNS (extra safety)
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
        ];
        Default = "SearXNG";
        Remove = [
          "Google"
          "Amazon.com"
        ];
      };
      SearchSuggestEnabled = false;

      Extensions.Install = [
        "https://addons.mozilla.org/firefox/downloads/latest/react-devtools/latest.xpi"
        "https://addons.mozilla.org/firefox/downloads/latest/keepassxc-browser/latest.xpi"
        "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"
      ];
    };
  };
}
