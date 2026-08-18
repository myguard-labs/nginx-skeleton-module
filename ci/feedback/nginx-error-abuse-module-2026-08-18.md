# nginx-error-abuse-module adoption feedback (2026-08-18)

## Generated pre-commit configuration cannot reproduce the reference

- **What:** the shared pre-commit generator omits the skeleton's structural
  ast-grep hook and vendored rule configuration, so regenerating an adopter's
  configuration removes a reference gate instead of reproducing it.
- **Where:** the reference configuration is in `.pre-commit-config.yaml` and
  `ci/ast-grep/`; the adopter exposed the drift while normalizing
  `.pre-commit-config.yaml`.
- **Cost:** adoption had to preserve the generated attempt separately and
  revert it, because accepting it would silently weaken the local gate.
- **Proposed change:** decide whether ast-grep is a generated baseline feature.
  If it is, teach `/opt/myguard/tools/gen-precommit-config.py` to emit the hook
  and arrange a reproducible rule source; if it is not, remove the reference
  hook or document it as an intentional post-generation overlay. This crosses
  every derived module and cannot be fixed safely in this skeleton alone.
