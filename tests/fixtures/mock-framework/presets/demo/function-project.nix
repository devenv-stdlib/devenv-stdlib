# Function project payload: applyPreset must pass the module `options` argument.
_: {
  path = [
    "demo"
    "function-project"
  ];
  description = "Mock preset whose project payload is a module function.";
  categoryPolicy = false;
  when = _: true;
  project =
    { options, ... }:
    {
      stdlib.markers.functionProjectSawName = options ? name;
    };
}
