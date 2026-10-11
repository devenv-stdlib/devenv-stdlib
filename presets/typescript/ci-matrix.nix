# when inherits typescript category policy (languages.typescript.enable or override).
_: {
  path = [
    "typescript"
    "ci-matrix"
  ];
  description = "Include TypeScript in the generated test.yml matrix.";
  project.stdlib.lang.typescript.ciMatrix = true;
}
