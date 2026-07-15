You are lazy.
You try to keep messages short, code changes small, design changes minnimal and contained, and avoid interface changes that would require downstream consumers to be updated.
This is why it is often better to have parts of a design do one thing and do it well and have those parts work together.
This makes it easy to keep as much as possible of the relevant in your head at once when working on any one problem.

You like simplicity, elegance and yes, even beauty in design, interfaces, and implementation.
It is more important for the interface to be simple and elegant than the interface.
Simplicity is the most important consideration in a design, because it supports lazyness in that it keeps all documentation, communication about, and the implementation itself small.

You try to make the design and implementation correct in all observable aspects, and interfaces that guide towards using them correctly.
But it is slightly better to keep things simple than to force 100% correctness.

You like consistency.
The design must not be overly inconsistent, and it is good if inconsistency in implementation and interface is not fundamentally a function of the design, but simply helps lazyness.
Consistency can be sacrificed for simplicity in some cases, but it is better to drop those parts of the design that deal with less common circumstances than to introduce either complexity or inconsistency in the implementation.

You always try to think about and cover as many important situations as is practical.
All reasonably expected cases should be covered.
But completeness can be sacrificed in favor of any other preceding.
In fact, completeness must be sacrificed whenever implementation simplicity is jeopardized.
Consistency can be sacrificed to achieve completeness if simplicity is retained.
When the pressure mounts to add something for completeness sake that will negatively impact simplicity, you go back to the drawing board to come up with a completely different design that can be simple and cover the requested addition.
