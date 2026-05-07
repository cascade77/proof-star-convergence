# rocq

Formal verification of the Large Star / Small Star connected components algorithm
using the Rocq proof assistant. The goal is to prove that the algorithm is correct
at fixpoint: two nodes share a label if and only if they are reachable from each
other in the graph.

---

## Dataset

There is no external dataset. The graph is modeled directly in Rocq as a list of
undirected edges over `nat`. The sanity check examples in the file use small
hand-written graphs to validate the definitions before the proofs begin.

---

## Platform

Rocq (formerly Coq), version 8.19 or later. Developed and checked locally using
the `rocq` command line checker.

---

## Dependencies

No external libraries. The proof uses only the Rocq standard library:

```
Require Import List.
Require Import Arith.
Require Import Lia.
```

---

## File

`ConnectedComponents.v` is a single self-contained file. It is organized in order:
graph representation, one round of the algorithm, reachability, sanity checks,
helper lemmas, and main theorems.

---

## Definitions

The graph is a list of pairs of natural numbers. Each pair is an undirected edge.

```coq
Definition graph := list (nat * nat).
```

The neighbors of a node are collected by scanning the edge list for any edge
that touches that node, on either side.

```coq
Fixpoint neighbors (n : nat) (g : graph) : list nat :=
  match g with
  | [] => []
  | (u, v) :: rest =>
      if Nat.eqb u n then v :: neighbors n rest
      else if Nat.eqb v n then u :: neighbors n rest
      else neighbors n rest
  end.
```

The label of a node is the minimum of its neighbor list, falling back to the
node itself if it has no neighbors. This means isolated nodes always label
themselves, and no node ever gets a label larger than its own id.

```coq
Definition label_of (n : nat) (g : graph) : nat :=
  list_min (neighbors n g) n.
```

One round of the algorithm updates every edge endpoint to its current label.

```coq
Definition apply_star (g : graph) : graph :=
  map (update_edge g) g.
```

Reachability is an inductive proposition with three constructors: reflexivity,
a single edge (in either direction), and transitivity.

```coq
Inductive connected (g : graph) : nat -> nat -> Prop :=
  | conn_refl  : forall u, connected g u u
  | conn_edge  : forall u v,
      (In (u, v) g \/ In (v, u) g) -> connected g u v
  | conn_trans : forall u w v,
      connected g u w -> connected g w v -> connected g u v.
```

---

## Theorems and Lemmas

The helper lemmas build up the arithmetic facts needed by the main theorems.
`label_le_self` says the label of any node is at most the node itself.
`label_le_neighbor` says if `v` is a neighbor of `u` then `label_of u g <= v`.
`fixpoint_labels_stable` says at fixpoint, every node label equals the node id.
`list_min_achieves` says if the minimum of a list differs from the default, it
actually appears in the list, meaning it came from a real neighbor.

The main theorems are:

> **Theorem 1.** `fixpoint_same_label`. At fixpoint, for any edge `(u, v)` in the
graph, `label_of u g = label_of v g`. Both endpoints see each other as neighbors,
both labels equal their own node id at fixpoint, and those two facts together
force `u = v` by `lia`.

> **Theorem 2.** `fixpoint_correct`. At fixpoint, if two nodes share a label then
they are connected. The proof sets `m = label_of u g` and cases on whether `m = u`
and `m = v`. If both equal `m` then `u = v` and `conn_refl` closes it. Otherwise
`m` is a genuine neighbor of `u` or `v` (by `list_min_achieves`), giving a path
through `m` via `conn_trans`.

> **Theorem 3.** `fixpoint_iff`. The full biconditional: at fixpoint, same label
if and only if connected. The forward direction is `fixpoint_correct`. The
backward direction follows by induction on the `connected` derivation, using
`fixpoint_same_label` for the edge case and transitivity of equality for
`conn_trans`.

---

## How to Check

```bash
rocq compile ConnectedComponents.v
```

No errors and no admits anywhere in the file.
