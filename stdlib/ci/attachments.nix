# Provider-agnostic CI attachment IR (AttachmentPlan).
# Sibling of MatrixPlan: build caches, coverage collectors, and test reporters
# that backends splice into job step slots around the primary command.
{ lib }:
let
  # Slots relative to the job's primary test/build command.
  slots = [
    "pre-toolchain"
    "pre-command"
    "post-command"
    "always"
  ];

  emptyPlan = {
    caches = [ ];
    coverage = [ ];
    reporting = [ ];
  };

  # Normalize a plan attrset (fill missing categories).
  plan =
    {
      caches ? [ ],
      coverage ? [ ],
      reporting ? [ ],
    }:
    {
      inherit
        caches
        coverage
        reporting
        ;
    };

  kindFor =
    category:
    {
      caches = "build-cache";
      coverage = "coverage";
      reporting = "test-report";
    }
    .${category};

  # Flatten plan categories into one list (stable category order).
  allAttachments =
    attachmentPlan:
    let
      from =
        category:
        map (
          a:
          a
          // {
            kind = a.kind or (kindFor category);
          }
        ) (attachmentPlan.${category} or [ ]);
    in
    from "caches" ++ from "coverage" ++ from "reporting";

  # Empty languages = apply to every job; otherwise require a match.
  matchesLanguage =
    languages: language: languages == [ ] || language == null || lib.elem language languages;

  assertSlot =
    slot:
    if lib.elem slot slots then
      slot
    else
      throw "ci.attachments: unknown slot '${toString slot}' (expected one of: ${lib.concatStringsSep ", " slots})";

  # Select attachments that have a bag for ctx.provider and match language.
  # ctx = { provider, language ? null, forge ? null, ... }
  select =
    attachmentPlan: ctx:
    let
      provider = ctx.provider or "github_actions";
      language = ctx.language or null;
    in
    lib.filter (
      a:
      let
        langs = a.languages or [ ];
        bag = a.providers.${provider} or null;
      in
      bag != null && matchesLanguage langs language
    ) (allAttachments attachmentPlan);

  # Group selected attachments by slot (plan order preserved within each slot).
  bySlot =
    attachmentPlan: ctx:
    let
      provider = ctx.provider or "github_actions";
      selected = select attachmentPlan ctx;
      slotOf = a: assertSlot (a.providers.${provider}.slot or "pre-command");
      forSlot = slot: lib.filter (a: slotOf a == slot) selected;
    in
    lib.listToAttrs (
      map (slot: {
        name = slot;
        value = forSlot slot;
      }) slots
    );

  # Auto-enable is a pure function of config + forge/provider context.
  # Phase 1 ships the hook only; Phase 2 adds Rust → mr-boxington, etc.
  autoEnable = _config: _ctx: [ ];

  # Merge attachment lists by id (later wins). Categories stay separate.
  mergeLists =
    base: extra:
    let
      byId = lib.foldl' (acc: a: acc // { ${a.id} = a; }) { } (base ++ extra);
      order = lib.unique (map (a: a.id) (base ++ extra));
    in
    map (id: byId.${id}) order;

  # Resolve user plan + auto-enable (auto first, user overrides same id).
  resolve =
    {
      config ? { },
      ctx,
      userPlan ? emptyPlan,
    }:
    let
      auto = autoEnable config ctx;
      autoPlan = {
        caches = lib.filter (a: (a.kind or "build-cache") == "build-cache") auto;
        coverage = lib.filter (a: (a.kind or "") == "coverage") auto;
        reporting = lib.filter (a: (a.kind or "") == "test-report") auto;
      };
      user = plan userPlan;
    in
    plan {
      caches = mergeLists autoPlan.caches user.caches;
      coverage = mergeLists autoPlan.coverage user.coverage;
      reporting = mergeLists autoPlan.reporting user.reporting;
    };

  # Structured summary for stdlib.report / markers (phase 2+ consumers).
  report =
    attachmentPlan:
    let
      all = allAttachments attachmentPlan;
    in
    {
      empty = all == [ ];
      ids = map (a: a.id) all;
      caches = attachmentPlan.caches or [ ];
      coverage = attachmentPlan.coverage or [ ];
      reporting = attachmentPlan.reporting or [ ];
      count = lib.length all;
    };
in
{
  inherit
    slots
    emptyPlan
    plan
    allAttachments
    matchesLanguage
    assertSlot
    select
    bySlot
    autoEnable
    mergeLists
    resolve
    report
    ;
}
