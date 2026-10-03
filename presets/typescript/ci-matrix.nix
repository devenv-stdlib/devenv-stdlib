{ ... }:
{
  path = [
    "typescript"
    "ci-matrix"
  ];
  description = "Include TypeScript in the generated test.yml matrix.";
  when = cfg: (cfg.languages.typescript or { }).enable or false;
  project.stdlib.lang.typescript.ciMatrix = true;
}
