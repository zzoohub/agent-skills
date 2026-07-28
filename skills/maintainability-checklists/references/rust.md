# Rust instantiation

The per-language spellings of the SKILL.md smells. Same judgment, same Before-You-Report gates,
same output contract. Rust's compiler absorbs whole categories other languages review by hand
(aliasing, nullability, data races) — so here, review concentrates on the places where code
*opts back out* of those guarantees, and on the design layers the borrow checker can't see.

## Modularity, Cohesion & Coupling

- **`mod.rs` / lib.rs accumulation** — one module collecting types, impls, helpers, and glue; same god-object cost, spelled as a 2,000-line module. Split by responsibility; use `pub(crate)` deliberately, not as a default.
- **Visibility leaks** — `pub` fields and `pub` internals that freeze implementation details into the crate's API (semver cost: changing them is a breaking release). Expose constructors/methods, keep fields private.
- **Coherence workarounds as coupling** — newtype wrappers over foreign types spread across modules to dodge the orphan rule; centralize the wrapping in one adapter module (that's your anti-corruption layer).

## Abstraction Fit

- **Trait with one impl** — a trait invented "for flexibility" with a single implementor and no test double using it; concrete types first, trait on the third implementor (a trait that exists as a test seam is a seam — gate 5 applies).
- **Macro where a function would do** — `macro_rules!`/proc macros add an opaque layer rustfmt/clippy/IDE can't see through; the cognitive-cost test applies double. Reach for macros only when the type system genuinely can't express it.
- **Generic soup** — `fn f<T: AsRef<str>, U: Into<Cow<'a, str>>>(…)` on an internal function with one caller; monomorphization bloat plus unreadable signatures. Take `&str` and move on.

## Inheritance & Interfaces (traits)

- **Fat trait** — a trait whose impls `unimplemented!()`/`todo!()` half the methods (that panic *is* refused bequest). Split by consumer role; default methods only for true shared behavior.
- **Deref-as-inheritance** — implementing `Deref` to a "base" struct to fake method inheritance; method resolution becomes invisible and self-documenting APIs stop being either. Compose and delegate explicitly.
- **`dyn Trait` vs generics by accident** — boxed trait objects on hot internal paths (vtable + allocation) or generics on plugin boundaries (no runtime swap); choose per the boundary's real variability, and note it.

## State & Side Effects

- **`Rc<RefCell<T>>` / `Arc<Mutex<T>>` sprawl** — interior mutability everywhere is the codebase fighting the borrow checker instead of fixing ownership; compile-time guarantees degrade into runtime `borrow()` panics and deadlocks. Restructure ownership (pass `&mut`, split the struct, message-pass) before reaching for shared mutability.
- **`.clone()` to silence the borrow checker** — routine deep clones hiding an ownership design problem (and the perf cost compounds); each one deserves a "who owns this?" answer, not a reflex.
- **Hidden mutation behind `&self`** — a `&self` method that writes through `RefCell`/`Mutex`/atomics is CQS violation in Rust spelling: the signature promises read-only. Take `&mut self`, or name the method for the write it does.
- **Global mutable state** — `static` + `lazy_static!`/`OnceLock` with interior mutability as ambient config/registry; hidden dependency, test-ordering hazard. Pass it down or scope it to an app struct.

## Error-Handling Design

- **`unwrap()`/`expect()` on recoverable paths** — in a library or long-running service, a panic is a crash *the caller never chose*; reserve panics for invariant violations, return `Result` for everything reachable by bad input. (`expect("why this can't fail")` at true invariants is fine — say why.)
- **`anyhow` in a public API** — `Box<dyn Error>`/`anyhow::Error` returned from a library boundary means callers can't `match` on failure modes; use a `thiserror` enum at the API edge, keep `anyhow` for applications.
- **Context-free `?` chains** — `?` all the way up with no `#[source]`/`.context(...)`: the caller learns "io error" five layers from which file/operation. Attach the operation and identifiers where the error crosses a layer.
- **`let _ = fallible()`** — explicitly discarding a `Result` is the empty-catch of Rust; either handle it or document why ignoring is correct.

## Domain Modeling

- **Bool/Option soup instead of an enum** — `is_loading: bool, error: Option<String>, result: Option<T>` permits illegal combinations; Rust's sum types are the canonical fix — model the states, let `match` exhaustiveness enforce handling.
- **Newtype the primitives** — raw `String`/`u64` for ids, money, quantities cross-assign silently; `struct UserId(String)`, `struct Cents(i64)` make misuse a compile error (zero runtime cost).
- **Typestate for temporal coupling** — `configure()`-before-`run()` ordering enforced by runtime panic → encode as `Builder → Ready → Running` types so the wrong order doesn't compile.
- **Escape hatches** — `as` numeric casts (silent truncation/wraparound — use `try_into`), `transmute`, unchecked indexing on external input, and `unsafe` blocks without a `// SAFETY:` comment stating the upheld invariant. Each one switches off exactly the guarantee Rust was chosen for.

## Testability

- **Uninjected time/IO** — `Instant::now()`/`SystemTime`, `std::fs`, raw sockets called deep inside logic; no seam without a trait or function parameter. Inject a clock/fs trait at the boundary (one prod impl + one test impl is not premature abstraction).
- **`#[cfg(test)]` forks of prod code** — test-only branches inside production functions mean tests exercise a different program; prefer seams over conditional compilation of logic.

## Test Quality

- **`assert!(result.is_ok())`** — the hollow assertion in Rust spelling: unwrap and assert on the *value*. Same for `is_some()`.
- **Giant `insta` snapshots re-approved blindly** — `cargo insta accept` as a reflex is the snapshot-blob smell; snapshot only what a human will re-review.
- **Order-dependent tests** — `cargo test` runs tests in parallel by default; tests sharing files/env/statics that pass only with `--test-threads=1` are the interdependence smell plus flakiness.
