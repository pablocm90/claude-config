# Deep modules

Vocabulary for the *shape* of a module, adapted from Matt Pocock's `codebase-design` (github.com/mattpocock/skills, MIT), after Ousterhout's *A Philosophy of Software Design*. Use these terms exactly. It pairs with `code-smells` (what is wrong) and `connascence` (which way the coupling should move).

## Terms

- **Module**: anything with an interface and an implementation, at any scale: a function, a class, a package, a slice across tiers.
- **Interface**: everything a caller must know to use the module correctly: the signature, but also invariants, ordering constraints, error modes, required configuration and performance. Wider than the type signature.
- **Depth**: leverage at the interface: how much behaviour a caller or a test reaches per thing it must learn. A **deep** module hides a lot behind a small interface. A **shallow** module's interface is nearly as complex as its implementation. This is not Ousterhout's ratio of implementation lines to interface lines, which padding the implementation would improve.
- **Seam**: a place where behaviour can be altered without editing there; the place a module's interface lives (Feathers, as in `finding-seams`).
- **Adapter**: a concrete thing that satisfies an interface at a seam.
- **Leverage**: what callers get from depth: more capability per thing learned.
- **Locality**: what maintainers get from depth: change, bugs and knowledge concentrate in one place.

## Three tests

- **Deletion**: imagine deleting the module. If the complexity vanishes, it was a pass-through. If it reappears across its callers, it earns its keep.
- **The interface is the test surface**: callers and tests cross the same seam. Wanting to test past the interface means the module has the wrong shape.
- **One adapter is a hypothetical seam; two make a real one** (production plus a test fake counts as two). Introduce a seam only where something actually varies across it.

## Deepening, by dependency

| The cluster depends on | Test the deepened module |
|---|---|
| Nothing outside the process | Merge it and test through the new interface directly |
| Something with a local stand-in (test database, in-memory filesystem) | With the stand-in; the seam stays internal |
| Your own service across a network | Through a port at the seam: a network adapter in production, an in-memory one in tests |
| A third party | Through an injected port, with a fake adapter in tests |

A deepening is new interface work, not a REFACTOR-phase move: it is built through `tdd`, starting RED at the new interface, so the REFACTOR checklist's "tests pass unmodified, no new public APIs" does not govern it. Once tests at the deepened interface kill the same mutants, the old unit tests on the shallow parts are redundant: delete them rather than keep both layers.

## Design it twice

When the interface of a chosen candidate is open, first tell the user the constraints any interface must meet, then have three subagents each design it under a different constraint: the fewest entry points; the most flexibility; the easiest common case. Add a fourth, designed around ports and adapters, when dependencies cross a network. Give each the files, the dependency kinds, and the glossary's words. Compare the designs on depth, locality and seam placement, then recommend one, or a hybrid, with a reason.
