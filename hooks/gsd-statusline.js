#!/usr/bin/env node
// gsd-statusline.js — StatusLine script
// Reads JSON from stdin (provided by Claude Code) and outputs status with context usage.

const fs = require("fs");
const path = require("path");

// Read JSON from stdin
let input = "";
try {
  input = fs.readFileSync(0, "utf8");
} catch (e) {
  // stdin not available
}

let contextPct = 0;
let projectDir = process.cwd();
try {
  const data = JSON.parse(input);
  contextPct = Math.round(data?.context_window?.used_percentage ?? 0);
  if (data?.cwd) projectDir = data.cwd;
} catch (e) {
  // No valid JSON from stdin
}

const checkpointDir = path.join(process.env.HOME, ".claude", "checkpoints");
const counterFile = path.join(checkpointDir, ".tool_count");

let toolCount = 0;
try {
  toolCount = parseInt(fs.readFileSync(counterFile, "utf8").trim(), 10) || 0;
} catch (e) {
  // No counter file yet
}

const projectName = path.basename(projectDir);

const contextBar = contextPct >= 70 ? "🔴" : contextPct >= 50 ? "🟡" : "🟢";

console.log(
  `${contextBar} ${contextPct}% context | 📂 ${projectName} | 🔧 ${toolCount} tools`,
);
