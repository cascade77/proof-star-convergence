# proof-star-convergence

This project builds a distributed bioinformatics pipeline on the STRING human protein
interaction network using PySpark, and formally verifies the correctness of the core
algorithm in Rocq. The pipeline ingests 13.7 million protein interactions, filters to
high-confidence links, computes network statistics in parallel, runs connected
components, and performs three types of Monte Carlo disruption simulations to study
network robustness. The Rocq proof guarantees that the connected components algorithm
produces the correct answer at fixpoint for any graph.

---

## Problem Statement

The human proteome is not a collection of isolated proteins. Proteins interact with
each other physically, and those interactions form a network where two proteins are
connected if there is experimental or computational evidence that they bind. Finding
connected components in this network reveals which proteins are functionally linked
and which are isolated. The algorithm that does this, the Large Star / Small Star
connected components algorithm, is the same one LinkedIn deployed in production to
find connected communities across hundreds of millions of users.

The biological question this project answers is: are cancer driver proteins
disproportionately important for the structural integrity of the human protein
interaction network, beyond what their degree (number of connections) alone predicts?

To answer it, the pipeline compares three disruption strategies: removing edges
randomly, removing edges connected to the highest-degree hub proteins first, and
removing edges connected to known cancer driver genes from the COSMIC Cancer Gene
Census first. The cancer driver attack causes faster network collapse than the
degree-based attack even at very low removal fractions, which means these proteins
hold structurally critical positions that go beyond simply having many connections.

---

## Why Connected Components at This Scale

- LinkedIn uses this algorithm to power "People You May Know": finding everyone in
  your extended professional network means finding all nodes in the same connected
  component of a graph with hundreds of millions of nodes. In a protein network, the
  same question is which proteins are reachable from each other through chains of
  physical interactions.
- Twitter uses it for community detection, identifying clusters of related accounts.
  In a protein network, these clusters correspond to functional modules, groups of
  proteins working together in the same biological process.
- Facebook runs it across their social graph to find connected communities. In the
  human proteome, the giant connected component spans nearly 98% of all proteins,
  meaning most of human biology is one large interconnected system.
- At production scale these algorithms must be distributed and verifiably correct. A
  bug does not appear on a small test graph. It appears silently at 500 million nodes,
  or in a Monte Carlo simulation running 450 times where a wrong answer looks exactly
  like a right one.
- The Large Star / Small Star algorithm is what LinkedIn actually deployed. This
  project formally verifies its correctness in Rocq, then runs it on the STRING
  human protein interaction network with a machine-checked guarantee backing every
  simulation result.

---

## Dataset

