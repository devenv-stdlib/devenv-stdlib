# stdlib.generate copy-if-changed helper.
{
  lib,
  ...
}:
let
  generate = import ../../../stdlib/generate.nix { inherit lib; };
  exec = generate.mkSyncFileExec {
    storePath = "/nix/store/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-example.yml";
    relPath = ".github/workflows/test.yml";
  };
  contains = needle: haystack: lib.hasInfix needle haystack;
in
{
  testGenerateSyncFileExecHonorsDryRun = {
    expr = {
      hasDryRunFlag = contains "--dry-run" exec;
      hasCmp = contains "cmp -s" exec;
      hasDest = contains ".github/workflows/test.yml" exec;
      writesOnlyWhenNotDry = contains "wrote .github/workflows/test.yml" exec;
      dryRunExitsOne = contains "stale: .github/workflows/test.yml" exec;
      envOverride = contains "DEVENV_STDLIB_DRY_RUN" exec;
    };
    expected = {
      hasDryRunFlag = true;
      hasCmp = true;
      hasDest = true;
      writesOnlyWhenNotDry = true;
      dryRunExitsOne = true;
      envOverride = true;
    };
  };

  testGenerateEnsureTrailingNewline = {
    expr = {
      adds = generate.ensureTrailingNewline "{}" == "{}\n";
      keeps = generate.ensureTrailingNewline "{}\n" == "{}\n";
      empty = generate.ensureTrailingNewline "" == "";
    };
    expected = {
      adds = true;
      keeps = true;
      empty = true;
    };
  };

  testGenerateEnsureNewlineExecHonorsDryRun = {
    expr =
      let
        nl = generate.mkEnsureTrailingNewlineExec { relPath = "devenv.lock"; };
      in
      {
        hasDryRunFlag = contains "--dry-run" nl;
        hasDest = contains "devenv.lock" nl;
        dryRunExitsOne = contains "stale: devenv.lock" nl;
        appendsNewline = lib.hasInfix "printf '\\n'" nl;
      };
    expected = {
      hasDryRunFlag = true;
      hasDest = true;
      dryRunExitsOne = true;
      appendsNewline = true;
    };
  };
}
