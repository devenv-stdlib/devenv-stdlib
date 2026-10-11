# when inherits javascript category policy (languages.javascript.enable or override).
_: {
  path = [
    "javascript"
    "debtmap"
  ];
  description = "debtmap javascript language id when JavaScript is available.";
  project.stdlib.lang.javascript.debtmap = [ "javascript" ];
}
