# when inherits typescript category policy (languages.typescript.enable or override).
_: {
  path = [
    "typescript"
    "debtmap"
  ];
  description = "debtmap typescript language id when TypeScript is available.";
  project.stdlib.lang.typescript.debtmap = [ "typescript" ];
}
