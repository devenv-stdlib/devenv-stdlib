# listOf concatenates across modules. Selectable runtimes (JavaScript
# runtimes, Python implementations, Rust channels, a future compiler
# list) use this type so each value is expanded once, in first-seen order.
{ lib }:
elemType:
let
  base = lib.types.listOf elemType;
in
base
// {
  merge = loc: defs: lib.unique (base.merge loc defs);
}
