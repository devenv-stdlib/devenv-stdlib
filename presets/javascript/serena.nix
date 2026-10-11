# JS and TS share the Serena typescript server (lib.unique in the loader).
# Uses javascript-or-typescript category policy.
_: {
  path = [
    "javascript"
    "serena"
  ];
  description = "Serena typescript language server when JS or TS is available.";
  categoryPolicy = "javascript-or-typescript";
  project.stdlib.lang.javascript.serena = [ "typescript" ];
}
