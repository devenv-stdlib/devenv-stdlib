# Phase 1: Den cursor aspect includes DAG (pure cascade metadata).
{ lib, ... }:
let
  cascade = import ../../modules/den/_cascades/cursor-cascade.nix;
  includesOf = name: cascade.${name}.includes or [ ];
  hasInclude = aspect: child: builtins.elem child (includesOf aspect);
in
{
  testDenCursorIncludesExtensions = {
    expr = hasInclude "cursor" "cursor-extensions";
    expected = true;
  };

  testDenCursorIncludesLlmMcpStack = {
    expr = hasInclude "cursor" "cursor-llm";
    expected = true;
  };

  testDenCursorIncludeCount = {
    expr = builtins.length (includesOf "cursor");
    expected = 2;
  };

  testDenCursorExtensionsHasNoNestedIncludes = {
    expr = includesOf "cursor-extensions";
    expected = [ ];
  };

  testDenCursorLlmHasNoNestedIncludes = {
    expr = includesOf "cursor-llm";
    expected = [ ];
  };

  # Disabling cursor means the developer aspect would not pull this DAG —
  # expressed here as: without the cursor hub, extensions/llm are not reached.
  testDenCursorOffDropsCascade = {
    expr =
      let
        developerIncludes = [ ]; # cursor aspect not listed
        reachable = lib.concatMap (name: [ name ] ++ (includesOf name)) developerIncludes;
      in
      reachable;
    expected = [ ];
  };

  testDenCursorOnPullsCascade = {
    expr =
      let
        developerIncludes = [ "cursor" ];
        reachable = lib.unique (lib.concatMap (name: [ name ] ++ (includesOf name)) developerIncludes);
      in
      lib.sort (a: b: a < b) reachable;
    expected = [
      "cursor"
      "cursor-extensions"
      "cursor-llm"
    ];
  };
}