| Field | Detail |
|---|---|
| Source | STRING database v12.0 (https://string-db.org/cgi/download) |
| File | `9606.protein.links.v12.0.txt.gz` |
| Organism | *Homo sapiens* (taxon 9606) |
| Format | Space-separated text, gzipped |
| Columns | `protein1`, `protein2`, `combined_score` (0 to 1000) |
| Raw size | 13,715,651 interactions |
| After filtering | 473,860 edges, 16,201 proteins (score >= 700) |

The combined score integrates experimental evidence, co-expression, text mining, and
computational prediction. A score of 700 or above is STRING's high-confidence
threshold. About 96% of raw interactions fall below it, so the filter keeps only
well-evidenced links.

---

## Framework

PySpark (Apache Spark) running in local mode on Google Colab. The notebook installs
PySpark at runtime, downloads the dataset directly from STRING, and runs all
distributed operations using Spark DataFrames and RDDs. No cluster setup is required.
The design scales to a full cluster by changing `local[*]` to a cluster master URL.

---

## Pipeline

```
Download STRING .gz file
        |
        v
Ingest into Spark DataFrame (schema enforced, gzip read natively)
        |
        v
Cache raw DataFrame
        |
        v
Filter: combined_score >= 700
        |
        v
Cache filtered DataFrame
        |
        v
Compute degree distribution in parallel (Spark groupBy)
        |
        v
Identify top hub proteins
        |
        v
Collect edges locally, map protein strings to integers
        |
        v
Run Large Star / Small Star connected components (Rocq-verified)
        |
        v
Parallel Monte Carlo edge dropout simulations (Spark parallelize)
        |
        v
Targeted hub attack simulations (Spark parallelize)
        |
        v
Cancer driver attack simulations (Spark parallelize)
        |
        v
Phase transition refinement (fine-grained hub attack, 40-50%)
        |
        v
Plots, summary tables, biological interpretation
```

**Distributed operations used:**

- `spark.read.csv` with enforced schema for parallel ingest
- `df.cache()` at two stages to avoid recomputation
- `df.filter` and `df.groupBy` for parallel degree computation
- `sc.parallelize` with `numSlices` for distributing Monte Carlo tasks across workers
- `rdd.map` for parallel simulation execution
- `rdd.collect` to gather results back to the driver

---

## Repository Structure

```
proof-star-convergence/
├── rocq/
│   ├── ConnectedComponents.v      # Rocq proof of algorithm correctness at fixpoint
│   └── README.md                  # proof walkthrough and theorem listing
├── spark/
│   ├── string_pipeline.ipynb      # full PySpark pipeline notebook
│   └── results/
│       ├── score_distribution.jpeg
│       ├── degree_distribution.jpeg
│       ├── robustness_curve.jpeg
│       ├── targeted_vs_random.jpeg
│       ├── three_attack_comparison.jpeg
│       ├── phase_transition.jpeg
│       ├── mc_simulation_results.csv
│       └── robustness_summary.csv
├── LICENSE
└── README.md
```

---

## Results

All plots are generated from the filtered STRING network (473,860 edges, 16,201 proteins).

![STRING Score Distribution](spark/results/score_distribution.jpeg)
Score distribution across all 13.7 million raw interactions. The red dashed line marks
the confidence threshold at 700. About 96% of interactions fall below it.

![Degree Distribution](spark/results/degree_distribution.jpeg)
Top 20 hub proteins by degree (left) and the full degree distribution on a log-log
scale (right). The straight line on log-log axes confirms a power-law distribution,
the hallmark of a scale-free biological network. The top hub ENSP00000269305 (TP53)
has degree 1537, meaning it interacts with nearly 10% of all proteins in the
high-confidence network.

![Robustness Curve](spark/results/robustness_curve.jpeg)
Size of the largest connected component under random edge dropout, averaged over 50
Monte Carlo simulations per dropout rate. At 90% random edge removal the network
retains roughly 75% of its proteins. The network is highly resilient to random disruption.

![Random vs Targeted Hub Attack](spark/results/targeted_vs_random.jpeg)
Comparison of random dropout against degree-based hub attack. The hub attack curve
collapses to 13% of original size by 50% removal while random dropout barely moves.

![Three Attack Strategies](spark/results/three_attack_comparison.jpeg)
All three attack strategies on one plot. The cancer driver attack curve (COSMIC genes
prioritized) sits below the degree-based curve from the very first removal fraction,
meaning cancer driver proteins cause faster fragmentation than the most connected
proteins overall.

![Phase Transition](spark/results/phase_transition.jpeg)
Fine-grained simulations at 1% intervals from 40% to 50% targeted hub removal. The
network declines approximately linearly across this range with the steepest single-step
drop at 50%.

---

## Setup and Run Instructions

1. Open `spark/string_pipeline.ipynb` in Google Colab.
2. Run all cells top to bottom (Runtime > Run all).
3. The notebook installs PySpark, downloads the dataset, and runs the full pipeline.
4. Download outputs using the final cell which calls `files.download` for all plots and CSVs.

No local installation required. Expected total runtime is 30 to 45 minutes, dominated
by the Monte Carlo simulation cells.

---


## References

Szklarczyk, D., Kirsch, R., Koutrouli, M., et al. (2023). The STRING database in 2023:
protein-protein association networks and functional enrichment analyses for any of 14,094
organisms. *Nucleic Acids Research*, 51(D1), D638-D646.
https://doi.org/10.1093/nar/gkac1000

Barabasi, A. L., & Albert, R. (1999). Emergence of scaling in random networks.
*Science*, 286(5439), 509-512.
https://doi.org/10.1126/science.286.5439.509

Forbes, S. A., et al. (2017). COSMIC: somatic cancer genetics at high-resolution.
*Nucleic Acids Research*, 45(D1), D777-D783.
https://doi.org/10.1093/nar/gkw1121

Jeong, H., Mason, S. P., Barabasi, A. L., & Oltvai, Z. N. (2001). Lethality and
centrality in protein networks. *Nature*, 411(6833), 41-42.
https://doi.org/10.1038/35075138

Saha, B., et al. (2014). A new approximation technique for resource-allocation problems.
*Proceedings of the 5th Innovations in Theoretical Computer Science conference*.
(Large Star / Small Star algorithm origin.)
