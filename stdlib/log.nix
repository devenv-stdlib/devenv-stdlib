# Public logging API for tools, presets, and loaders.
# Wraps nix-log's mkLog privately. Callers use stdlib.log only — never
# `inputs.nix-log` or raw nix-log lib. When the flake input is absent
# (nix-unit importing stdlib with only `lib`), a private fallback mirrors
# the same function surface over nixpkgs lib + builtins.trace + NIX_LOG.
{
  lib,
  nix-log ? null,
}:
let
  nixLogLib =
    if nix-log == null then
      null
    else if nix-log ? mkLog then
      nix-log
    else if nix-log ? lib && nix-log.lib ? mkLog then
      nix-log.lib
    else
      throw "stdlib.log: nix-log must expose lib.mkLog (flake input or its .lib)";

  # Private offline fallback — not a second public backend.
  fallback =
    let
      levels = {
        trace = 0;
        debug = 1;
        info = 2;
        warn = 3;
        error = 4;
      };
      envLevel =
        let
          raw = builtins.getEnv "NIX_LOG";
        in
        if raw == "" then "warn" else lib.toLower raw;
      current = levels.${envLevel} or levels.warn;
      formatAttrs = attrs: builtins.toJSON attrs;
      mk =
        rank: emit: msg:
        if current <= rank then emit msg else (x: x);
      mkAttr =
        logFn: msg: attrs:
        logFn "${msg} ${formatAttrs attrs}";
      emitTrace = msg: builtins.trace "TRACE: ${msg}";
      emitDebug = msg: builtins.trace "DEBUG: ${msg}";
      emitInfo = msg: lib.info msg;
      emitWarn = msg: lib.warn msg;
    in
    {
      mkLog = _: {
        trace = mk levels.trace emitTrace;
        debug = mk levels.debug emitDebug;
        info = mk levels.info emitInfo;
        warn = mk levels.warn emitWarn;
        warnIf = cond: msg: if cond then emitWarn msg else (x: x);
        trace' = mkAttr (mk levels.trace emitTrace);
        debug' = mkAttr (mk levels.debug emitDebug);
        info' = mkAttr (mk levels.info emitInfo);
        warn' = mkAttr (mk levels.warn emitWarn);
      };
    };

  backend = if nixLogLib != null then nixLogLib else fallback;
  logger = backend.mkLog { };
in
{
  inherit (logger)
    trace
    debug
    info
    warn
    warnIf
    trace'
    debug'
    info'
    warn'
    ;

  # True when the private nix-log flake input is wired. Tests may assert this.
  usingNixLog = nixLogLib != null;
}
