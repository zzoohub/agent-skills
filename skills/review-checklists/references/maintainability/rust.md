# Rust instantiation

Rust spellings of `references/maintainability.md` (gates and output: `SKILL.md`). The compiler owns aliasing, nullability and data races; review where code opts back out. Not findings: what rustc or clippy already flag (an `#[allow]` silencing one is), `expect("why")` at a true invariant, cloning an `Arc`, and interior mutability in shared services (pools, caches, metrics).

## API surface & traits
- **Visibility leaks** — `pub` fields or internals in a library's API make every implementation change a semver-major release. Keep fields private; `pub(crate)` by intent.
- **Fat trait** — impls that `unimplemented!()` or `todo!()` half the methods: refused bequest that panics at runtime. Split by consumer role.
- **`Deref` as inheritance** — `Deref` to a "base" struct for its methods hides method resolution. Delegate explicitly.

## Ownership & state
- **`Rc<RefCell<T>>` / `Arc<Mutex<T>>` sprawl** — shared mutability as the default trades compile-time guarantees for runtime borrow panics and deadlocks. Restructure ownership (pass `&mut`, split the struct, pass messages).
- **Hidden mutation behind `&self`** — `&self` promises shared access, not read-only: flag only a query-named method (`get_*`, `is_*`) whose mutation callers can observe.
- **`.clone()` to silence the borrow checker** — a finding only for large per-request copies, or copies that must stay in sync.

## Errors & escape hatches
- **`unwrap()`/`expect()` on recoverable paths** — a panic the caller never chose; return `Result` for anything bad input can reach.
- **`anyhow` or `Box<dyn Error>` across a library API** — callers can't `match` on failure modes: a `thiserror` enum at the edge, `anyhow` in applications.
- **`let _ = fallible()`** — Rust's empty `catch`: handle it or say why ignoring is correct.
- **Escape hatches** — `as` numeric casts on external values (silent truncation; use `try_into`), `transmute`, unchecked indexing on external input, an `unsafe` block without a `// SAFETY:` comment naming its invariant.

## Tests
- **`#[cfg(test)]` branches in production functions** — tests exercise a different program; use a seam.
- **Order-dependent tests** — passing only with `--test-threads=1` (`cargo test` runs in parallel): shared files, env vars or statics.
