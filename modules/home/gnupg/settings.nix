# gpg.conf hardening, as plain data rather than a module: ./default.nix hands it
# to home-manager's `programs.gpg.settings`, and hosts/nixos/airgap renders it
# itself. Keep it data-only — no `pkgs`, no `lib`, no module arguments — since
# both call sites `import` it bare.
#
# Keep both on this file rather than letting airgap carry its own copy: airgap
# is where keys are generated, so a weaker s2k or digest there outlives every
# machine that later uses the key.
{
  armor = true;
  cert-digest-algo = "SHA512";
  charset = "utf-8";
  default-preference-list = "SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed";
  keyid-format = "0xlong";
  list-options = "show-uid-validity";
  no-comments = true;
  no-emit-version = true;
  no-greeting = true;
  no-symkey-cache = true;
  personal-cipher-preferences = "AES256 AES192 AES";
  personal-compress-preferences = "ZLIB BZIP2 ZIP Uncompressed";
  personal-digest-preferences = "SHA512 SHA384 SHA256";
  require-cross-certification = true;
  require-secmem = true;
  s2k-cipher-algo = "AES256";
  s2k-digest-algo = "SHA512";
  throw-keyids = true;
  use-agent = true;
  verify-options = "show-uid-validity";
  with-fingerprint = true;
}
