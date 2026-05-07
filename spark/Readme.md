# spark

Empirical convergence benchmark for the Large Star / Small Star connected
components algorithm. Runs the same algorithm the Rocq proof verifies, on
three graph types at six sizes, and records how many rounds it takes to reach
fixpoint and how long that takes in wall clock time.

---

## Dataset

No external dataset. Graphs are generated synthetically inside the notebook:

- **Chain**: `make_chain(n)` produces edges `(0,1), (1,2), ..., (n-2, n-1)`.
- **Star**: `make_star(n)` produces edges `(0,1), (0,2), ..., (0, n-1)`.
- **Random**: `make_random(n, p=0.01)` samples each pair `(i, j)` with
  probability `p`, producing a sparse random graph.

Sizes tested: 100, 500, 1000, 2000, 5000, 10000 nodes.

---

## Platform

Google Colab (Python 3, CPU runtime). The benchmark runs in local mode using
plain Python, not a distributed Spark cluster. PySpark is installed in the
notebook via `pip install pyspark`.

---

## Dependencies

```
pip install pyspark matplotlib
```

---

## How the Algorithm Works

Each round computes a label for every node: the minimum among its neighbors,
falling back to the node id itself. Then every edge endpoint is replaced by
its label. This repeats until the edge list stops changing. That stopping
point is the fixpoint. The Rocq proof guarantees the labels at that point
correctly identify connected components.

The core of the benchmark:

```python
def compute_labels_local(edges):
    from collections import defaultdict
    neighbors = defaultdict(list)
    for u, v in edges:
        neighbors[u].append(v)
        neighbors[v].append(u)
    labels = {}
    for node in set(neighbors.keys()):
        labels[node] = min(min(neighbors[node]), node)
    return labels

def apply_star_local(edges):
    labels = compute_labels_local(edges)
    return [(labels.get(u, u), labels.get(v, v)) for u, v in edges]

def run_until_fixpoint(edges):
    current = edges
    rounds = 0
    while True:
        next_edges = apply_star_local(current)
        rounds += 1
        if sorted(next_edges) == sorted(current):
            break
        current = next_edges
    return rounds, current
```

---

## Results

![Rounds to convergence by graph type](results/rounds_convergence.jpeg)
Rounds to fixpoint for chain, star, and random graphs from 100 to 10000 nodes.

![Wall clock time by graph type](results/wall_clock_time.jpeg)
Wall clock time in seconds for the same graphs and sizes.

The chain graph takes exactly $n - 1$ rounds because the minimum label has to
walk the full length of the path one hop at a time. The star graph converges
in 2 rounds regardless of size. The random graph converges in 4 to 6 rounds
across all sizes, consistent with the short path lengths in sparse random graphs.

Raw numbers are in `results.csv`.

---

## Notebook

`benchmark.ipynb` is fully documented with markdown cells explaining each step.
It runs top to bottom on Google Colab with no changes needed. The last cell
downloads the CSV and both plots directly to your browser.
