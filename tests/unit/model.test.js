// Tier-1 tests: pure Model.js logic, no desktop needed. `node tests/unit/model.test.js`
// Model.js is a QML `.pragma library` file, not a Node module -- strip the
// pragma and evaluate it, then call its functions directly.
"use strict"
const fs = require("fs")
const path = require("path")
const assert = require("assert")

const src = fs.readFileSync(path.join(__dirname, "../../Model.js"), "utf8").replace(/^\.pragma.*$/m, "")
const names = [...src.matchAll(/^function (\w+)/gm)].map(m => m[1])
const M = new Function(src + "\nreturn {" + names.join(",") + "}")()

let failed = 0
function t(name, fn) {
  try { fn(); console.log("PASS " + name) } catch (e) { failed++; console.log("FAIL " + name + "\n  " + e.message) }
}

// ---- PR #6 write-guard helpers
const id = "io.github.silverstone.wpal"
t("hasWorkspaceData: fresh-install seed has none", () => assert(!M.hasWorkspaceData({ globalOverride: "x", enabled: true })))
t("hasWorkspaceData: configured workspace counts", () => assert(M.hasWorkspaceData({ workspaces: { 1: {} } })))
t("hasWorkspaceData: array is not workspace data", () => assert(!M.hasWorkspaceData({ workspaces: [1] })))
t("storedEntry: found in bar layout", () =>
  assert.strictEqual(M.storedEntry(JSON.stringify({ bar: { layout: { right: [{ id, x: 1 }] } } }), id).x, 1))
t("storedEntry: found in plugins", () => assert(M.storedEntry(JSON.stringify({ plugins: [{ id }] }), id)))
t("storedEntry: bad json -> null", () => assert.strictEqual(M.storedEntry("{nope", id), null))

// ---- scratchpads
t("padKeys: S and W", () => assert.deepStrictEqual(M.padKeys(), ["S", "W"]))
t("padWorkspace: S is Omarchy's own scratchpad", () => assert.strictEqual(M.padWorkspace("S"), "special:scratchpad"))
t("padWorkspace: W is pad-w", () => assert.strictEqual(M.padWorkspace("W"), "special:pad-w"))
t("default slide: S bottom, W top", () => {
  assert.strictEqual(M.padSetting({}, "S").slideFrom, "bottom")
  assert.strictEqual(M.padSetting({}, "W").slideFrom, "top")
})
t("bad slideFrom falls back to default", () =>
  assert.strictEqual(M.padSetting({ pads: { W: { slideFrom: "left" } } }, "W").slideFrom, "top"))
t("no pads configured -> nothing launches", () => {
  for (const k of M.padKeys()) assert.strictEqual(M.padPlan({}, k).panes, null)
})

const zeroSettings = {
  workspaces: { 3: { panes: [{ appId: "foot", args: "" }] } },
  pads: {
    S: { panes: [{ appId: "omawrite", args: "~/SilverStone-Hub/scratchpad.md" }] },
    W: { panes: [{ appId: "gliff", args: "" }], slideFrom: "top" }
  }
}
t("S pad launches omawrite with the scratchpad file", () =>
  assert.deepStrictEqual(M.padPlan(zeroSettings, "S").panes,
    [{ type: "app", value: "omawrite", args: "~/SilverStone-Hub/scratchpad.md" }]))
t("W pad launches gliff, drops from top", () => {
  const p = M.padPlan(zeroSettings, "W")
  assert.deepStrictEqual(p.panes, [{ type: "app", value: "gliff", args: "" }])
  assert.strictEqual(p.slideFrom, "top")
  assert.strictEqual(p.workspace, "special:pad-w")
})
t("pad pause stops its launch", () =>
  assert.strictEqual(M.padPlan({ pads: { S: { autoLaunchEnabled: false, panes: [{ appId: "a", args: "" }] } } }, "S").panes, null))
t("global Auto Launch off stops pad launch", () =>
  assert.strictEqual(M.padPlan(Object.assign({ autoLaunchEnabled: false }, zeroSettings), "W").panes, null))
t("empty slots dropped, full-screen pick remapped", () => {
  const p = M.padPlan({ pads: { W: { panes: [{ appId: "", args: "" }, { appId: "a", args: "" }, { appId: "b", args: "" }], fullScreenIndex: 2 } } }, "W")
  assert.strictEqual(p.panes.length, 2)
  assert.strictEqual(p.fullScreenIndex, 1)
})
t("pads never count as workspace data (write guard unaffected)", () =>
  assert(!M.hasWorkspaceData({ pads: zeroSettings.pads })))

console.log(failed ? failed + " failed" : "all unit tests passed")
process.exit(failed ? 1 : 0)
