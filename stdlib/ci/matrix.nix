# Provider-agnostic CI matrix IR (MatrixPlan).
# Dimensions → cartesian / explicit allow → exclude → include → cells.
{ lib }:
let
  # Default host profiles: current Ubuntu LTS + previous (matches versions-lib.ubuntuLts).
  defaultRunnerProfiles = {
    ubuntu-lts-prev = {
      os = "linux";
      distro = "ubuntu";
      release = "24.04";
      arch = "x86_64";
      providers = {
        github_actions = {
          runs-on = [ "ubuntu-24.04" ];
        };
      };
    };
    ubuntu-lts-curr = {
      os = "linux";
      distro = "ubuntu";
      release = "26.04";
      arch = "x86_64";
      providers = {
        github_actions = {
          runs-on = [ "ubuntu-26.04" ];
        };
      };
    };
  };

  defaultStrategy = {
    failFast = false;
    maxParallel = null;
    maxCells = null;
  };

  # Partial match: every key in pattern equals the same key on cell.
  matchesPartial =
    pattern: cell:
    lib.all (name: (builtins.hasAttr name cell) && cell.${name} == pattern.${name}) (
      lib.attrNames pattern
    );

  # Merge a dimension assignment into a cell. Attrset values are merged in;
  # scalars become cell.${dimName}.
  applyDim =
    cell: dimName: value:
    if builtins.isAttrs value then cell // value else cell // { ${dimName} = value; };

  # Cartesian product of an attrset of lists → list of cells (merged).
  cartesian =
    dimensions:
    let
      names = lib.attrNames dimensions;
    in
    if names == [ ] then
      [ { } ]
    else
      lib.foldl' (
        cells: name:
        let
          values = dimensions.${name};
        in
        lib.concatMap (cell: map (value: applyDim cell name value) values) cells
      ) [ { } ] names;

  crossSeeds = seeds: dimCells: lib.concatMap (seed: map (dim: seed // dim) dimCells) seeds;

  normalizeCell =
    job: cell:
    cell
    // {
      optional = cell.optional or job.optional or false;
    };

  # Expand one job decl to a list of cells.
  expand =
    job:
    let
      mode = job.expansion or "cartesian";
      dimensions = job.dimensions or { };
      seeds = job.seeds or [ { } ];
      strategy = defaultStrategy // (job.strategy or { });
      base = if mode == "explicit" then job.allow or [ ] else crossSeeds seeds (cartesian dimensions);
      afterExclude = lib.filter (
        cell: !(lib.any (pat: matchesPartial pat cell) (job.exclude or [ ]))
      ) base;
      # include appends (exclude + include to override).
      withIncludes = afterExclude ++ (job.include or [ ]);
      cells = map (normalizeCell job) withIncludes;
      inherit (strategy) maxCells;
    in
    if maxCells != null && lib.length cells > maxCells then
      throw "ci.matrix: job exceeds maxCells (${toString (lib.length cells)} > ${toString maxCells})"
    else
      cells;

  # Assemble a MatrixPlan: profiles + expanded jobs.
  plan =
    {
      runnerProfiles ? defaultRunnerProfiles,
      jobs ? { },
      strategy ? { },
      strict ? true,
    }:
    let
      globalStrategy = defaultStrategy // strategy;
      expandedJobs = lib.mapAttrs (
        name: job:
        let
          merged = job // {
            strategy = globalStrategy // (job.strategy or { });
          };
          cells = expand merged;
        in
        merged
        // {
          inherit name cells;
        }
      ) jobs;
    in
    {
      inherit runnerProfiles strict;
      strategy = globalStrategy;
      jobs = expandedJobs;
    };

  # Resolve github_actions runs-on label list for a profile id.
  profileRunsOn =
    profiles: provider: profileId:
    let
      profile = profiles.${profileId} or null;
      bag = if profile == null then null else profile.providers.${provider} or null;
    in
    bag;

  requireProviderBag =
    {
      strict ? true,
      runnerProfiles,
      provider,
      profileId,
    }:
    let
      bag = profileRunsOn runnerProfiles provider profileId;
    in
    if bag != null then
      bag
    else if strict then
      throw "ci.matrix: runner profile '${profileId}' missing providers.${provider}"
    else
      { };

  # Structured report for stdlib.report / markers (language-shaped when jobs match).
  report =
    matrixPlan:
    let
      jobs = matrixPlan.jobs or { };
      jobNames = lib.attrNames jobs;
      allCells = lib.concatLists (map (n: jobs.${n}.cells or [ ]) jobNames);
      # Prefer GHA runs-on labels as "runners" when profiles are the defaults.
      runners = lib.unique (
        lib.concatMap (
          id:
          let
            bag = (matrixPlan.runnerProfiles.${id} or { }).providers.github_actions or { };
            runs = bag.runs-on or [ ];
          in
          if builtins.isList runs then runs else [ runs ]
        ) (lib.attrNames matrixPlan.runnerProfiles)
      );
    in
    {
      empty = allCells == [ ];
      inherit runners;
      jobs = lib.mapAttrs (_: j: {
        cells = j.cells or [ ];
        optional = j.optional or false;
        strategy = j.strategy or { };
      }) jobs;
      cellCount = lib.length allCells;
    };
in
{
  inherit
    defaultRunnerProfiles
    defaultStrategy
    matchesPartial
    cartesian
    expand
    plan
    report
    profileRunsOn
    requireProviderBag
    ;
}
