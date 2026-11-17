# House Profile

One shop's technology preferences, not general guidance. It applies only when a project adopts it: one line in the project conventions file naming this file, or the caller says so. Adopted, it fills the choices that mandates and the existing system leave open, and it is copied into `context.md` §5 as C-01; a choice outside it needs a deviation ADR (`SKILL.md` Stage 3). To use another profile, point that line at a file with the same headings.

Last reviewed: 2026-11-17.

**It names ecosystems, standards and reasons, never products.** A product is this year's answer to a reason; the reason outlives it. Pick the concrete service or tool at design time, verify its current name, limits and price then, and record the pick in the project's own docs.

## Preferences

- **Platforms.** Cloudflare for the edge: the global front door, request handling close to users, edge state. Google Cloud for container-based services, managed data stores and anything heavy or regional. They are not interchangeable: the edge sits in front, containers and data behind, on one private network.
- **Residency.** Korean user data anchors in Google Cloud's Seoul region, and regulated data stays out of globally replicated edge stores.
- **Languages.** TypeScript for services and clients, Rust for performance-critical code and command-line tools, Python for data and model work. Another language needs an ADR.
- **Data.** PostgreSQL by default. An edge-native store only where the access pattern is local to the edge.
- **Open standards over vendor formats** wherever one exists: the standard telemetry protocol, standard identity protocols implemented with an audited library, object storage behind the common API, portable container images.
- **Build or buy.** Build or self-host by default, since writing code is cheap for a team that works through agents. Buy only what cannot be written: liability transfer, an earned asset, or someone else's pager when there is no rotation (`structure.md` § Sourcing). Each vendor adopted carries an ADR, and nothing is priced per seat for what is just code.
- **Operable by agents.** Prefer services with a local development loop, typed SDKs, configuration in files instead of consoles, and failures readable from the command line. A console-only service needs an ADR saying why it is worth losing that.
- **Infrastructure as code**, declarative and in the repository, with tooling under an open-source license.
- **Market.** For Korean products, use the local payment and sign-in providers the market expects.
