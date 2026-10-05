# Provider-agnostic CI matrix IR (MatrixPlan).
# Dimensions → cartesian / explicit allow → exclude → include → cells.
# M3 adds arch-filtered runner catalogs plus fixture/process dimension metadata.
{ lib }:
let
  ubuntuProfile = release: {
    os = "linux";
    distro = "ubuntu";
    inherit release;
    arch = "x86_64";
    providers = {
      github_actions = {
        runs-on = [ "ubuntu-${release}" ];
      };
    };
  };

  # Default host profiles: current Ubuntu LTS + previous. versions-lib.ubuntuLts reads these releases.
  # x86_64-only so empty / default language matrices stay byte-stable.
  defaultRunnerProfiles = {
    ubuntu-lts-prev = ubuntuProfile "24.04";
    ubuntu-lts-curr = ubuntuProfile "26.04";
  };

  # Opt-in aarch64 LTS pair (GitHub-hosted ARM labels). Merge when arches includes aarch64.
  aarch64RunnerProfiles = {
    ubuntu-lts-prev-aarch64 = {
      os = "linux";
      distro = "ubuntu";
      release = "24.04";
      arch = "aarch64";
      providers = {
        github_actions = {
          runs-on = [ "ubuntu-24.04-arm" ];
        };
      };
    };
    ubuntu-lts-curr-aarch64 = {
      os = "linux";
      distro = "ubuntu";
      release = "26.04";
      arch = "aarch64";
      providers = {
        github_actions = {
          runs-on = [ "ubuntu-26.04-arm" ];
        };
      };
    };
  };

  allRunnerProfiles = defaultRunnerProfiles // aarch64RunnerProfiles;

  # Preferred runner id order for stable matrix.include / empty-workflow output.
  preferredRunnerOrder = [
    "ubuntu-lts-prev"
    "ubuntu-lts-curr"
    "ubuntu-lts-prev-aarch64"
    "ubuntu-lts-curr-aarch64"
  ];

  # Named fixture catalogs (metadata). Dimension values are the attr names.
  defaultFixtureProfiles = {
    none = {
      description = "No CI fixture services";
      services = { };
    };
    postgres = {
      description = "Enable services.postgres (see presets.fixtures.postgres)";
      services.postgres.enable = true;
    };
  };

  # Named process/service-set catalogs (metadata). Dimension values are the attr names.
  defaultProcessProfiles = {
    default = {
      description = "No extra devenv processes";
      processes = { };
    };
  };

  defaultStrategy = {
    failFast = false;
    maxParallel = null;
    maxCells = null;
  };

  # Keep profiles whose arch is in arches (missing arch treated as x86_64).
  profilesForArches =
    profiles: arches: lib.filterAttrs (_: p: lib.elem (p.arch or "x86_64") arches) profiles;

  # Stable runner id list for the given profile set.
  runnerIds =
    profiles:
    let
      ids = lib.attrNames profiles;
      preferred = lib.filter (id: lib.elem id ids) preferredRunnerOrder;
      rest = lib.filter (id: !(lib.elem id preferredRunnerOrder)) ids;
    in
    preferred ++ lib.sort (a: b: a < b) rest;

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

  # Runner ids whose profile metadata is current Ubuntu LTS: highest `release`
  # among profiles with distro = "ubuntu". Custom catalogs with different ids
  # still participate as long as they carry release/distro metadata.
  currentLtsRunnerIds =
    profiles:
    let
      ubuntu = lib.filterAttrs (
        _: p: (p.distro or null) == "ubuntu" && (p.release or null) != null
      ) profiles;
      releases = lib.unique (map (p: p.release) (lib.attrValues ubuntu));
      maxRelease =
        if releases == [ ] then
          null
        else
          lib.foldl' (a: b: if lib.versionOlder a b then b else a) (lib.head releases) (lib.tail releases);
    in
    if maxRelease == null then
      [ ]
    else
      lib.attrNames (lib.filterAttrs (_: p: p.release == maxRelease) ubuntu);

  # matchAny patterns for current-LTS runners; throws when none can be resolved.
  currentLtsMatchAny =
    profiles:
    let
      ids = currentLtsRunnerIds profiles;
    in
    if ids == [ ] then
      throw "ci.matrix: pr expansion profile found no current-LTS runners (need ubuntu profiles with release metadata)"
    else
      map (id: { runner = id; }) ids;

  # Named expansion profiles: same dimensions, different cell filters (PR vs schedule).
  # Empty attrset = identity (keep all cells). `match` / `matchAny` / `exclude` use
  # the same partial-match semantics as job.exclude.
  # `selectCurrentLts` (pr default, or a job overlay) is resolved in forProfile
  # after overlay merge against the plan's runnerProfiles — not fixed ids — so
  # caller-supplied catalogs keep cells.
  defaultExpansionProfiles = {
    schedule = { };
    push = { };
    pr = {
      selectCurrentLts = true;
    };
  };

  # Filter an expanded cell list by an expansion-profile attrset.
  filterCells =
    cells: profile:
    let
      afterExclude =
        if (profile.exclude or [ ]) != [ ] then
          lib.filter (cell: !(lib.any (pat: matchesPartial pat cell) profile.exclude)) cells
        else
          cells;
    in
    if profile ? match then
      lib.filter (matchesPartial profile.match) afterExclude
    else if (profile.matchAny or [ ]) != [ ] then
      lib.filter (cell: lib.any (pat: matchesPartial pat cell) profile.matchAny) afterExclude
    else
      afterExclude;

  # Apply a named or inline expansion profile to a MatrixPlan (post-expand).
  forProfile =
    matrixPlan: profileOrName:
    let
      catalogs = matrixPlan.expansionProfiles or defaultExpansionProfiles;
      profileName = if builtins.isString profileOrName then profileOrName else null;
      rawBase =
        if profileName != null then
          catalogs.${profileName} or (throw "ci.matrix: unknown expansion profile '${profileName}'")
        else
          profileOrName;
      # Job overlay keys replace base; lists are replaced wholesale (not concatenated).
      mergeRaw =
        job:
        let
          overlay = if profileName != null then (job.expansionProfiles or { }).${profileName} or { } else { };
        in
        rawBase // overlay;
      # Resolve selectCurrentLts after overlay merge so a job can opt in, and strip
      # the control key before filterCells (which only understands match/matchAny/exclude).
      resolveProfile =
        raw:
        let
          withoutControl = builtins.removeAttrs raw [ "selectCurrentLts" ];
        in
        if raw.selectCurrentLts or false then
          withoutControl
          // {
            matchAny = currentLtsMatchAny (matrixPlan.runnerProfiles or { });
          }
        else
          withoutControl;
      profileUsesFilters =
        raw:
        (raw.selectCurrentLts or false)
        || (raw ? match)
        || ((raw.matchAny or [ ]) != [ ])
        || ((raw.exclude or [ ]) != [ ]);
      filteredJobs = lib.mapAttrs (
        _: job:
        let
          p = resolveProfile (mergeRaw job);
        in
        job
        // {
          cells = filterCells (job.cells or [ ]) p;
        }
      ) matrixPlan.jobs;
      # Reject when a profile empties any previously nonempty job — even if
      # sibling jobs retain cells. github_actions.render omits empty jobs, so a
      # silent per-job wipe would skip that job's command. Also covers the
      # all-jobs-empty case (misconfigured catalog / match that matches nothing).
      emptiedJob = lib.any (
        name: (matrixPlan.jobs.${name}.cells or [ ]) != [ ] && (filteredJobs.${name}.cells or [ ]) == [ ]
      ) (lib.attrNames matrixPlan.jobs);
      anyJobFilters = lib.any (job: profileUsesFilters (mergeRaw job)) (lib.attrValues matrixPlan.jobs);
    in
    if anyJobFilters && emptiedJob then
      throw "ci.matrix: expansion profile emptied one or more jobs (no cells matched the profile for a previously nonempty job)"
    else
      matrixPlan
      // {
        activeProfile = profileName;
        jobs = filteredJobs;
      };

  # Assemble a MatrixPlan: profiles + expanded jobs.
  plan =
    {
      runnerProfiles ? defaultRunnerProfiles,
      jobs ? { },
      strategy ? { },
      strict ? true,
      fixtureProfiles ? defaultFixtureProfiles,
      processProfiles ? defaultProcessProfiles,
      expansionProfiles ? defaultExpansionProfiles,
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
      inherit
        runnerProfiles
        strict
        fixtureProfiles
        processProfiles
        expansionProfiles
        ;
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
      arches = lib.sort (a: b: a < b) (
        lib.unique (
          map (id: (matrixPlan.runnerProfiles.${id} or { }).arch or "x86_64") (
            lib.attrNames matrixPlan.runnerProfiles
          )
        )
      );
      dimValues =
        name:
        lib.sort (a: b: a < b) (
          lib.unique (lib.filter (v: v != null) (map (cell: cell.${name} or null) allCells))
        );
    in
    {
      empty = allCells == [ ];
      inherit runners arches;
      fixtures = dimValues "fixture";
      processes = dimValues "process";
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
    aarch64RunnerProfiles
    allRunnerProfiles
    preferredRunnerOrder
    defaultFixtureProfiles
    defaultProcessProfiles
    defaultExpansionProfiles
    defaultStrategy
    profilesForArches
    runnerIds
    currentLtsRunnerIds
    currentLtsMatchAny
    matchesPartial
    cartesian
    expand
    filterCells
    forProfile
    plan
    report
    profileRunsOn
    requireProviderBag
    ;
}
