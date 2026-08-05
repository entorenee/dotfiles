{...}: {
  # Persona-specific agents are declared in users/<persona>/darwin.nix;
  # `launchd.user.agents` is an attrset of submodules, so they merge with this.
  launchd.user.agents.elgatoControlCenter = {
    serviceConfig = {
      Label = "ElgatoControlCenter";
      ProgramArguments = ["/Applications/Elgato Control Center.app/Contents/MacOS/Elgato Control Center"];
      RunAtLoad = true;
      KeepAlive = false;
    };
  };
}
