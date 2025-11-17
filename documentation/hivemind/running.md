import { ComputeEngine } from "https://cdn.jsdelivr.net/npm/@cortex-js/compute-engine/+esm";

const ce = new ComputeEngine();

// A MathJSON expression
const expr = ["Add", 5, ["Multiply", 2, 3]];

// Evaluate it
const result = ce.box(expr).evaluate().json;

console.log(result);  // → 11