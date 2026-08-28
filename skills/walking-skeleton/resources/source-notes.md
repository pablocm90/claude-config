# Walking Skeleton Source Notes

Provenance for the `walking-skeleton` skill. Load for teaching, for justifying the approach to a team, or when updating the skill. Not needed during ordinary use.

## Central Thesis

Across every source: **the first thing you build should be the thinnest possible slice of real functionality that you can automatically build, deploy, and test end to end.** Its value lies in what it forces you to decide and what it lets you discover — architecture, deployment, integration, feedback loops — not in the functionality it delivers. Build the connections first, because connections are where projects break, and they break most expensively when discovered late.

## Source Map

| Source | Concepts used in the skill |
|--------|----------------------------|
| Alistair Cockburn, *Crystal Clear* (2004) — "Walking Skeleton" | The canonical definition: "a tiny implementation of the system that performs a small end-to-end function… it need not use the final architecture, but it should link together the main architectural components"; architecture and functionality evolve in parallel → "Core Principles", "The Architecture Is Allowed To Be Wrong" |
| Andy Hunt & Dave Thomas, *The Pragmatic Programmer* (1999) — "Tracer Bullets" | Tracer code is lean but complete and becomes part of the final system; the prototype contrast ("all facade… nothing behind it"); feedback velocity — "the more quickly you can get feedback, the less change you need to get back on target"; tracer bullets suit volatile requirements, upfront spec suits stable ones → "The Terms, Distinguished", "It Is Production Code", "Do You Actually Need One?" |
| Steve Freeman & Nat Pryce, *Growing Object-Oriented Software, Guided by Tests* (2009), ch. 4 "Kick-Starting the Test-Driven Cycle" and ch. 10 "The Walking Skeleton" | "The thinnest possible slice of real functionality that we can automatically build, deploy, and test end-to-end"; the first end-to-end test forces the whole build/deploy/test cycle into existence; keep skeleton functionality "so simple that it's obvious and uninteresting" so attention goes to infrastructure; "Deciding the Shape of the Walking Skeleton" via a simple boxes-and-lines diagram; "Build Sources of Feedback"; "Expose Uncertainty Early" → the entire Workflow section, "The Functionality Should Be Boring On Purpose", "Write The End-to-End Test First", "Build Sources Of Feedback" |
| Clint Shank, *97 Things Every Software Architect Should Know* — "Start with a Walking Skeleton" | All main architectural components connected through all communication paths; grow the skeleton rather than replace it ("put it on a workout program"); architectural change gets harder and more expensive the longer the system exists; matters more as team and system scale → "It Must Be A Skeleton", "Write Down The Deferrals, Then Grow Flesh" |
| Jade Rubick, [Steel threads](https://www.rubick.com/steel-threads/) | A thin slice that weaves through the parts of a system to implement one important use case; useful for cutting through design complexity and avoiding integration pain; the term of choice for existing systems → "The Terms, Distinguished", brownfield example in `worked-examples.md` |
| Rian van der Merwe, [Using steel threads to reduce product delivery risk](https://elezea.com/2023/03/using-steel-threads-to-reduce-product-delivery-risk/) | "The thinnest possible version that crosses the boundaries of the system and covers an important use case"; stakeholders see working capability rather than component completion → "Choose The Thread", sizing |
| [Integration, integration, integration](https://www.defmyfunc.com/2019_10_18_walking_skeleton/) | Skeleton proves known integrations across people, process and tech; layered order — foundation, interface, observability, system integration, process integration; test in production safely; failure modes: prototyping mindset, feature-first, siloed teams, avoiding production testing → "Failure Modes", brownfield example |
| Ben Christel, [Walking Skeleton](https://bensguide.substack.com/p/walking-skeleton) | README-and-one-command-per-task first; build tools and app code iteratively rather than finishing infrastructure first; generators save time but every tool is "a burden you will have to carry for the lifetime of the project" → "Building It In Strides", the DoD item about someone else running the cycle from the README |
| Industrial Logic, [Evolution, Cupcakes, and Skeletons](https://www.industriallogic.com/blog/evolution-cupcakes-and-skeletons/) (cupcake via Brandon Schauer) | The skeleton tests infrastructure and integration; the cupcake tests product viability and user experience; both are evolutionary-design instruments and neither substitutes for the other → "The Terms, Distinguished", the cupcake caveat |
| Artima interview with Hunt & Thomas, [Tracer Bullets and Prototypes](https://www.artima.com/articles/tracer-bullets-and-prototypes) | "One thin line of execution goes end to end"; add one feature at a time, each implementing one use case; prototypes answer a specific investigable question and are thrown away → spike/prototype rows in the terms table |

## Where The Sources Disagree

- **How much architecture to commit to.** Cockburn explicitly permits a non-final architecture. Shank's framing leans toward the skeleton *being* the architecture, validated early. The skill takes Cockburn's line — the skeleton is an instrument for finding out the architecture is wrong — because it removes the excuse to delay the skeleton until the design is settled.
- **Skeleton vs cupcake as the right first thing.** Industrial Logic's framing implies a fully-baked tiny slice is often the better first deliverable. The skill keeps both and routes by dominant risk: integration/deployment risk → skeleton; product-viability risk → cupcake, via `story-splitting`.
- **Templates and generators.** Christel prefers hand-building the skeleton for understanding; most practitioner sources are silent. The skill does not take a side — it only requires the result to walk.

## What The Sources Do Not Cover Well

Little published material addresses the skeleton that is built and then abandoned, or scaffolding presented as a skeleton. The "Failure Modes" table extends the sources on these points rather than reporting them.
