// Runs the comparison rules and the subcategory chips of the panel outside the game
//   node scripts/interface/equipment/tests/logic.test.cjs
// The parts are plain enough script to run in node with a few stand-ins for SkyUI and the menu

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const source = path.join(__dirname, "..", "source");
const parts = ["10-core.as", "12-compare.as", "20-rows.as", "21-marks.as", "22-sorting.as", "24-subcategories.as", "26-draw.as", "27-queue.as", "28-junk.as", "28-junk-ask.as", "29-chip-menu.as", "30-panel.as", "31-strip.as", "33-context.as", "34-drag.as", "35-models.as", "36-window.as", "36-long-words.as", "36-made-of.as", "37-inspect.as", "38-stats.as", "38-hero.as", "38-look.as", "39-row-menu.as", "39-gamepad.as", "39-card-numbers.as", "39-companions.as", "39-magic.as", "39-crafting.as", "39-cancel.as"];
// PANEL_CALLS=1 runs the same tests on the parts the way the debug build puts them in the movie, with a call at the
// start and every way out of each function. They have to pass all the same, that's the proof the pass keeps what
// the panel does
const withCalls = process.env.PANEL_CALLS === "1" ? require("./calls.cjs").panel(parts.map((part) => path.join(source, part))) : undefined;

function freshPanel(sides, words, stage) {
   const context = {
      _global: {},
      skse: {plugins: {}},
      // what the game shows of the stage of a 1280x720 menu that keeps its proportions, unless a test gives another
      Stage: stage || {visibleRect: {x: 0, y: 0, width: 1280, height: 720}, safeRect: {x: 0, y: 0}},
      Math, String, Number, Array,
      getTimer: () => Date.now(),
      MovieClip: function() {},
      TextField: function() {},
      Mouse: {addListener: () => undefined},
      _root: {_xmouse: 0, _ymouse: 0},
      skyui: {util: {Translator: {translate: (key) => words && words[key] !== undefined ? words[key] : key}}, defines: {Input: {XButton: {name: "XButton"}}}},
      // what gfx.managers.InputDelegate of SkyUI names the moves and buttons
      gfx: {ui: {NavigationCode: {UP: "up", DOWN: "down", LEFT: "left", RIGHT: "right", ENTER: "enter-gamepad_A", ESCAPE: "escape-gamepad_B", TAB: "tab", SHIFT_TAB: "shifttab"}}},
      Shared: {GlobalFunc: {IsKeyPressed: (details, held) => details.value == "keyDown" || (held === undefined || held) && details.value == "keyHold"}},
   };
   context._global.EquipmentPanelMenu = "inventory";
   vm.createContext(context);
   if (withCalls) {
      withCalls.load(context);
   } else {
      for (const part of parts) {
         vm.runInContext(fs.readFileSync(path.join(source, part), "utf8"), context, {filename: part});
      }
   }
   const Equipment = context._global.Equipment;
   // the stand-ins a test changes on the way: the pointer, the clock, what lies under the pointer
   freshPanel.context = context;
   const categories = sides ? [{flag: 2048}, {flag: 4096}, {flag: 0}, {flag: 2}, {flag: 4}] : [{flag: 1}, {flag: 1023}, {flag: 2}, {flag: 4}];
   Equipment.menu = {inventoryLists: {
      categoryList: {entryList: categories, dividerIndex: sides ? 2 : -1},
      _typeFilter: {isMatch: (entry, flag) => entry.side === undefined || entry.side === flag},
   }};
   return Equipment;
}

let failed = 0;
let passed = 0;
function expect(name, got, wanted) {
   const same = wanted === undefined ? got === undefined : Math.abs(got - wanted) < 1e-6;
   if (same) {
      passed++;
   } else {
      failed++;
      console.log(`FAIL ${name}: got ${got}, wanted ${wanted}`);
   }
}

const W = {WEAPON: 41, ARMOR: 26, AMMO: 42, LIGHT: 31};
const sword = (damage, worn) => ({formType: W.WEAPON, subType: 1, infoDamage: damage, equipState: worn || 0});
const dagger = (damage, worn) => ({formType: W.WEAPON, subType: 2, infoDamage: damage, equipState: worn || 0});
const greatsword = (damage, worn) => ({formType: W.WEAPON, subType: 5, infoDamage: damage, equipState: worn || 0});
const bow = (damage, worn) => ({formType: W.WEAPON, subType: 8, infoDamage: damage, equipState: worn || 0});
const crossbow = (damage, worn) => ({formType: W.WEAPON, subType: 9, infoDamage: damage, equipState: worn || 0});
const staff = (worn) => ({formType: W.WEAPON, subType: 10, infoDamage: null, equipState: worn || 0});
const arrow = (damage, worn) => ({formType: W.AMMO, subType: 0, infoDamage: damage, equipState: worn || 0});
const bolt = (damage, worn) => ({formType: W.AMMO, subType: 1, infoDamage: damage, equipState: worn || 0});
const armor = (mask, rating, worn, extra) => Object.assign({formType: W.ARMOR, partMask: mask, infoArmor: rating, equipState: worn || 0}, extra || {});
const torch = (worn) => ({formType: W.LIGHT, equipState: worn || 0});

function difference(rows, item) {
   const Equipment = freshPanel(false);
   const all = rows.concat([item]);
   return Equipment.difference(item, Equipment.worn(all, undefined), undefined);
}

// ammo counts only while something that shoots it is in the hands
expect("arrow, empty hands", difference([], arrow(10)), undefined);
expect("arrow, sword in hand", difference([sword(8, 3)], arrow(10)), undefined);
expect("arrow, bow and no arrows worn", difference([bow(9, 3)], arrow(10)), 10);
expect("arrow, bow and iron arrows worn", difference([bow(9, 3), arrow(8, 1)], arrow(10)), 2);
expect("arrow, bow and bolts worn", difference([bow(9, 3), bolt(12, 1)], arrow(10)), 10);
expect("bolt, bow in hand", difference([bow(9, 3)], bolt(12)), undefined);
expect("bolt, crossbow and arrows worn", difference([crossbow(19, 3), arrow(8, 1)], bolt(12)), 12);
expect("bolt, crossbow and bolts worn", difference([crossbow(19, 3), bolt(10, 1)], bolt(12)), 2);
expect("arrow, crossbow in hand", difference([crossbow(19, 3)], arrow(10)), undefined);
expect("arrow, a bow in the left only is not how bows are held", difference([bow(9, 2)], arrow(10)), undefined);

// a bow against a bow, a melee weapon against a melee weapon
expect("bow, sword in hand", difference([sword(8, 3)], bow(12)), undefined);
expect("bow, bow in hand", difference([bow(9, 3)], bow(12)), 3);
expect("crossbow, bow in hand", difference([bow(9, 3)], crossbow(19)), 10);
expect("sword, bow in hand", difference([bow(9, 3)], sword(10)), undefined);
expect("sword, empty hands", difference([], sword(10)), undefined);
expect("sword, sword in right", difference([sword(8, 3)], sword(10)), 2);
expect("sword, dagger in left only", difference([dagger(4, 2)], sword(10)), 6);
expect("greatsword, sword in right", difference([sword(8, 3)], greatsword(18)), 10);
expect("sword, greatsword in both", difference([greatsword(18, 4)], sword(10)), -8);
expect("sword, staff in right and dagger in left", difference([staff(3), dagger(4, 2)], sword(10)), 6);
expect("sword, only a staff", difference([staff(3)], sword(10)), undefined);
expect("staff, sword in hand", difference([sword(8, 3)], staff()), undefined);
expect("torch", difference([sword(8, 3)], torch()), undefined);
expect("worn row", difference([], sword(10, 3)), undefined);

// armor against what it would replace by slot mask
expect("helmet over helmet", difference([armor(1, 15, 1)], armor(1, 20)), 5);
expect("helmet over nothing", difference([], armor(1, 20)), 20);
expect("cuirass over cuirass", difference([armor(4, 30, 1), armor(1, 15, 1)], armor(4, 25)), -5);
expect("circlet with no armor over a helmet that takes both head bits", difference([armor(1 | 4096, 15, 1)], armor(4096, 0)), -15);
expect("ring over nothing, no armor either side", difference([], armor(64, 0)), 0);
expect("shield over shield", difference([armor(512, 20, 1)], armor(512, 24)), 4);
expect("clothes over armor", difference([armor(4, 30, 1)], armor(4, 0)), -30);

// in a container only the player's side counts as worn
{
   const Equipment = freshPanel(true);
   const players = armor(1, 15, 1, {side: 2});
   const bodys = armor(1, 30, 1, {side: 2048});
   const shown = armor(1, 22, 0, {side: 2048});
   const rows = [players, bodys, shown];
   const flags = Equipment.ownFlags();
   const worn = Equipment.worn(rows, flags);
   expect("container, the body's helmet is not worn by the player", worn.armor.length, 1);
   expect("container, a helmet of the body is compared with the player's", Equipment.difference(bodys, worn, flags), 15);
   expect("container, the player's own worn row has no mark", Equipment.difference(players, worn, flags), undefined);
   expect("container, a helmet of the chest", Equipment.difference(shown, worn, flags), 7);
}

// chips
{
   const Equipment = freshPanel(false);
   const holds = (key, entry) => Equipment.chipHolds(key, entry) ? 1 : 0;
   expect("chip one handed, sword", holds("oneHanded", sword(8)), 1);
   expect("chip one handed, staff is not", holds("oneHanded", staff()), 0);
   expect("chip one handed, greatsword is not", holds("oneHanded", greatsword(18)), 0);
   expect("chip two handed, greatsword", holds("twoHanded", greatsword(18)), 1);
   expect("chip bows, crossbow", holds("ranged", crossbow(19)), 1);
   expect("chip staves, staff", holds("staff", staff()), 1);
   expect("chip ammo, bolt", holds("ammo", bolt(10)), 1);
   expect("chip light, light helmet", holds("light", armor(1, 10, 0, {weightClass: 0})), 1);
   expect("chip light, light shield is a shield", holds("light", armor(512, 10, 0, {weightClass: 0})), 0);
   expect("chip heavy, heavy cuirass", holds("heavy", armor(4, 30, 0, {weightClass: 1})), 1);
   expect("chip clothing", holds("clothing", armor(4, 0, 0, {weightClass: 3})), 1);
   expect("chip jewelry", holds("jewelry", armor(64, 0, 0, {weightClass: 4})), 1);
   expect("chip shields", holds("shield", armor(512, 20, 0, {weightClass: 1})), 1);
   expect("chip head, helmet", holds("head", armor(1, 10, 0)), 1);
   expect("chip head, circlet", holds("head", armor(4096, 0, 0)), 1);
   expect("chip feet, boots", holds("feet", armor(128, 5, 0)), 1);
   expect("chip hands, gauntlets", holds("hands", armor(8, 5, 0)), 1);
   expect("chip body, cuirass", holds("body", armor(4, 30, 0)), 1);
   expect("chip other, cloak", holds("other", armor(65536, 0, 0)), 1);
   expect("chip other, ring", holds("other", armor(64, 0, 0)), 1);
   expect("chip body, shield is not", holds("body", armor(512, 20, 0)), 0);

   // two rows add up
   Equipment.chosenChips = ["heavy", "head"];
   const rows = [armor(1, 20, 0, {weightClass: 1}), armor(1, 10, 0, {weightClass: 0}), armor(4, 30, 0, {weightClass: 1})];
   Equipment.chipFilter.applyFilter(rows);
   expect("heavy and head leave one heavy helmet", rows.length, 1);
   expect("the one left is the heavy helmet", rows[0].infoArmor, 20);
   Equipment.chosenChips = [undefined, "body"];
   const more = [armor(1, 20, 0, {weightClass: 1}), armor(4, 30, 0, {weightClass: 1}), armor(4, 0, 0, {weightClass: 3})];
   Equipment.chipFilter.applyFilter(more);
   expect("only the second row: every body piece", more.length, 2);
   // a slot's filter keeps the rows that fit it in their order
   const fitsBefore = Equipment.fits;
   Equipment.activeSlot = {name: "head"};
   Equipment.fits = (entry) => entry.partMask == 1;
   const slotRows = [armor(1, 20, 0), armor(4, 30, 0), armor(1, 10, 0), armor(8, 5, 0)];
   Equipment.slotFilter.applyFilter(slotRows);
   expect("the slot keeps its two helmets", slotRows.length, 2);
   expect("in their order", slotRows[0].infoArmor * 100 + slotRows[1].infoArmor, 2010);
   Equipment.activeSlot = undefined;
   Equipment.fits = fitsBefore;

   // the strip takes a row's height from the list, the rows that fit are counted again (SkyUI counts them only when
   // the columns are laid out)
   const list = {_y: 100, listHeight: 600, entryHeight: 30, _maxListIndex: 20, requestUpdate() {}};
   Equipment.menu.inventoryLists.itemList = list;
   Equipment.menu.updateDynamicListHeight = () => { list.listHeight = 700 - list._y; };
   Equipment.roomHigh = 0;
   Equipment.openStrip(true);
   expect("the strip moves the list down", list._y, 100 + Equipment.STRIP_HIGH);
   expect("one row less fits under the strip", list._maxListIndex, 19);
   Equipment.openStrip(false);
   expect("the row comes back when the strip goes", list._maxListIndex, 20);
   Equipment.menu.updateDynamicListHeight = undefined;
   Equipment.openStrip(true);
   expect("a menu that can't fit its list is cut by hand", list.listHeight, 570);
   expect("and counts its rows too", list._maxListIndex, 19);
   delete Equipment.roomHigh;
   list._y = 100;
   list.listHeight = 600;
   list._maxListIndex = 20;
   Equipment.openStrip(false);
   expect("a menu that opens with no strip keeps its height", list.listHeight, 600);
   expect("and its rows", list._maxListIndex, 20);
   delete Equipment.menu.updateDynamicListHeight;
   delete Equipment.menu.inventoryLists.itemList;

   // slot fit
   const left = Equipment.slotNamed("left");
   expect("left takes a dagger", Equipment.fits(dagger(4), left) ? 1 : 0, 1);
   expect("left takes a shield", Equipment.fits(armor(512, 20), left) ? 1 : 0, 1);
   expect("left takes a torch", Equipment.fits(torch(), left) ? 1 : 0, 1);
   expect("left takes no greatsword", Equipment.fits(greatsword(18), left) ? 1 : 0, 0);
   expect("left takes no bow", Equipment.fits(bow(9), left) ? 1 : 0, 0);
   expect("left takes a staff", Equipment.fits(staff(), left) ? 1 : 0, 1);
   expect("left takes a pickaxe", Equipment.fits({formType: W.WEAPON, subType: 11}, left) ? 1 : 0, 1);
   expect("right takes a bow", Equipment.fits(bow(9), Equipment.slotNamed("right")) ? 1 : 0, 1);
   expect("head takes a circlet", Equipment.fits(armor(4096, 0), Equipment.slotNamed("head")) ? 1 : 0, 1);
   expect("ammo takes a bolt", Equipment.fits(bolt(10), Equipment.slotNamed("ammo")) ? 1 : 0, 1);
}

// weapon numbers against the weapon in the hands, the pairs of the row arrows: melee with melee, a bow with a bow
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const stats = {
      1: {kind: "weapon", speed: 1, speedMult: 1, leftSpeedMult: 1, reach: 1, stagger: 0.75, critDamage: 0},
      2: {kind: "weapon", speed: 1.3, speedMult: 1, leftSpeedMult: 1, reach: 0.7, stagger: 0.75, critDamage: 5},
      3: {kind: "weapon", speed: 1, speedMult: 1, leftSpeedMult: 1, reach: 1, stagger: 0, critDamage: 3},
   };
   Equipment.plugin = () => ({Stats: (formId) => stats[formId]});
   const lineOf = (lines, name) => {
      const line = lines.find((one) => one[0] === name);
      return line === undefined ? "missing" : line[1] + (line[2] ? " " + line[2].role + " " + Equipment.bracketed(line[2]) : "");
   };
   const held = Object.assign(sword(8, 1), {formId: 2});
   const longer = Object.assign(sword(10), {formId: 1});
   Equipment.wornNow = {armor: [], right: held};
   const lines = Equipment.statsOf(longer);
   said("a slower sword lands later", lineOf(lines, "Swing"), "0.7 s worse (+0.16)");
   said("the faster held sword hits more a second", lineOf(lines, "DPS"), "~8.3 worse (-0.3)");
   said("a longer blade reaches farther", lineOf(lines, "Reach"), "1.00 better (+0.3)");
   said("the same stagger is equal", lineOf(lines, "Stagger"), "0.75 equal (=)");
   said("crit damage the held one has and this one lacks", lineOf(lines, "Crit damage"), "0 worse (-5)");
   Equipment.settings = {numbersOff: 1 << 1 | 1 << 3};
   const fewer = Equipment.statsOf(longer);
   said("damage a second switched off on its own", lineOf(fewer, "DPS"), "missing");
   said("reach too", lineOf(fewer, "Reach"), "missing");
   said("the rest stays", lineOf(fewer, "Stagger") + ", " + fewer.length, "0.75 equal (=), 4");
   Equipment.settings = undefined;

   said("the sword in the hands is weighed against nothing", lineOf(Equipment.statsOf(held), "Reach"), "0.7");
   const longbow = Object.assign(bow(9), {formId: 3});
   said("a bow against a sword in the hands says no change", lineOf(Equipment.statsOf(longbow), "Draw"), "1.00 s");
   said("a change goes into brackets in its ink", Equipment.valueHtml("1.00", Equipment.change(0.3, 2, 1)), "<font color='" + Equipment.hex(Equipment.inkOf("value")) + "'>1.00</font> <font color='" + Equipment.hex(Equipment.inkOf("better")) + "'>(+0.3)</font>");

   // the worn arrows count for the held bow only, a crossbow's damage a second would lose to them
   Equipment.wornNow = {armor: [], right: Object.assign(bow(9, 1), {formId: 3}), ammo: Object.assign(arrow(10, 1), {text: "Iron Arrow"})};
   const heavyBow = Object.assign(crossbow(19), {formId: 3});
   said("a crossbow against a bow with arrows says no change of its damage a second", lineOf(Equipment.statsOf(heavyBow), "DPS"), "~7.6");
   said("but still of its draw", lineOf(Equipment.statsOf(heavyBow), "Draw"), "1.00 s equal (=)");
   said("another bow counts the same arrows", lineOf(Equipment.statsOf(Object.assign(bow(12), {formId: 3})), "DPS (with Iron Arrow)"), "~12.2 better (+1.7)");
}

// a body's worn things are things to take, weighed against what the player wears
{
   const Equipment = freshPanel(true);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const told = {armorScale: 0.12, armorBase: 0.03, armorCap: 80};
   Equipment.kind = "container";
   Equipment.subject = {player: true};
   const mine = armor(4, 27, 1, {weightClass: 1, side: 2});
   const onBody = armor(4, 40, 1, {weightClass: 1, side: 2048});
   Equipment.wornNow = {armor: [mine]};
   const lines = Equipment.armorStats(onBody, told);
   said("a body's cuirass says what it would stop", lines[0][0], "Would stop");
   said("what it stops in place of the player's one", lines[0][1], "7.8% of a hit");
   said("and in brackets how much more than the player's", lines[0][2].text, "+1.6%");
   said("in the ink of better", lines[0][2].role, "better");
   said("the player's own cuirass still says what it stops", Equipment.armorStats(mine, told)[0][0], "Stops");
}

// a list that scrolls smoothly keeps its rows one clip deeper, the row under the pointer is still found
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const list = Equipment.menu.inventoryLists.itemList = {entryList: [{text: "Iron Sword"}, {text: "Steel Armor"}]};
   const holder = {_parent: list};
   const row = {_parent: holder, itemIndex: 1, _visible: true};
   freshPanel.context.Mouse.getTopMostEntity = () => ({_parent: row});
   said("a row inside the list's own holder", Equipment.rowUnderMouse().text, "Steel Armor");
   row._parent = list;
   said("a row right in the list", Equipment.rowUnderMouse().text, "Steel Armor");
   row._parent = {};
   said("a clip of another list is no row", Equipment.rowUnderMouse(), undefined);
}

// a line too long for its column is cut with dots, one that fits stays whole
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const letters = (words) => words.length * 10;
   said("a short line stays", Equipment.cutToFit("DPS", 100, letters), "DPS");
   said("a long one is cut to fit with its dots", Equipment.cutToFit("DPS (with Ancient Nord Arrow)", 100, letters), "DPS (wi...");
   said("an endless room cuts nothing", Equipment.cutToFit("DPS (with Ancient Nord Arrow)", Infinity, letters), "DPS (with Ancient Nord Arrow)");

   // the tabs' names share the doll's room, the short ones keep their width
   const pads = 2 * Equipment.COMPANION_PAD + Equipment.COMPANION_GAP;
   said("names that fit have no limit", Equipment.namesRoom([30, 60, 60], 500), Infinity);
   said("long names share what the short one leaves", Equipment.namesRoom([30, 200, 200], 300 - Equipment.COMPANION_GAP + 3 * pads), 135);
}

// armor numbers: rating times the scale plus a share for each worn piece of armor, up to the cap
{
   const Equipment = freshPanel(false);
   const told = {armorScale: 0.12, armorBase: 0.03, armorCap: 80};
   const heavy = (mask, rating, worn) => armor(mask, rating, worn, {weightClass: 1});
   const percentOf = (lines, name) => parseFloat(lines.find((line) => line[0] === name)[1]);
   const four = [heavy(4, 300, 1), heavy(1, 100, 1), heavy(8, 84, 1), heavy(128, 83, 1)];
   Equipment.wornNow = {armor: four};
   expect("567 with four pieces is the cap", percentOf(Equipment.armorStats(four[0], told), "Whole set"), 80);

   const set = [heavy(4, 27, 1), heavy(1, 16, 1), heavy(8, 8, 1), heavy(128, 11, 1)];
   Equipment.wornNow = {armor: set};
   const worn = Equipment.armorStats(set[0], told);
   expect("62 rating and four pieces stop 19.4%", percentOf(worn, "Whole set"), 19.4);
   expect("a worn cuirass adds its rating and its piece", percentOf(worn, "Stops"), 6.2);

   const ring = armor(64, 0, 0, {weightClass: 4});
   expect("a ring with no armor says nothing", Equipment.armorStats(ring, told).length, 0);

   const better = heavy(4, 40, 0);
   expect("a cuirass in place of the worn one says what it stops itself", percentOf(Equipment.armorStats(better, told), "Would stop"), 7.8);

   const shield = armor(512, 20, 0, {weightClass: 1});
   expect("a shield into an empty hand adds a piece too", percentOf(Equipment.armorStats(shield, told), "Would stop"), 20 * 0.12 + 3);

   const worse = heavy(4, 20, 0);
   expect("a worse cuirass says what it would stop", percentOf(Equipment.armorStats(worse, told), "Would stop"), 5.4);

   // a piece that isn't worn colours its change, a worn one says what it adds without a colour
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const roleOf = (lines, name) => {
      const line = lines.find((one) => one[0] === name);
      return line && line[2] ? line[2].role + (line[2].text !== undefined ? " " + line[2].text : "") : "none";
   };
   const lighter = armor(4, 27, 0, {weightClass: 1, infoWeight: 15});
   set[0].infoWeight = 30;
   const lighterLines = Equipment.armorStats(lighter, told);
   said("the same rating stops the same", roleOf(lighterLines, "Would stop"), "equal =");
   said("half the weight doubles the armor per weight", roleOf(lighterLines, "Armor per weight"), "better +0.9");
   said("a better cuirass says how much more in brackets", roleOf(Equipment.armorStats(heavy(4, 40, 0), told), "Would stop"), "better +1.6%");
   said("a worse cuirass says how much less", roleOf(Equipment.armorStats(worse, told), "Would stop"), "worse -0.8%");
   said("and its effective health too", roleOf(Equipment.armorStats(worse, told), "Effective health"), "worse -1.0%");
   said("a shield into an empty hand has nothing to compare with", roleOf(Equipment.armorStats(shield, told), "Would stop"), "none");
   said("a worn cuirass has no colour", roleOf(Equipment.armorStats(set[0], told), "Stops"), "none");

   // the plugin asks the game's own sum, a mod that rewrote it counts its way: Armor Rating Rescaled at scale 1
   const plugin = Equipment.plugin;
   const rescaled = (rating, hidden) => {
      const own = rating * 0.12 / 100 * 5 / (1 + rating * 0.12 / 100 * 5);
      return own + hidden * (1 - own);
   };
   Equipment.plugin = () => ({ArmorStops: rescaled});
   expect("62 rating and four pieces rescaled stop 35.9%", percentOf(Equipment.armorStats(set[0], told), "Whole set"), 35.9);
   expect("the share the character sheet takes too", Math.round(Equipment.armorShare(62, 4, told) * 1000) / 10, 35.9);
   Equipment.plugin = () => ({ArmorStops: () => undefined});
   expect("no answer of the game counts by the settings", percentOf(Equipment.armorStats(set[0], told), "Whole set"), 19.4);
   Equipment.plugin = plugin;

   // a slot filter puts chosen chips aside, a mod's piece without keywords still finds its chip
   Equipment.chosenChips = ["light"];
   Equipment.activeSlot = Equipment.slotNamed("ring");
   const ringRows = [armor(64, 0, 0, {weightClass: 4}), armor(64, 0, 0)];
   Equipment.chipFilter.applyFilter(ringRows);
   expect("a slot filter keeps rows a chip would drop", ringRows.length, 2);
   Equipment.activeSlot = undefined;
   expect("a ring without keywords counts as jewelry", Equipment.chipHolds("jewelry", armor(64, 0, 0)) ? 1 : 0, 1);
   expect("a robe without keywords counts as clothing", Equipment.chipHolds("clothing", armor(4, 0, 0)) ? 1 : 0, 1);
   expect("a ring without keywords is no clothing", Equipment.chipHolds("clothing", armor(64, 0, 0)) ? 1 : 0, 0);
}

// subcategories of potions, food, books and things, by the kinds SkyUI tells
{
   const Equipment = freshPanel(false);
   const holds = (key, entry) => Equipment.chipHolds(key, entry) ? 1 : 0;
   const potion = (subType) => ({formType: 46, subType});
   const book = (subType) => ({formType: 27, subType});
   const thing = (subType) => ({formType: 32, subType});
   expect("a health potion is health", holds("health", potion(0)), 1);
   expect("a health potion is no other", holds("otherPotion", potion(0)), 0);
   expect("a regeneration of magicka is magicka", holds("magicka", potion(4)), 1);
   expect("a fire resistance is other", holds("otherPotion", potion(9)), 1);
   expect("a poison is a poison", holds("poison", potion(15)), 1);
   expect("a poison is no other", holds("otherPotion", potion(15)), 0);
   expect("mead is a drink", holds("drink", potion(13)), 1);
   expect("bread is food", holds("meal", potion(14)), 1);
   expect("a note is a note", holds("note", book(1)), 1);
   expect("a recipe counts as a note", holds("note", book(2)), 1);
   expect("a note is no book", holds("book", book(1)), 0);
   expect("a plain book is a book", holds("book", book(undefined)), 1);
   expect("a spell tome", holds("spellTome", book(0)), 1);
   expect("a treasure map", holds("map", book(3)), 1);
   expect("iron ore", holds("ore", thing(31)), 1);
   expect("an ingot", holds("ingot", thing(7)), 1);
   expect("a ruby", holds("gem", thing(0)), 1);
   expect("a pelt", holds("pelt", thing(5)), 1);
   expect("leather goes with pelts", holds("pelt", thing(3)), 1);
   expect("a soul gem", holds("soulGem", {formType: 52}), 1);
   expect("a soul gem is no other", holds("otherMisc", {formType: 52}), 0);
   expect("clutter is other", holds("otherMisc", thing(19)), 1);
   expect("a torch in misc is other", holds("otherMisc", torch()), 1);
   const oldMenu = (made, formId) => Object.assign(made, {formId});
   expect("iron ore an older menu calls an ingot", holds("ore", oldMenu(thing(7), 0x71CF3)), 1);
   expect("and it is no ingot then", holds("ingot", oldMenu(thing(7), 0x71CF3)), 0);
   expect("a real ingot stays one", holds("ingot", oldMenu(thing(7), 0x5ACE4)), 1);
   expect("a treasure map an older menu calls a note", holds("map", oldMenu(book(1), 996303)), 1);
   expect("and it is no note then", holds("note", oldMenu(book(1), 996303)), 0);
   expect("a torch is no ore", holds("ore", torch()), 0);
   const family = (flag) => Equipment.chipFamily(flag) || "none";
   expect("potions of a container", family(8192) === "potions" ? 1 : 0, 1);
   expect("books of a container", family(131072) === "books" ? 1 : 0, 1);
   expect("misc of the inventory", family(512) === "misc" ? 1 : 0, 1);
   expect("food of a container", family(32768) === "food" ? 1 : 0, 1);
   expect("all has its junk", family(1023) === "all" ? 1 : 0, 1);
   expect("all of a container too", family(1047552) === "all" ? 1 : 0, 1);
}

// under a slot filter only the subcategories that split what fits the slot are offered
{
   const Equipment = freshPanel(false);
   const helmets = [armor(1, 20, 0, {weightClass: 1}), armor(1, 12, 0, {weightClass: 0}), armor(2, 0, 0, {weightClass: 3}), armor(4, 30, 0, {weightClass: 1})];
   Equipment.menu.inventoryLists.itemList = {entryList: helmets};
   Equipment.menu.inventoryLists.categoryList.selectedEntry = {flag: 4};
   Equipment.activeSlot = Equipment.slotNamed("head");
   const splits = (key) => Equipment.splitsSlot(key) ? 1 : 0;
   expect("heavy splits the helmets", splits("heavy"), 1);
   expect("clothing splits the helmets", splits("clothing"), 1);
   expect("head holds every helmet and splits nothing", splits("head"), 0);
   expect("jewelry holds no helmet", splits("jewelry"), 0);
   expect("the cuirass doesn't count for the head", splits("body"), 0);
}

// the menu of a row offers what the menu it's in can do with the row
{
   const menuOf = (kind, side, charge) => {
      const Equipment = freshPanel(false);
      Equipment.kind = kind;
      Equipment.settings = {};
      Equipment.viewer = kind == "inventory" ? {} : undefined;
      Equipment.inspectable = () => true;
      Equipment.menu.itemCard = {itemInfo: {charge}};
      Equipment.menu.isViewingContainer = () => side;
      Equipment.menu.isViewingVendorItems = () => side;
      return (entry) => Equipment.rowLines(entry).filter((line) => line.key !== "-").map((line) => line.words).join(" | ");
    };
   const said = (name, got, wanted) => {
      if (got === wanted) {
         passed++;
      } else {
         failed++;
         console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`);
      }
   };
   const counted = (entry, count) => Object.assign(entry, {count});
   const potion = (count) => ({formType: 46, count, equipState: 0});
   said("inventory, a sword", menuOf("inventory")(counted(sword(8), 1)), "Equip | Equip in left hand | Drop | Add to favorites | Inspect");
   said("inventory, a sword in the left hand", menuOf("inventory")(counted(sword(8, 2), 1)), "Take off | Drop | Add to favorites | Inspect");
   said("inventory, a greatsword has no left hand", menuOf("inventory")(counted(greatsword(18), 1)), "Equip | Drop | Add to favorites | Inspect");
   said("inventory, five potions", menuOf("inventory")(potion(5)), "Use | Drop one | Drop all (5) | Drop some... | Add to favorites | Inspect");
   said("inventory, an ingredient is eaten", menuOf("inventory")({formType: 30, count: 1, equipState: 0}), "Eat | Drop | Add to favorites | Inspect");
   said("inventory, a book is read", menuOf("inventory")({formType: 27, count: 1, equipState: 0}), "Read | Drop | Add to favorites | Inspect");
   said("inventory, a worn favorite helmet", menuOf("inventory")(Object.assign(armor(1, 16, 1), {count: 1, favorite: true})), "Take off | Drop | Remove from favorites | Inspect");
   said("inventory, a drained sword can be recharged", menuOf("inventory", false, 40)(counted(sword(8), 1)), "Equip | Equip in left hand | Recharge | Drop | Add to favorites | Inspect");
   said("container side, two arrows", menuOf("container", true)(counted(arrow(8), 2)), "Take one | Take all (2)");
   said("own side of a container, a greatsword", menuOf("container", false)(counted(greatsword(18), 1)), "Equip | Store | Add to favorites");
   said("a shop's three potions", menuOf("barter", true)(potion(3)), "Buy one | Buy all (3) | Buy some...");
   said("own side of a shop, a sword", menuOf("barter", false)(counted(sword(8), 1)), "Sell");
}

// a window or a menu of a slot opens beside it toward the doll, from either column
{
   const Equipment = freshPanel();
   const named = (column, x, words) => ({column, box: {_x: x, label: {textWidth: words}}});
   const left = named(0, 880, 30);
   const right = named(1, 1780, 40);
   Equipment.SLOTS = [left, named(0, 880, 120), right, named(1, 1780, 50)];
   const size = Equipment.SLOT_SIZE;
   expect("left slot, beside it on the right, past the widest name", Equipment.besideSlot(left, 300), 880 + 124 + Equipment.POPUP_GAP);
   expect("right slot, beside it on the left", Equipment.besideSlot(right, 300), 1780 - Equipment.POPUP_GAP - 300);
   Equipment.SLOTS.push(named(1, 1780, 150));
   expect("right slot, past a long name of its column", Equipment.besideSlot(right, 300), 1780 + size - 154 - Equipment.POPUP_GAP - 300);
   Equipment.SLOTS.push(named(1, 1780, 400));
   expect("a name is never counted wider than its field", Equipment.besideSlot(right, 300), 1780 + size - Equipment.LABEL_WIDTH - Equipment.POPUP_GAP - 300);
}

// the pieces of a slot keep one order whatever the list's sort, so the slot shows the same one
{
   const Equipment = freshPanel(false);
   const piece = (form, bits, extra) => Object.assign(armor(bits.reduce((mask, bit) => mask | (1 << (bit - 30)), 0), 0, 1, {formId: form, text: "f" + form}), extra || {});
   const order = (rows, name) => {
      Equipment.place(Equipment.worn(rows, undefined));
      return Equipment.slotNamed(name).entries.map((entry) => entry.formId).join(",");
   };
   const bag = piece(1, [47]);
   const cloak = piece(2, [46]);
   const lamp = piece(3, [60]);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   said("other, a cloak first, then by body slot", order([lamp, bag, cloak], "other"), "2,1,3");
   said("other, the same order from another sort", order([bag, cloak, lamp], "other"), "2,1,3");
   said("head, the hood before the circlet", order([piece(5, [42]), piece(4, [31, 41])], "head"), "4,5");
   const real = piece(10, [36], {myPreciousesVanillaRingSlotEquipped: true});
   const finger = (form) => piece(form, [36], {myPreciousesVanillaRingSlotEquipped: false, equipState: 2});
   said("rings, the game's own finger first", order([finger(7), real, finger(6)], "ring"), "10,6,7");
   expect("a ring on a virtual finger", Equipment.virtualRing(finger(6)) ? 1 : 0, 1);
   expect("a ring without My Precious...es", Equipment.virtualRing(piece(8, [36])) ? 1 : 0, 0);
   expect("an unworn ring My Precious...es marked", Equipment.virtualRing(piece(9, [36], {myPreciousesVanillaRingSlotEquipped: false, equipState: 0})) ? 1 : 0, 0);

   // MARA takes the slots off jewelry, the keywords still place it
   const maraRing = (form) => armor(0, 0, 1, {formId: form, text: "r" + form, keywords: {ArmorJewelry: 1, gearMaraRing: 1}});
   const maraAmulet = (form) => armor(0, 0, 1, {formId: form, text: "a" + form, keywords: {ArmorJewelry: 1, gearMaraAmulet: 1}});
   said("MARA rings go to the ring slot", order([maraRing(21), maraRing(20), lamp], "ring"), "20,21");
   said("MARA amulets go to the neck slot", order([maraAmulet(31), maraAmulet(30)], "amulet"), "30,31");
   said("a slotless necklace of a mod by its keyword", order([armor(0, 0, 1, {formId: 40, keywords: {ClothingNecklace: 1}})], "amulet"), "40");
   said("other keeps only the lamp", order([maraRing(21), lamp], "other"), "3");
   const enchantableCloak = piece(41, [40, 46], {keywords: {ClothingNecklace: 1}});
   said("a cloak with the necklace keyword stays in other", order([enchantableCloak, maraAmulet(30)], "other"), "41");
   said("and the neck holds only the amulet", order([enchantableCloak, maraAmulet(30)], "amulet"), "30");
   let hung = [];
   Equipment.plugin = () => ({HungPieces: () => hung});
   Equipment.hiddenMask = 0;
   Equipment.hiddenPieces = [];
   Equipment.settings = {hideIcons: true, pieceStrips: true};
   order([maraRing(21), maraRing(20)], "ring");
   expect("a ring slot of MARA rings never seen hanging has no eye", Equipment.canToggle(Equipment.slotNamed("ring")) ? 1 : 0, 0);
   expect("nor a MARA ring in a strip", Equipment.canToggle({parent: Equipment.slotNamed("ring"), entries: [maraRing(20)], name: "ring"}) ? 1 : 0, 0);
   hung = [20];
   expect("once its copy was seen the slot has an eye", Equipment.canToggle(Equipment.slotNamed("ring")) ? 1 : 0, 1);
   expect("and so has that ring in the strip", Equipment.canToggle({parent: Equipment.slotNamed("ring"), entries: [maraRing(20)], name: "ring"}) ? 1 : 0, 1);
   expect("the other ring still has none", Equipment.canToggle({parent: Equipment.slotNamed("ring"), entries: [maraRing(21)], name: "ring"}) ? 1 : 0, 0);
   hung = [];
   order([real, finger(6)], "ring");
   expect("the game's own ring keeps the eye of the slot", Equipment.canToggle(Equipment.slotNamed("ring")) ? 1 : 0, 1);
   expect("an empty small slot has no eye", Equipment.canToggle({parent: Equipment.slotNamed("ring"), entries: [], plus: true, name: "ring"}) ? 1 : 0, 0);
   Equipment.hiddenMask = 1 << Equipment.slotIndex(Equipment.slotNamed("ring"));
   expect("a virtual ring in a hidden slot shows no shut eye, it stays on the finger", Equipment.canToggle({parent: Equipment.slotNamed("ring"), entries: [finger(6)], name: "ring"}) ? 1 : 0, 0);
   expect("the hidden slot keeps its eye to be shown again", Equipment.canToggle(Equipment.slotNamed("ring")) ? 1 : 0, 1);
   Equipment.hiddenMask = 0;
   Equipment.plugin = () => undefined;

   Equipment.settings = {pieceStrips: true};
   order([lamp, bag, cloak], "other");
   const other = Equipment.slotNamed("other");
   const mini = {parent: other, entries: [bag]};
   expect("three pieces pull out a strip", Equipment.hasPieces(other) ? 1 : 0, 1);
   expect("a small slot has no strip of its own", Equipment.hasPieces(mini) ? 1 : 0, 0);
   expect("a small slot takes what its slot takes", Equipment.fits(piece(11, [48]), mini) ? 1 : 0, 1);
   expect("a small slot of Other takes no helmet", Equipment.fits(piece(12, [30]), mini) ? 1 : 0, 0);
   order([cloak], "other");
   expect("one piece pulls out nothing", Equipment.hasPieces(other) ? 1 : 0, 0);
   Equipment.settings = {pieceStrips: false};
   order([lamp, bag, cloak], "other");
   expect("strips switched off", Equipment.hasPieces(other) ? 1 : 0, 0);
}

// a strip is one row that ends before the other column, past that it scrolls between two arrows
{
   const Equipment = freshPanel(false);
   const fit = (room, count) => { const told = Equipment.piecesFit(room, count); return told.shown + (told.scrolls ? " scrolls" : ""); };
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   said("four rings in a wide room", fit(950, 4), "4");
   said("as many as fit, no arrows", fit(950, 15), "15");
   said("one more needs the arrows, they take a piece's room", fit(950, 16), "14 scrolls");
   said("thirty rings on a wide screen", fit(950, 30), "14 scrolls");
   said("a narrow room still shows one", fit(150, 30), "1 scrolls");
}

// The tab of a slot with several pieces takes the press of a real mouse (under hitTestDisable beside the slot every
// press went through to the doll). The game's picking stands in here: a press lands on a visible text field whose
// clips are all visible and none of them under hitTestDisable
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const fakeClip = () => {
      const clip = {_x: 0, _y: 0, _visible: true, parts: []};
      clip.createEmptyMovieClip = (name) => (clip[name] = fakeClip(), clip.parts.push(clip[name]), clip[name]);
      clip.createTextField = (name, depth, x, y, wide, high) => (clip[name] = {_x: x, _y: y, _width: wide, _height: high}, clip.parts.push(clip[name]), clip[name]);
      ["clear", "lineStyle", "beginFill", "endFill", "moveTo", "lineTo", "curveTo"].forEach((name) => clip[name] = () => undefined);
      return clip;
   };
   const takesMouse = (clip, x, y) => clip._visible && !clip.hitTestDisable && clip.parts.some((part) => part.parts !== undefined
      ? takesMouse(part, x - part._x, y - part._y)
      : x >= part._x && x <= part._x + part._width && y >= part._y && y <= part._y + part._height);
   // the pointer at a place of the slot, every part of it reads the pointer in its own space
   const pointAt = (box, x, y) => [box, box.tab, box.eye].forEach((clip) => { clip._xmouse = x - (clip === box ? 0 : clip._x); clip._ymouse = y - (clip === box ? 0 : clip._y); });
   const pressed = [];
   Object.assign(Equipment, {panel: fakeClip(), settings: {pieceStrips: true}, pieceStrip: {}});
   Equipment.showSlot = Equipment.styleText = Equipment.roundBox = () => undefined;
   Equipment.openPieces = (slot) => pressed.push("strip " + slot.name);
   Equipment.toggleHidden = (slot) => pressed.push("eye " + slot.name);
   Equipment.click = (slot) => pressed.push("slot " + slot.name);
   const size = Equipment.SLOT_SIZE;
   const middle = (size - Equipment.TAB_HIGH) / 2 + Equipment.TAB_HIGH / 2;
   const rings = [{formId: 1}, {formId: 2}, {formId: 3}];
   [["ring", size + Equipment.TAB_GAP + Equipment.TAB_WIDE / 2, size + 1], ["other", -Equipment.TAB_GAP - Equipment.TAB_WIDE / 2, -1]].forEach(([name, onTab, inGap]) => {
      const slot = Equipment.slotNamed(name);
      Equipment.buildSlot(slot, 1);
      slot.entries = rings;
      Equipment.drawTab(slot);
      const box = slot.box;
      said(name + " has a tab", box.tab._visible, true);
      said("a press on the " + name + " tab comes to the slot", takesMouse(box, onTab, middle), true);
      said("so does a press in the gap between the " + name + " slot and its tab", takesMouse(box, inGap, middle), true);
      pointAt(box, onTab, middle);
      box.onPress();
      pointAt(box, inGap, middle);
      box.onPress();
      pointAt(box, size / 2, size / 2);
      box.onPress();
      box.eye._visible = true;
      pointAt(box, box.eye._x + 2, box.eye._y + 2);
      box.onPress();
   });
   said("tab, gap, middle and eye of both columns", pressed.join(", "), "strip ring, strip ring, slot ring, eye ring, strip other, strip other, slot other, eye other");
   const ring = Equipment.slotNamed("ring");
   ring.entries = [rings[0]];
   Equipment.drawTab(ring);
   pressed.length = 0;
   pointAt(ring.box, size + Equipment.TAB_GAP + Equipment.TAB_WIDE / 2, middle);
   ring.box.onPress();
   said("one piece left, the hidden tab's place is no tab", pressed.join(", "), "slot ring");
}

// With one strip out a press on the tab of another slot pulls out that slot's strip, and the click that closes a
// strip on a press outside it leaves the new one out, whether its listener hears the press before or after the tab
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const ring = Equipment.slotNamed("ring");
   const other = Equipment.slotNamed("other");
   let closed = 0;
   Object.assign(Equipment, {context: {_visible: false}, anchorSlot: {}, contextSlot: {}});
   Equipment.pressOnPieces = () => false;
   Equipment.closePieces = () => { closed++; Equipment.pieceStrip = undefined; };
   Equipment.buildPieces();
   const click = (opens) => { Equipment.piecesMouse.onMouseDown(); opens(); Equipment.piecesMouse.onMouseUp(); };
   Equipment.pieceStrip = {slot: ring};
   click(() => { Equipment.pieceStrip = {slot: other}; });
   said("the other slot's strip stays out", closed + " " + Equipment.pieceStrip.slot.name, "0 other");
   Equipment.pieceStrip = {slot: ring};
   click(() => { Equipment.pieceStrip = {slot: ring}; });
   said("the same slot's strip made again from the list still goes in on a click outside", closed + " " + Equipment.pieceStrip, "1 undefined");
   Equipment.pieceStrip = {slot: ring};
   click(() => undefined);
   said("a plain click outside puts it back", closed + " " + Equipment.pieceStrip, "2 undefined");
}

// a window of the strip opens over the strip when there's room there, under it otherwise
{
   const Equipment = freshPanel(false);
   const slot = {column: 1, row: 4, box: {_x: 1780, _y: 900}};
   const mini = {parent: slot, column: 1, box: {_x: 1600, _y: 907}};
   const window = {wide: 300, high: 400};
   Equipment.frame = {left: 900, right: 1844, top: 40, bottom: 990};
   Equipment.pieceStrip = {slot, left: 1500, top: 900, wide: 280, high: 64};
   expect("over the strip", Equipment.placeByPieces(mini, window, 1000) ? window._y : -1, 900 - Equipment.POPUP_GAP - 400);
   expect("its right edge on the small slot's", window._x, 1600 + Equipment.MINI_SIZE - 300);
   Equipment.pieceStrip = {slot, left: 1500, top: 120, wide: 280, high: 64};
   Equipment.placeByPieces(mini, window, 1000);
   expect("under a strip high on the screen", window._y, 120 + 64 + Equipment.POPUP_GAP);
   expect("another slot's window is left alone", Equipment.placeByPieces({column: 0, box: {}}, window, 1000) ? 1 : 0, 0);
}

// the character sheet: pools with what comes back a second, armor by the game's rate and cap, resistances capped
{
   const Equipment = freshPanel(false);
   const pool = (now, most, regen, combat) => ({now, most, regen, combat});
   const told = {health: pool(80, 100, 0.7, 0.7), magicka: pool(100, 100, 3, 0), stamina: pool(50, 100, 5, 1),
      armorScale: 0.12, armorBase: 0.03, armorCap: 80, resistCap: 85, magic: 10, fire: 120, frost: 0, shock: 0, poison: 0, disease: 0,
      speedMult: 1, leftSpeedMult: 0.8, crit: 0, unarmed: 4, move: 100, level: 12, toNextLevel: 0.45,
      worn: 46.45, wornForSpeed: 12, noise: 0.5, shout: 0.8, absorb: 0, reflect: 10, waterBreathing: 1,
      skills: [{name: "One-handed", points: 0, modifier: 20, power: 10}, {name: "Heavy armor", points: 15, modifier: 0, power: 0},
         {name: "Destruction", points: 0, modifier: 25, power: 0}, {name: "Restoration", points: 0, modifier: 0, power: 0}]};
   const worn = {armor: [armor(4, 30, 1, {weightClass: 1}), armor(1, 15, 1, {weightClass: 1}), armor(64, 0, 1, {weightClass: 4})]};
   const sheet = Equipment.heroSheet(told, {armor: 100, damage: 12.6, encumbrance: 152.3, maxEncumbrance: 320}, worn);
   const named = (list, name) => list.find((one) => one.name === name) || {};
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   said("health and its pace in a fight", named(sheet.pools, "Health").note, "+0.7/s, in a fight +0.5");
   said("magicka that stops in a fight", named(sheet.pools, "Magicka").note, "+3.0/s, none in a fight");
   said("stamina keeps its pace in a fight", named(sheet.pools, "Stamina").note, "+5.0/s");
   expect("armor stops by rating and two pieces", sheet.armor.stops, 0.18);
   expect("armor's cap", sheet.armor.cap, 0.8);
   said("fire past the cap", named(sheet.resists, "Fire").value + " " + named(sheet.resists, "Fire").capped, "85% true");
   said("a zero resistance is faint", String(named(sheet.resists, "Frost").zero) + " " + String(named(sheet.resists, "Magic").zero), "true false");
   said("fists: no swing, the left hand slowed, no crit", sheet.offense.map((one) => one.name + " " + one.value).join(", "), "Damage 12, Left attack speed -20%, Unarmed damage 4");
   told.hands = [{entry: {formType: 41, subType: 1}, speed: 1, left: false}, {entry: {formType: 41, subType: 2}, speed: 1.3, left: true}];
   told.speedMult = 1.1;
   told.leftSpeedMult = 1.1;
   told.crit = 5;
   const armed = Equipment.heroSheet(told, {armor: 100, damage: 12.6, encumbrance: 152.3, maxEncumbrance: 320}, worn);
   said("a sword and a dagger", armed.offense.map((one) => one.name + " " + one.value).join(", "), "Damage 12, Swing 0.64 s, Damage a second ~11.6, Left hand swing 0.49 s, Attack speed +10%, Critical chance 5%");
   told.hands = [{entry: {formType: 41, subType: 8}, speed: 1, left: false}];
   told.speedMult = 1;
   told.leftSpeedMult = 1;
   told.crit = 0;
   said("a bow is drawn", Equipment.heroSheet(told, {damage: 20}, worn).offense.map((one) => one.name).join(","), "Damage,Draw,Damage a second");
   expect("level", sheet.level, 12);
   expect("the way to the next", sheet.toNext, 0.45);
   said("movement", sheet.movement.map((one) => one.name + " " + one.value).join(", "), "Carry weight 153 / 320, Gear weight 46.5, slows you down 12, Noise of steps 50%");
   const near = Object.assign({}, told, {worn: 92.8, wornForSpeed: 92.75});
   said("a weight that reads the same is not told twice", Equipment.heroSheet(near, {encumbrance: 1, maxEncumbrance: 2}, worn).movement.map((one) => one.name).join(","), "Carry weight,Gear weight,Noise of steps");
   said("other only what's there", sheet.other.map((one) => one.name + " " + one.value).join(", "), "Shout cooldown -20%, Reflect damage 10%, Water breathing yes");
   told.voice = {name: "Unrelenting Force", words: [{seconds: 20, learned: true}, {seconds: 30, learned: true}, {seconds: 45, learned: false}]};
   told.voiceWait = 12;
   said("a shout in seconds of its learned words", Equipment.voiceLines(told).map((one) => one.name + " " + one.value + (one.minor ? " (dim)" : "")).join(", "), "Unrelenting Force 16 / 24 s, Voice rests 12 s more (dim), Shout cooldown -20% (dim)");
   told.move = 110;
   said("speed only when changed", Equipment.heroSheet(told, {}, worn).movement[0].name + " " + Equipment.heroSheet(told, {}, worn).movement[0].value, "Speed +10%");
   delete told.voice;
   told.voiceWait = 0;
   told.move = 100;
   said("skills only when raised", sheet.skills.map((one) => one.name + " " + one.value).join(", "), "One-handed +30% damage, Heavy armor +15 skill, Destruction cost -25%");
   said("no numbers, no sheet", String(Equipment.heroSheet(undefined, undefined, worn)), "undefined");
}

// spells in hand by what they cost, bounties, statuses with their time left
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const told = {magicka: {now: 100}, spells: [{name: "Firebolt", cost: 41, stream: false}, {name: "Flames", cost: 14, stream: true}]};
   said("a cast and a stream", Equipment.spellLines(told).map((one) => one.name + " " + one.aside).join(", "), "Firebolt 41 magicka, Flames 14 magicka a second");
   told.spells = [{name: "Flames", cost: 14, stream: true}, {name: "Flames", cost: 14, stream: true}];
   expect("the same spell in both hands is one line", Equipment.spellLines(told).length, 1);
   said("a bounty", Equipment.bountyLines({bounties: [{name: "Whiterun", gold: 40}]})[0].value, "40 gold");
   const statuses = Equipment.statusLines({statuses: [{name: "Rockjoint", text: "Your melee hits do 25% less damage.", left: -1, type: 1}, {name: "Blessing of Talos", text: "Shouts recharge 20% faster.", left: 28800, type: 4}]});
   said("a disease in red without a time", statuses[0].aside + " " + (statuses[0].color === Equipment.HERO_HEAVY), " true");
   said("a blessing with its time", statuses[1].aside, "8 h");
   const fight = {health: {now: 1, most: 1, regen: 0, combat: 0}, magicka: {now: 1, most: 1, regen: 0, combat: 0}, stamina: {now: 100, most: 100, regen: 0, combat: 0},
      armorScale: 0.12, armorBase: 0.03, armorCap: 80, resistCap: 85, speedMult: 1, leftSpeedMult: 1, crit: 0, unarmed: 4, move: 100,
      hands: [{entry: {formType: 41, subType: 8}, speed: 1, left: false}], bowDamage: 21.6, arrow: "Iron Arrow", sneakMult: 2, runSpeed: 300, walkSpeed: 100};
   const armed = Equipment.heroSheet(fight, {damage: 12}, {armor: []});
   said("a bow with its arrow and a sneak shot", armed.offense.map((one) => one.name + " " + one.value).join(", "), "Damage with Iron Arrow 21, Draw 1.00 s, Damage a second ~12.0, Sneak attack x2, 43");
   said("run and walk in metres", armed.movement.slice(0, 2).map((one) => one.name + " " + one.value).join(", "), "Run 4.3 m/s, Walk 1.4 m/s");
   delete fight.bowDamage;
   fight.hands = [{entry: {formType: 41, subType: 1}, speed: 1, left: false}];
   fight.sneakMult = 3;
   fight.powerStamina = 26.5;
   fight.powerDamage = 2;
   said("a power attack", Equipment.heroSheet(fight, {damage: 10}, {armor: []}).offense.slice(3).map((one) => one.name + " " + one.value).join(", "), "Sneak attack x3, 30, Power attack x2, 27 stamina, in a row from full 3");
   said("no fists with a spell in the right hand", Equipment.offenseLines({speedMult: 1, leftSpeedMult: 1, crit: 0, unarmed: 4, spells: [{name: "Flames", left: false}]}, {}).length + "", "0");
   said("minutes and seconds", Equipment.timeLeft(90) + ", " + Equipment.timeLeft(40.2) + ", " + Equipment.timeLeft(3720), "1 min, 41 s, 1 h 2 min");
}

// the character drawer: as far out as asked within the room and the sheet
{
   const Equipment = freshPanel(false);
   const least = Equipment.heroLeast();
   Equipment.hero = {room: 500, full: 419};
   expect("never pulled shows all of the sheet", Equipment.heroHigh(0), 419);
   expect("no further out than the sheet", Equipment.heroHigh(800), 419);
   expect("a few lines at the least", Equipment.heroHigh(10), least);
   expect("as it was left", Equipment.heroHigh(210), 210);
   Equipment.hero = {room: 300, full: 419};
   expect("a low room holds it", Equipment.heroHigh(0), 300);
   Equipment.hero = {room: 40, full: 419};
   expect("a room under the least wins", Equipment.heroHigh(0), 40);
   expect("gold blends toward white", Equipment.blendColor(0x000000, 0xFFFFFF, 0.5), 0x808080);
}

// Node runs the parts as JavaScript, where get and set are plain names. The movie's compiler takes them for a getter or a
// setter and the whole build stops, so no name in the parts may be one of the words AS2 keeps for itself
{
   const kept = ["set", "get", "class", "interface", "dynamic", "intrinsic", "implements", "extends", "import"];
   const named = new RegExp(`\\b(?:var|function)\\s+(${kept.join("|")})\\b|function\\s*\\([^)]*\\b(${kept.join("|")})\\b[^)]*\\)`);
   for (const part of parts) {
      const lines = fs.readFileSync(path.join(source, part), "utf8").split("\n");
      let clean = true;
      lines.forEach((line, i) => {
         const found = line.match(named);
         if (found) {
            clean = false;
            console.log(`FAIL ${part}:${i + 1} names a thing "${found[1] || found[2]}", a word the movie's compiler keeps`);
         }
      });
      clean ? passed++ : failed++;
   }
}

// a chip brings the list up to date through the call the game makes after an equip, a menu without it the old way
{
   const Equipment = freshPanel(false);
   const lists = Equipment.menu.inventoryLists;
   const calls = [];
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   Equipment.chosenChips = [];
   Equipment.settings = {subcategories: true};
   lists.categoryList.selectedEntry = {flag: 4};
   lists.categoryLabel = {_x: 0, textField: {_x: 0}};
   lists.itemList = {InvalidateData: function() { calls.push("list"); if (this.onInvalidate) this.onInvalidate(); }};
   lists.InvalidateListData = () => { calls.push("lists"); lists.itemList.InvalidateData(); };
   Equipment.chooseChip("0,clothing");
   said("a chosen chip refreshes like an equip does", calls.join(","), "lists,list");
   said("and the chip is chosen", Equipment.chosenChips[0], "clothing");
   delete lists.InvalidateListData;
   Equipment.chooseChip("0,");
   said("a menu without that call refreshes the list itself", calls.join(","), "lists,list,list");
   said("the refresh leaves no hook behind", lists.itemList.onInvalidate, undefined);
}

// A card that gets new info past the menu's call (Description Framework adds its text a frame later) lays the window
// out again, the menu's own call and the panel's own remake don't do it twice
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   let laid = 0;
   let numbers = 0;
   const card = {
      kept: undefined,
      __get__itemInfo() { return this.kept; },
      __set__itemInfo(info) { this.kept = info; },
      addProperty(name, get, set) { Object.defineProperty(this, name, {get, set, configurable: true}); },
      gotoAndStop() {},
   };
   Equipment.showWindow = () => laid++;
   Equipment.cardNumbersLater = () => numbers++;
   Equipment.cardStamp = 4;
   Equipment.watchCardInfo(card, Equipment.cardRefilled);
   card.itemInfo = {effects: "Fire damage", DF_fixed: true};
   said("info from outside lays the window out", laid + "," + numbers, "1,1");
   said("as a new card", Equipment.cardStamp, 5);
   said("and the card keeps the info", card.itemInfo.effects, "Fire damage");
   Equipment.fillingCard = true;
   card.itemInfo = {effects: "Frost"};
   Equipment.fillingCard = false;
   said("the menu's own call lays it out itself", laid, 1);
   Equipment.menu.itemCard = card;
   Equipment.remakeCard();
   said("so does the remake", laid, 1);
   Equipment.watchCardInfo(card, Equipment.cardNumbersLater);
   card.itemInfo = {effects: "Shock"};
   said("a second watch adds nothing", laid, 2);
   const plain = {itemInfo: {effects: "x"}};
   Equipment.watchCardInfo(plain, Equipment.cardRefilled);
   said("a card of a skin with no setter is left as it is", plain.equipmentSetInfo, undefined);
   // a chest's card has no window, a late description lays out only its numbers
   const chest = {...card, kept: undefined, equipmentSetInfo: undefined};
   delete chest.itemInfo;
   numbers = 0;
   Equipment.watchCardInfo(chest, Equipment.cardNumbersLater);
   chest.itemInfo = {effects: "Does Raw Magic damage", descriptionText: "A translucent Ancient Nord Sword"};
   said("a chest's late description lays the numbers out again, no window", laid + "," + numbers, "2,1");
}

// A mod that hooks the menu's card call keeps what it found under a name of its own and hooks again once ours sits over
// it. Its new hook called ours, ours its old one, that one ours again without end and the card stayed empty. A call back
// into a wrapper that still runs goes to the menu class's own function
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   let filled = [];
   let hops = 0;
   let looped = false;
   let windows = 0;
   let numbers = 0;
   const own = {UpdateItemCardInfo(info) {
      filled.push(info.text + (Equipment.fillingCard ? " filling" : ""));
      this.itemCard.itemInfo = info;
   }};
   const fresh = () => Object.assign(Object.create(own), {itemCard: {}});
   // stores what's on top under its own name and calls it by that name, a hook already on top stays
   const hookOther = (menu) => {
      if (menu.UpdateItemCardInfo === menu.otherHook) return;
      const hook = function(info) {
         hops++;
         if (hops > 20) {
            looped = true;
            return;
         }
         this.otherOriginal(info);
      };
      menu.otherOriginal = menu.UpdateItemCardInfo;
      menu.UpdateItemCardInfo = hook;
      menu.otherHook = hook;
   };
   const run = (menu, info) => {
      filled = [];
      hops = 0;
      looped = false;
      windows = 0;
      numbers = 0;
      menu.UpdateItemCardInfo(info || {text: "Iron Sword"});
   };
   Equipment.menu.itemCard = {};
   Equipment.showWindow = () => windows++;
   Equipment.cardNumbersLater = () => numbers++;

   let menu = fresh();
   hookOther(menu);
   Equipment.windowFollowsCardInfo(menu);
   hookOther(menu);
   Equipment.cardStamp = 0;
   const info = {text: "Iron Sword", effects: "Burns for 5 points. Frost for 3 points."};
   run(menu, info);
   said("a hook that hooks again over the window's wrapper fills the card once", filled.join(","), "Iron Sword filling");
   said("and goes round once", looped + "," + hops, "false,2");
   said("the card has the info", menu.itemCard.itemInfo, info);
   said("its effects split once", info.effects, "Burns for 5 points.<br>Frost for 3 points.");
   said("the window is laid out after both calls of the wrapper", windows + "," + Equipment.cardStamp, "2,2");
   said("the card isn't filling once it's done", Equipment.fillingCard, false);
   run(menu);
   said("the next call goes the same way", filled.length + "," + hops + "," + looped, "1,2,false");

   menu = fresh();
   hookOther(menu);
   Equipment.numbersFollowCardInfo(menu);
   hookOther(menu);
   run(menu);
   said("over the numbers' wrapper the card fills once too", filled.join(",") + "," + hops + "," + looped, "Iron Sword,2,false");
   said("the numbers are laid out after both calls", numbers, 2);

   // the inventory with the card at home has both
   menu = fresh();
   hookOther(menu);
   Equipment.windowFollowsCardInfo(menu);
   Equipment.numbersFollowCardInfo(menu);
   hookOther(menu);
   run(menu);
   said("over both of ours the card fills once", filled.join(",") + "," + hops + "," + looped, "Iron Sword filling,2,false");
   said("the window's wrapper runs once, the numbers' twice", windows + "," + numbers, "1,2");
   said("and neither stays busy", menu.equipmentUpdateItemCardInfoBusy + "," + menu.equipmentCardInfoBusy, "false,false");

   menu = fresh();
   Equipment.windowFollowsCardInfo(menu);
   Equipment.numbersFollowCardInfo(menu);
   run(menu);
   said("without another mod the card fills once through both", filled.join(",") + "," + windows + "," + numbers, "Iron Sword filling,1,1");

   // a hook that stays where it is between ours is passed through like the rest
   menu = fresh();
   Equipment.windowFollowsCardInfo(menu);
   hookOther(menu);
   Equipment.numbersFollowCardInfo(menu);
   run(menu);
   said("a hook between ours runs once", hops + "," + filled.join(",") + "," + windows + "," + numbers, "1,Iron Sword filling,1,1");
}

// A skin's card at the lower right (Edge UI) stands over the right column of slots, in the character's room it keeps
// between the columns, and a card wider than the room stands in its middle
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const holder = {_x: 900, _parent: {globalToLocal() {}}};
   const card = {_parent: holder, localToGlobal(point) { point.x += holder._x; }};
   let wide = 300;
   Equipment.frameBox = () => ({xMin: 0, xMax: wide, yMin: 0, yMax: 200});
   Equipment.stage = {touch: {_width: 600}, localToGlobal(point) { point.x += 400; }};
   Equipment.keepCardInRoom(card);
   said("a card past the room's right comes back in, a little off the slots", holder._x, 700 - Equipment.MARGIN / 2);
   holder._x = 450;
   Equipment.keepCardInRoom(card);
   said("a card inside stays", holder._x, 450);
   wide = 800;
   Equipment.keepCardInRoom(card);
   said("a card wider than the room stands in its middle", holder._x, 300);
}

// On paper the ingredients SkyUI writes in white and grey take the paper's inks
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   Equipment.paper = true;
   const html = '<FONT COLOR="#FFFFFF">2 Leather Strips</FONT>, <FONT COLOR="#777777">3 Iron Ingot</FONT>';
   const inked = Equipment.inksOnPaper(html);
   said("what the player has turns dark", inked.indexOf("#1C1814") > 0, true);
   said("what is short turns the quiet ink", inked.indexOf("#54473A") > 0, true);
   said("no white is left", inked.indexOf("#FFFFFF"), -1);
}

// The game's Cancel goes to the panel first: the topmost of what it has up steps back and the menu stays. The press
// that did it reaches neither the panel's own keys nor SkyUI's, whichever of the game's event and the key comes first
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const codes = freshPanel.context.gfx.ui.NavigationCode;
   const passedOn = [];
   const menu = {handleInput: (details) => (passedOn.push(details.value), true)};
   Equipment.context = {_visible: true};
   Equipment.look = {_visible: false};
   Equipment.closeContext = () => (Equipment.context._visible = false);
   Equipment.chargeListUp = () => false;
   Equipment.holdCancel(menu);
   const key = (value) => menu.handleInput({value: value, navEquivalent: codes.ESCAPE}, []);
   // the key first, then the game's Cancel
   key("keyDown");
   said("a row's menu up holds the key", passedOn.length, 0);
   said("the game's Cancel closes the row's menu", Equipment.panelCancel(), true);
   said("the row's menu is down", Equipment.context._visible, false);
   key("keyUp");
   said("the let go of that press is held too", passedOn.length, 0);
   key("keyDown");
   said("with nothing up the key goes on", passedOn.join(","), "keyDown");
   said("and the game's Cancel closes the menu", Equipment.panelCancel(), false);
   // the game's Cancel first, then the key
   passedOn.length = 0;
   Equipment.context._visible = true;
   said("the Cancel first closes the row's menu", Equipment.panelCancel(), true);
   key("keyDown");
   key("keyUp");
   said("the key of that press goes nowhere after it", passedOn.length, 0);
   key("keyDown");
   said("the next press goes on", passedOn.join(","), "keyDown");
}

// A subcategory's new dot: after the pointer passed a new row only the chips holding that row are looked at again
{
   const Equipment = freshPanel(false);
   const context = freshPanel.context;
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const chip = (key) => Object.assign(new context.MovieClip(), {key: key, newDot: {_visible: true}});
   const helmet = {formId: 1, chip: "head"};
   const boots = {formId: 2, chip: "feet"};
   const seen = {};
   let holds = 0;
   Equipment.chips = {head: chip("head"), feet: chip("feet")};
   Equipment.chipHolds = (key, entry) => (holds++, entry.chip == key);
   Equipment.isNew = (entry) => seen[entry.formId] != true;
   Equipment.menu.inventoryLists = {itemList: {entryList: [helmet, boots]}, categoryList: {selectedEntry: {flag: 1}}, _typeFilter: {isMatch: () => true}};
   seen[1] = true;
   Equipment.markChips(helmet);
   said("the head chip loses its dot", Equipment.chips.head.newDot._visible, false);
   said("the feet chip keeps its own", Equipment.chips.feet.newDot._visible, true);
   holds = 0;
   seen[2] = true;
   Equipment.markChips();
   said("a full look goes through every chip", Equipment.chips.feet.newDot._visible, false);
}

// Movies other mods load into the menu hear the selection again once the card stands in the window, and their clips
// that lie on the card go over the window and come and go with the card (Ingredients Have Description)
{
   const Equipment = freshPanel(false);
   const context = freshPanel.context;
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const clip = (url, box, extra) => Object.assign(new context.MovieClip(), {_url: url, _visible: true, at: -6708, getBounds: () => box, getDepth() { return this.depth != undefined ? this.depth : this.at; }, swapDepths(d) { this.depth = d; }}, extra);
   let depth = 10;
   const heard = [];
   const menu = Equipment.menu;
   menu._url = "inventorymenu.swf";
   Object.assign(menu, {getNextHighestDepth: () => ++depth});
   const holder = clip("inventorymenu.swf", {xMin: 400, xMax: 700, yMin: 300, yMax: 700});
   let at = 0;
   menu.itemCard = {_parent: holder, localToGlobal(point) { point.x += at; }};
   const tale = clip("IngredientDescriptions.swf", {xMin: 450, xMax: 650, yMin: 500, yMax: 560}, {onItemHighlightChange(event) { heard.push(event.index); }});
   const far = clip("LoreBox.swf", {xMin: 1000, xMax: 1200, yMin: 50, yMax: 90});
   const own = clip("inventorymenu.swf", {xMin: 450, xMax: 650, yMin: 500, yMax: 560});
   // SkyUI's lists are a movie of their own and lie under the window, where the menu's file put them
   const lists = clip("skyui/InventoryLists.swf", {xMin: 0, xMax: 600, yMin: -300, yMax: 1100}, {at: -16381, onItemHighlightChange() { heard.push("lists"); }});
   menu.listsPart = lists;
   menu.farBox = far;
   menu.ownPart = own;
   lists._parent = tale._parent = far._parent = own._parent = holder._parent = menu;
   Object.setPrototypeOf(menu, context.MovieClip.prototype);
   menu.inventoryLists._listeners = {itemHighlightChange: [
      {listenerObject: menu, listenerFunction: "onItemHighlightChange"},
      {listenerObject: lists, listenerFunction: "onItemHighlightChange"},
   ]};
   // a mod's script made its clip at a depth of its own
   menu.taleHolder = tale;
   menu.inventoryLists._listeners.itemHighlightChange.push({listenerObject: Equipment, listenerFunction: "onHighlight"}, {listenerObject: tale, listenerFunction: "onItemHighlightChange"});
   Equipment.over = clip("inventorymenu.swf", {}, {});
   Equipment.window = {_visible: true, getBounds: () => ({xMin: 400, xMax: 700, yMin: 300, yMax: 700})};
   Equipment.leavesCard = () => false;
   said("only another movie's listener is another's", Equipment.othersListening("itemHighlightChange").length, 1);

   Equipment.lastHighlight = {type: "itemHighlightChange", index: 7};
   Equipment.cardPlaceTold = undefined;
   Equipment.tellOthersOfCard();
   said("the other movie hears the selection again", heard.join(","), "7");
   said("its clip on the card goes over the window", tale.depth > 10 && Equipment.over.depth > tale.depth, true);
   said("a clip away from the card stays where it was", far.depth, undefined);
   said("the menu's own movies stay under the window", lists.depth, undefined);
   said("the menu's own clip too", own.depth, undefined);
   Equipment.tellOthersOfCard();
   said("the card in the same place tells nothing more", heard.length, 1);
   at = 30;
   Equipment.tellOthersOfCard();
   said("the card in a new place tells it once more", heard.join(","), "7,7");
   holder._visible = false;
   Equipment.followCard();
   said("the clip goes with the card", tale._visible, false);
   holder._visible = true;
   Equipment.followCard();
   said("and comes back with it", tale._visible, true);
   Equipment.window._visible = false;
   at = 60;
   Equipment.tellOthersOfCard();
   said("no window, nothing told", heard.length, 2);

   // the window shows the card at half its size, the tale follows it and keeps its corner where its mod put it
   let size = 1;
   menu.itemCard.localToGlobal = function(point) { point.x = point.x * size + at; point.y = point.y * size; };
   menu.globalToLocal = () => undefined;
   Equipment.cardScaleAtOpen = Equipment.cardScaleInMenu();
   size = 0.5;
   Object.assign(tale, {_x: 0, _y: 0, _xscale: 100, _yscale: 100});
   tale.getBounds = function() { return {xMin: this._x + 450 * this._xscale / 100, xMax: this._x + 650 * this._xscale / 100, yMin: this._y + 500 * this._yscale / 100, yMax: this._y + 560 * this._yscale / 100}; };
   Equipment.fitFollowers();
   said("the tale takes the card's size", tale._xscale + "," + tale._yscale, "50,50");
   said("its corner stays put", tale.getBounds().xMin + "," + tale.getBounds().yMin, "450,500");
   Equipment.fitFollowers();
   said("and stays so frame after frame", tale._x + "," + tale._y + "," + tale._xscale, "225,250,50");
   // Details borrows a card at home and keeps where it stood apart, the fit still goes by the card's size at the opening
   Equipment.cardBorrowedFrom = {x: 1200, y: 640, xscale: 100, yscale: 100};
   Equipment.fitFollowers();
   said("a borrowed card's place leaves the fit alone", tale._xscale + "," + tale._yscale, "50,50");
}

// A refresh of the panel's goes through even where a mod holds back a refresh of the same items (I4 Improved), and a
// list that skips it anyway gets its own pass from the panel
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   // SkyUI's BasicList with its InvalidateData, the filter keeps the heavy rows
   const skyList = () => {
      const list = {
         entryList: [{heavy: true}, {heavy: false}, {heavy: true}],
         _dataProcessors: [{processList: () => list.processed++}],
         _selectedIndex: 2,
         processed: 0, drawn: 0, passes: 0,
         listEnumeration: {kept: [], invalidate() { this.kept = list.entryList.filter((entry) => entry.heavy); }, size() { return this.kept.length; }},
         UpdateList() { this.drawn++; },
         InvalidateData() {
            if (this._bSuspended) {
               return;
            }
            this.passes++;
            this._dataProcessors.forEach((step) => step.processList(this));
            this.listEnumeration.invalidate();
            this.UpdateList();
            if (this.onInvalidate) {
               this.onInvalidate();
            }
         },
      };
      return list;
   };
   let list = skyList();
   Equipment.invalidate(list);
   said("a plain list makes one pass", list.passes + "," + list.drawn + "," + list.processed, "1,1,1");
   said("and keeps no hook", list.onInvalidate, undefined);

   // I4 Improved lets a refresh with the one-shot hook through and holds back the rest
   list = skyList();
   const real = list.InvalidateData;
   list.InvalidateData = function() { if (this.onInvalidate !== undefined) real.call(this); };
   Equipment.invalidate(list);
   said("a held back refresh goes through with the hook", list.passes + "," + list.drawn, "1,1");
   said("the rows are the filtered ones", list.listEnumeration.size(), 2);

   // a mod that holds every refresh back
   list = skyList();
   list.InvalidateData = () => undefined;
   Equipment.invalidate(list);
   said("the panel makes the pass itself", list.drawn + "," + list.processed + "," + list.listEnumeration.size(), "1,1,2");
   said("the rows get their places", list.entryList.map((entry) => entry.itemIndex).join(","), "0,1,2");
   said("the selection comes into the rows left", list._selectedIndex, 1);
   said("no hook stays", list.onInvalidate, undefined);

   // the menu's own one-shot hook to get the scroll back runs once and goes
   list = skyList();
   let restored = 0;
   list.onInvalidate = function() { restored++; delete this.onInvalidate; };
   Equipment.invalidate(list);
   said("the menu's hook still runs once", restored, 1);
   said("and is gone after", list.onInvalidate, undefined);

   // a held back refresh leaves the menu's hook waiting for the real one
   list = skyList();
   const hook = function() { restored++; delete this.onInvalidate; };
   list.onInvalidate = hook;
   list.InvalidateData = () => undefined;
   Equipment.invalidate(list);
   said("the menu's hook waits", list.onInvalidate === hook, true);
   said("and didn't run", restored, 1);

   // a paused list is left to refresh itself when it's back
   list = skyList();
   list._bSuspended = true;
   Equipment.invalidate(list);
   said("a paused list isn't drawn", list.drawn + "," + list.passes, "0,0");
   said("and keeps no hook", list.onInvalidate, undefined);

   // a chip in a menu where InvalidateListData of the lists runs the held back InvalidateData
   list = skyList();
   list.InvalidateData = function() { if (this.onInvalidate !== undefined) real.call(this); };
   Equipment.menu.inventoryLists.itemList = list;
   Equipment.menu.inventoryLists.InvalidateListData = () => list.InvalidateData();
   Equipment.refilter();
   said("a chip refresh gets through the lists' call", list.passes + "," + list.drawn, "1,1");
}

// the body slots of a piece from its mask, bit n is slot 30 + n, up to slot 61 in the top bit
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const line = (entry) => Equipment.bodySlotsLine(entry);
   said("a helmet takes slot 30", line(armor(1, 15)), "Slot 30");
   said("a cuirass and a cloak bit", line(armor(4 | 65536, 30)), "Slots 32, 46");
   said("a shield is slot 39", line(armor(512, 20)), "Slot 39");
   said("the top bit is slot 61", line(armor(2 ** 31, 0)), "Slot 61");
   said("every slot of a mask", Equipment.bodySlots(0xFFFFFFFF).length + " " + Equipment.bodySlots(0xFFFFFFFF).join(",").slice(0, 8), "32 30,31,32");
   said("a piece MARA took the slots off has none", line(armor(0, 0)), "No body slot");
   said("a mask SkyUI never told says nothing", line({formType: W.ARMOR}), "");
   said("a weapon takes no body slot", line(sword(8)), "No body slot");
   said("nor do arrows", line({formType: W.AMMO}), "No body slot");
   said("nor a torch", line({formType: W.LIGHT}), "No body slot");
   said("a potion says nothing", line({formType: 46}), "");

   // in a window of a row the line shares the strip of the lens, in a window of a slot it adds its own height
   // the lens is a part this test doesn't load
   Equipment.LENS_SIZE = 22;
   Equipment.window = {statLines: [], bodySlots: {_visible: true, _height: 17}};
   expect("a row window over its row keeps the lens's height", Equipment.underCard(true), Equipment.LENS_SIZE);
   expect("one under its row only the line's", Equipment.underCard(false), 17);
   Equipment.window.bodySlots._visible = false;
   expect("and with no line no strip at all", Equipment.underCard(false), 0);
   Equipment.window.bodySlots._visible = true;
   Equipment.anchorSlot = Equipment.slotNamed("body");
   expect("a slot window grows by the line", Equipment.underCard(), 17 + Equipment.ACTION_HIGH + 2 * Equipment.ACTION_GAP + Equipment.ACTION_EDGE);
   Equipment.window.bodySlots._visible = false;
   expect("switched off it adds nothing", Equipment.underCard(), Equipment.ACTION_HIGH + 2 * Equipment.ACTION_GAP + Equipment.ACTION_EDGE);
}

// the colours of the menu replace the gold and the parchment every part draws with
{
   const Equipment = freshPanel(false);
   Equipment.plugin = () => ({Settings: () => ({accent: 0x3A7BD5, text: 0xDDDDDD})});
   Equipment.readSettings();
   expect("the accent of the menu", Equipment.GOLD, 0x3A7BD5);
   expect("the text colour of the menu", Equipment.PARCHMENT, 0xDDDDDD);
   Equipment.plugin = () => undefined;
   Equipment.readSettings();
   expect("with no plugin the gold stays", Equipment.GOLD, 14069864);
   expect("and the parchment", Equipment.PARCHMENT, 15130824);
}

// the words of the panel come from the translation file of the game's language, English where it has none
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const english = freshPanel(false);
   said("no file keeps the English", english.say("Find in list"), "Find in list");
   said("a value in place of #", english.say("# gold", 40), "40 gold");
   said("values by number", english.say("#1 h #2 min", 7, 59), "7 h 59 min");
   const german = freshPanel(false, {
      "$IR_Find in list": "In der Liste finden",
      "$IR_#1 h #2 min": "#2 Min. von #1 Std.",
      "$IR_Head": "Kopf",
      "$IR_Bows": "Bögen",
   });
   said("a translated line", german.say("Find in list"), "In der Liste finden");
   said("a language puts the values in its own order", german.say("#1 h #2 min", 7, 59), "59 Min. von 7 Std.");
   said("the slots are named in it", german.SLOTS[5].title, "Kopf");
   said("a chip SkyUI has no word for takes the mod's word", german.translated({words: "$Bows", fallback: "Bows"}), "Bögen");
   const crowded = freshPanel(false, {"$Bows": "Bows", "$IR_Bows": "Bögen", "$Heavy": "Schwer", "$IR_Heavy": "Heavy"});
   said("the mod's own translation wins over another mod's English key", crowded.translated({words: "$Bows", fallback: "Bows"}), "Bögen");
   said("with the mod's words in English SkyUI's word stays", crowded.translated({words: "$Heavy", fallback: "Heavy"}), "Schwer");
   said("the item window line", german.bodySlotsLine({formType: 41}), "No body slot");
   const fromPlugin = freshPanel(false, {"$IR_Health": "HEALTH"});
   fromPlugin.plugin = () => ({Words: () => ({"$IR_Health": "Health"})});
   said("the plugin's words win over the game's pool, which keeps one letter case", fromPlugin.say("Health"), "Health");
}

// the kind under the name, the column of kinds, the effects of an enchantment line by line, the ink of paper skins
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel();
   const armor = (more) => Object.assign({formType: 26, partMask: 0}, more);
   said("a heavy helmet", Equipment.kindLine(armor({weightClass: 1, partMask: 1, subTypeDisplay: "Head"})), "Heavy, Head");
   said("clothing on the body", Equipment.kindLine(armor({weightClass: 3, partMask: 4, subTypeDisplay: "Body"})), "Clothing, Body");
   // the card's skill names a light or heavy piece whole, the corner of the card said it a second time
   said("a heavy helmet by its card's skill", Equipment.kindLine(armor({weightClass: 1, partMask: 1, subTypeDisplay: "Head"}), "Heavy Armor"), "Heavy Armor, Head");
   said("a light shield by its card's skill", Equipment.kindLine(armor({weightClass: 0, partMask: 512, subTypeDisplay: "Shield"}), "Light Armor"), "Light Armor, Shield");
   said("clothing has no skill, its chip names it", Equipment.kindLine(armor({weightClass: 3, partMask: 4, subTypeDisplay: "Body"}), ""), "Clothing, Body");
   said("a heavy shield", Equipment.kindLine(armor({weightClass: 1, partMask: 512, subTypeDisplay: "Shield"})), "Heavy, Shield");
   said("a one handed sword", Equipment.kindLine({formType: 41, subType: 1, subTypeDisplay: "Sword"}), "One-Handed, Sword");
   said("a greatsword", Equipment.kindLine({formType: 41, subType: 5, subTypeDisplay: "Greatsword"}), "Two-Handed, Greatsword");
   said("a bow is a bow", Equipment.kindLine({formType: 41, subType: 8, subTypeDisplay: "Bow"}), "Bow");
   said("a health potion", Equipment.kindLine({formType: 46, subType: 0, subTypeDisplay: "Health"}), "Potion, Health");
   said("a poison", Equipment.kindLine({formType: 46, subType: 15, subTypeDisplay: "Poison"}), "Poison");
   said("a gem", Equipment.kindLine({formType: 32, subType: 0, subTypeDisplay: "Gem"}), "Gem");
   said("no kind at all", Equipment.kindLine({formType: 32}), "");

   const ring = armor({weightClass: 4, keywords: {gearMaraRing: true}});
   Equipment.fillKind(ring);
   said("a ring MARA left with no slot", ring.subTypeDisplay, "Ring");
   said("and its line", Equipment.kindLine(ring), "Jewelry, Ring");
   const amulet = armor({weightClass: 4, keywords: {ClothingNecklace: true}, subTypeDisplay: "-"});
   Equipment.fillKind(amulet);
   said("an amulet with no slot", amulet.subTypeDisplay, "Amulet");
   const cloak = armor({weightClass: 3, partMask: 65536});
   Equipment.fillKind(cloak);
   said("a cloak of slot 46", cloak.subTypeDisplay, "Cloak");
   const helmet = armor({weightClass: 1, partMask: 1, subTypeDisplay: "Head"});
   Equipment.fillKind(helmet);
   said("SkyUI's own kind stays", helmet.subTypeDisplay, "Head");

   const iconOf = function(piece) {
      Equipment.fillIcon(piece);
      return piece.iconLabel;
   };
   said("a ring MARA left with no slot gets the ring icon", iconOf(armor({weightClass: 4, keywords: {gearMaraRing: true}, iconLabel: "default_armor"})), "armor_ring");
   said("an amulet with no slot gets the necklace icon", iconOf(armor({weightClass: 4, keywords: {ClothingNecklace: true}, iconLabel: "default_armor"})), "armor_amulet");
   said("a ring with a clothing keyword on its own slot", iconOf(armor({weightClass: 3, partMask: 0x40, iconLabel: "default_armor"})), "armor_ring");
   said("a cloak of slot 46 SkyUI left a shield", iconOf(armor({weightClass: 3, partMask: 65536, iconLabel: "default_armor"})), "clothing_cloak");
   said("a cloak with the necklace keyword stays a cloak", iconOf(armor({partMask: 65536, keywords: {ClothingNecklace: true}, iconLabel: "default_armor"})), "clothing_cloak");
   said("a piece on a slot of nobody keeps the shield", iconOf(armor({partMask: 0x200000, iconLabel: "default_armor"})), "default_armor");
   said("an icon SkyUI picked stays", iconOf(armor({partMask: 0x40, keywords: {gearMaraRing: true}, iconLabel: "lightarmor_hands"})), "lightarmor_hands");
   said("a weapon is not touched", iconOf({formType: 41, iconLabel: "default_armor"}), "default_armor");

   said("one effect stays one line", Equipment.effectLines("Your Magicka regenerates 25% faster."), "Your Magicka regenerates 25% faster.");
   said("two effects, two lines", Equipment.effectLines("Increases Destruction by 15%. Magicka regenerates 50% faster."),
      "Increases Destruction by 15%.<br>Magicka regenerates 50% faster.");
   said("a number starts a line", Equipment.effectLines("Fire damage. 25 points of frost."), "Fire damage.<br>25 points of frost.");
   said("a decimal point is no end", Equipment.effectLines("Weighs 1.5 less. Carry 20 more."), "Weighs 1.5 less.<br>Carry 20 more.");
   said("a tag between", Equipment.effectLines("Burns. <font color='#FF0000'>Freezes</font>."), "Burns.<br><font color='#FF0000'>Freezes</font>.");
   said("a small letter goes on", Equipment.effectLines("Lasts 60 s. and more"), "Lasts 60 s. and more");
   said("Cyrillic capitals", Equipment.effectLines("Шкода вогнем. Шкода морозом."), "Шкода вогнем.<br>Шкода морозом.");
   const menuBefore = Equipment.menu;
   Equipment.menu = {itemCard: {}};
   said("SkyUI's card sizes its effects itself", Equipment.cardFitsByHand(), false);
   Equipment.menu = {itemCard: {changeTextSize: function() {}}};
   said("a card of Dear Diary Dark Mode fits them by hand", Equipment.cardFitsByHand(), true);
   Equipment.menu = menuBefore;

   Equipment.readSkin({Appearance: {colors: {text: {enabled: 0xFFFFFF}}}});
   said("SkyUI's white list is no paper", Equipment.paper, false);
   said("the ink of junk on a dark list", Equipment.inkOf("junk"), 0x8A8579);
   Equipment.readSkin({Appearance: {colors: {text: {enabled: 0x141414}}}});
   said("Dear Diary's black list is paper", Equipment.paper, true);
   said("the ink of junk on paper", Equipment.inkOf("junk"), 0x5E574E);
   said("the window is a sheet of paper", Equipment.inkOf("sheet"), 0xD9CEB6);
   Equipment.readSkin({});
   said("a config with no colours is no paper", Equipment.paper, false);
}

// the material, as the item's keywords say or else as SkyUI names it, for the corner of what it's made of. The kind
// line under the name says the kind alone
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false, {"$Daedric": "Daedrisch"});
   const heavy = (more) => Object.assign({formType: 26, weightClass: 1, partMask: 4, subTypeDisplay: "Body"}, more);
   const sword = (more) => Object.assign({formType: 41, subType: 1, subTypeDisplay: "Sword"}, more);
   // SkyUI leaves material empty and says Other of what it doesn't know, Amber is its material 0
   said("the keyword's own material over SkyUI's family", Equipment.material(heavy({material: 20, materialDisplay: "Steel", keywords: {ArmorMaterialSteelPlate: true}})), "Steel Plate");
   said("and the kind line says no material", Equipment.kindLine(heavy({material: 20, materialDisplay: "Steel", keywords: {ArmorMaterialSteelPlate: true}})), "Heavy, Body");
   said("SkyUI's material without a keyword", Equipment.material(heavy({material: 20, materialDisplay: "Steel"})), "Steel");
   said("its material 0 counts", Equipment.material(sword({material: 0, materialDisplay: "Amber"})), "Amber");
   said("a vanilla arrow SkyUI knows by its form", Equipment.material({formType: 42, subTypeDisplay: "Arrow", material: 20, materialDisplay: "Steel"}), "Steel");
   said("a word SkyUI didn't find in its language", Equipment.material(sword({material: 3, materialDisplay: "$Daedric"})), "Daedrisch");
   said("SkyUI's Other is no material", Equipment.material(heavy({material: null, materialDisplay: "Other"})), "");
   said("Other with a keyword SkyUI doesn't know", Equipment.material(heavy({material: null, materialDisplay: "Other", keywords: {ArmorHeavy: true, DLC1ArmorMaterialDawnguard: true}})), "Dawnguard");
   said("a menu with no material of SkyUI's reads the keywords", Equipment.material(sword({keywords: {WeapTypeSword: true, WeapMaterialDraugrHoned: true}})), "Draugr Honed");
   said("no material keyword, no material", Equipment.material(sword({keywords: {WeapTypeSword: true, VendorItemWeapon: true}})), "");

   said("plain", Equipment.materialWords("ArmorMaterialSteel"), "Steel");
   said("two words", Equipment.materialWords("WeapMaterialDraugrHoned"), "Draugr Honed");
   said("gilded", Equipment.materialWords("ArmorMaterialElvenGilded"), "Elven Gilded");
   said("plate", Equipment.materialWords("ArmorMaterialSteelPlate"), "Steel Plate");
   said("heavy is the class", Equipment.materialWords("DLC2ArmorMaterialStalhrimHeavy"), "Stalhrim");
   said("a Creation's light", Equipment.materialWords("ccBGSSSE055_ArmorMaterialOrcishLight"), "Orcish");
   said("Dawnguard's own", Equipment.materialWords("DLC1ArmorMaterialDawnguard"), "Dawnguard");
   said("Dawnguard's Materiel and what follows heavy", Equipment.materialWords("DLC1ArmorMaterielFalmerHeavyOriginal"), "Falmer");
   said("a quest's tag", Equipment.materialWords("ArmorMaterialMS02Forsworn"), "Forsworn");
   said("a crafting material", Equipment.materialWords("DLC1LD_CraftingMaterialAetherium"), "Aetherium");
   said("letters of a name stay together", Equipment.materialWords("WAF_ArmorMaterialTGLinwe"), "TG Linwe");
   said("light that starts a name stays", Equipment.materialWords("ArmorMaterialLightbringer"), "Lightbringer");
   said("WACCF's perk group", Equipment.materialWords("WAF_ArmorMaterialAdvanced"), "");
   said("WACCF's faction", Equipment.materialWords("WAF_MaterialFaction"), "");
   said("WACCF's switch of perks", Equipment.materialWords("WAF_IgnoreVanillaMaterialKeywordPerks"), "");
   said("materials of tools", Equipment.materialWords("WAF_ToolsMaterials"), "");
   said("no material in the name", Equipment.materialWords("ArmorHeavy"), "");

   // USSEP gives vampire armor Leather too, none of the two is known: the first by name. A word the game has comes first
   said("of two unknown the first by name", Equipment.keywordMaterial({keywords: {DLC1ArmorMaterialVampire: true, ArmorMaterialLeather: true}}), "Leather");
   const known = freshPanel(false, {"$Vampire": "Vampir"});
   said("the one the game has a word for", known.keywordMaterial({keywords: {DLC1ArmorMaterialVampire: true, ArmorMaterialLeather: true}}), "Vampir");
   said("a skipped keyword leaves the next", Equipment.keywordMaterial({keywords: {WAF_ArmorMaterialAdvanced: true, ArmorMaterialPenitus: true}}), "Penitus");
   said("and alone no material", Equipment.material(heavy({keywords: {WAF_ArmorMaterialAdvanced: true}})), "");

   const steel = heavy({material: 20, materialDisplay: "Steel"});
   Equipment.settings = {linesOff: 1 << Equipment.lineAt(Equipment.SMALL_LINES, "kind")};
   said("the kind off, the line says nothing", Equipment.kindLine(steel), "");
   said("the small lines keep their bits, the material's switch went", Equipment.SMALL_LINES.map((line) => line.id).join(" "), "bKind:Lines bHave:Lines bSilver:Lines bStolen:Lines");
}

// What it's made of, in the top left corner of the window's model room: a head, then every part of the recipe the
// plugin tells with the item's numbers, Iron Ingot (4) and no (1). Material says the keywords' word alone, Off nothing.
// An item no recipe makes (Ghostblade, a potion) says its material when it has one, else nothing and no head. One of
// the quiet tags. Every new choice on the sheet lays the window out at once
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false, {"$IR_Made from": "Hergestellt aus"});
   const asked = [];
   const recipes = {
      0x12E46: [{name: "Iron Ingot", count: 4}, {name: "Leather Strips", count: 3}],
      0x13952: [{name: "Steel Ingot", count: 4}, {name: "Corundum Ingot", count: 2}, {name: "Leather Strips", count: 3}],
      0x13999: [{name: "Dragon Heartscales", count: 1}],
   };
   Equipment.plugin = () => ({Stats: (formId) => (asked.push(formId), recipes[formId] != undefined ? {kind: "armor", madeOf: recipes[formId]} : {kind: "weapon"})});
   Equipment.settings = {quietTags: true, madeOf: 2};
   const iron = {formId: 0x12E46, formType: 26, keywords: {ArmorMaterialIron: true}};
   const plate = {formId: 0x13952, formType: 26, keywords: {ArmorMaterialSteelPlate: true}};
   const ghostblade = {formId: 0xF82FA, formType: 41, keywords: {WeapTypeSword: true}};
   const potion = {formId: 0x3EADE, formType: 46};
   const unique = {formId: 0x2AC6E, formType: 26, keywords: {ArmorMaterialDaedric: true}};
   said("the head over every part with how many", Equipment.madeOfLines(iron).join(" / "), "Hergestellt aus / Iron Ingot (4) / Leather Strips (3)");
   said("the parts in the recipe's order", Equipment.madeOfLines(plate).join(" / "), "Hergestellt aus / Steel Ingot (4) / Corundum Ingot (2) / Leather Strips (3)");
   said("one of a thing says no count", Equipment.madeOfLines({formId: 0x13999, formType: 26}).join(" / "), "Hergestellt aus / Dragon Heartscales");
   said("the parts come from the plugin by the item's form", asked.slice(0, 3).join(","), [0x12E46, 0x13952, 0x13999].join(","));
   said("a unique sword with neither recipe nor material says nothing", Equipment.madeOfLines(ghostblade).length, 0);
   said("a potion says nothing either", Equipment.madeOfLines(potion).length, 0);
   said("no recipe, the material's word", Equipment.madeOfLines(unique).join(" / "), "Hergestellt aus / Daedric");
   Equipment.settings.madeOf = 1;
   asked.length = 0;
   said("Material says the keywords' word alone", Equipment.madeOfLines(plate).join(" / "), "Hergestellt aus / Steel Plate");
   said("and asks the plugin nothing", asked.length, 0);
   Equipment.settings.madeOf = 0;
   said("Off says nothing", Equipment.madeOfLines(iron).length, 0);
   Equipment.settings = {quietTags: false, madeOf: 2};
   said("one of the quiet tags", Equipment.madeOfLines(iron).length, 0);
   Equipment.settings = {quietTags: true, madeOf: 2};
   said("nothing selected says nothing", Equipment.madeOfLines(undefined).length, 0);
   Equipment.plugin = () => undefined;
   said("with no plugin the material stands in", Equipment.madeOfLines(iron).join(" / "), "Hergestellt aus / Iron");
   Equipment.plugin = () => ({Stats: () => ({madeOf: [{name: "", count: 2}, {name: "Firewood", count: 1}]})});
   said("a part with no name is left out", Equipment.madeOfLines(iron).join(" / "), "Hergestellt aus / Firewood");

   // a station that writes what its recipe takes under the numbers keeps the corner empty, the inventory doesn't
   const station = {extra: {_visible: true}};
   Equipment.crafting = true;
   said("a forge's line of ingredients sends the corner away", Equipment.madeOfAway(station), true);
   station.extra._visible = false;
   said("a station with no such line keeps it", Equipment.madeOfAway(station), false);
   Equipment.crafting = false;
   station.extra._visible = true;
   said("the inventory keeps it", Equipment.madeOfAway(station), false);

   // the sheet: Off, Material, Components between two arrows, the step goes to the plugin under the menu's id and the
   // window is laid out at once, quiet without the quiet tags and with the card left in the UI's place
   const told = [];
   let laid = 0;
   freshPanel.context.gfx.io = {GameDelegate: {call: () => undefined}};
   Equipment.plugin = () => undefined;
   Equipment.readSettings();
   said("Components is the default", Equipment.settings.madeOf, 2);
   said("in words", [0, 1, 2].map((value) => Equipment.lookWords("madeOf", value)).join(" | "), "Off | Material | Components");
   expect("no step past Components", Equipment.lookStepped("madeOf", 1), 2);
   Equipment.plugin = () => ({SetSetting: (id, value) => told.push(id + "=" + value)});
   Equipment.look = {lines: []};
   Equipment.showWindow = () => laid++;
   Equipment.stepLook("madeOf", -1);
   Equipment.stepLook("madeOf", -1);
   said("each step goes to the plugin under the menu's id", told.join(";"), "iMadeOf:Lines=1;iMadeOf:Lines=0");
   said("and lays the window out at once", laid, 2);
   expect("no step under Off", Equipment.lookStepped("madeOf", -1), 0);
   Equipment.stepLook("madeOf", -1);
   said("a step past the end tells nothing", told.length + " " + laid, "2 2");
   Equipment.stepLook("madeOf", 1);
   Equipment.stepLook("madeOf", 1);
   said("and back to Components", Equipment.settings.madeOf + " " + told[told.length - 1], "2 iMadeOf:Lines=2");
   Equipment.settings.quietTags = false;
   said("quiet without the quiet tags", Equipment.lookQuiet("madeOf"), true);
   Equipment.settings.quietTags = true;
   Equipment.window = {};
   Equipment.leftCard = true;
   said("quiet with the card in the UI's place", Equipment.lookQuiet("madeOf"), true);
   Equipment.leftCard = false;
   said("counts with the card in the window", Equipment.lookQuiet("madeOf"), false);
}

// The corner in the window: at the top left of the model's room under the frame's edge, in the small lines' size and
// ink, as wide as its words up to its share of the room, the names too long for it cut short. PlacePreview gets the
// corner's right and bottom edges with the air the model keeps, from the room's middle in shares of the screen's
// height, and nothing of a corner while it's empty
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   const near = (value) => Math.round(value * 1000) / 1000;
   const placed = [];
   const styled = [];
   // fields whose letters are 0.3 of their size wide and whose lines are 1.306 of it high plus the leading, as the
   // small lines measure in the game (three lines at 12 were 47 high)
   const pitch = 12 * 1.306;
   const madeField = () => {
      const field = {_x: 0, _y: 0, _width: 10, _height: 10, text: "", format: {size: 12, leading: 0}};
      field.getNewTextFormat = () => Object.assign({}, field.format);
      field.setNewTextFormat = (format) => Object.assign(field.format, format);
      Object.defineProperty(field, "textWidth", {get: () => Math.max(0, ...String(field.text).split("\n").map((one) => one.length)) * field.format.size * 0.3});
      Object.defineProperty(field, "textHeight", {get: () => String(field.text) == "" ? 0 : String(field.text).split("\n").length * (field.format.size * 1.306 + field.format.leading)});
      return field;
   };
   const field = madeField();
   const side = madeField();
   const lines = (one) => String(one.text).split("\n").join(" / ");
   Equipment.styleText = (one, size, align, ink) => (one.format.size = size, styled.push(size + " " + align + " " + ink));
   Equipment.settings = {quietTags: true, madeOf: 2, quietText: 100};
   const window = {_x: 600, _y: 100, wide: 340, across: 1, preview: 130, high: 400, madeOf: field, madeOfSide: side, madeOfLines: ["Made from", "Leather Strips (3)", "Iron Ingot (5)"], sheet: {framed: true}, hole: {top: 20}};
   Equipment.window = window;
   Equipment.windowWide = () => 340;
   const top = 20 + Equipment.WINDOW_PAD / 2;
   const columnsWide = (Math.min((340 - 2 * Equipment.WINDOW_PAD) * Equipment.MADE_OF_TWO_WIDE, 340 - Equipment.STATS_PAD - Equipment.LENS_SIZE - Equipment.WINDOW_PAD) - Equipment.MADE_OF_COLUMN_GAP) / 2;

   // a short list as the iron armor shows it: the head over the parts in one column at its own spacing
   Equipment.placeMadeOf(window);
   said("in the small lines' size and ink", styled[styled.length - 1], Equipment.BODY_SLOTS_TEXT + " left " + Equipment.inkOf("quiet"));
   said("the head over its parts", lines(field), "Made from / Leather Strips (3) / Iron Ingot (5)");
   said("at the room's left under the frame's edge", field._x + "," + field._y, Equipment.STATS_PAD + "," + top);
   said("as wide as its widest words", near(field._width), near("Leather Strips (3)".length * 12 * 0.3 + 4));
   said("as high as its lines at their own spacing", near(field._height) + " " + field.format.leading, near(3 * pitch + 4) + " 0");
   said("one column", field._visible + " " + side._visible, "true false");
   said("laid as the first way", JSON.stringify(window.madeOfWay), JSON.stringify({head: true, columns: 1, tight: false, size: 12, rows: 3, counted: false}));
   Equipment.settings.quietText = 150;
   Equipment.placeMadeOf(window);
   said("at the small lines' size the player set", field.format.size, Math.round(Equipment.BODY_SLOTS_TEXT * 1.5));
   Equipment.settings.quietText = 100;

   // Steel Plate Armor: a window low on the screen left the room 114 high, four parts and the head didn't fit and two
   // parts went under a count. The head goes, every part stays
   window.preview = 114;
   window.madeOfLines = ["Made from", "Iron Ingot", "Steel Ingot (3)", "Leather Strips (3)", "Corundum Ingot"];
   Equipment.placeMadeOf(window);
   said("Steel Plate Armor's four parts without the head", lines(field), "Iron Ingot / Steel Ingot (3) / Leather Strips (3) / Corundum Ingot");
   said("still one column at its own spacing", side._visible + " " + field.format.leading + " " + field.format.size, "false 0 12");
   window.preview = 106;
   window.madeOfLines = ["Made from", "Iron Ingot", "Refined Moonstone (4)", "Quicksilver Ingot", "Leather Strips (3)"];
   Equipment.placeMadeOf(window);
   said("Elven Gilded Armor's four in a room 106 high", lines(field), "Iron Ingot / Refined Moonstone (4) / Quicksilver Ingot / Leather Strips (3)");

   // six parts where four lines fit take two columns of three, the second clear of the lens in the top right
   const six = ["Made from", "Dwarven Metal Ingot (2)", "Refined Moonstone (4)", "Quicksilver Ingot", "Leather Strips (3)", "Firewood", "Crafting Feathers (5)"];
   window.madeOfLines = six;
   Equipment.placeMadeOf(window);
   said("the first column", lines(field), "Dwarven Metal Ingot (2) / Refined Moonstone (4) / Quicksilver Ingot");
   said("the second", lines(side), "Leather Strips (3) / Firewood / Crafting Feathers (5)");
   said("side by side at the top", near(side._x) + "," + side._y, near(field._x + field._width + Equipment.MADE_OF_COLUMN_GAP) + "," + top);
   said("each within its share", field._width <= columnsWide && side._width <= columnsWide, true);
   said("the second clear of the lens", side._x + side._width <= 340 - Equipment.LENS_SIZE - Equipment.WINDOW_PAD, true);
   said("no name cut at this size", (lines(field) + lines(side)).indexOf("...") < 0, true);
   said("at their own spacing", field.format.leading + " " + side.format.leading, "0 0");
   const both = Equipment.madeOfBox(window);
   said("the corner's box takes both columns", near(both.xMax - both.xMin) + " " + near(both.yMax - both.yMin), near(side._x + side._width - field._x) + " " + near(3 * pitch + 4));

   // the smallest room at twice the size: two columns, lines closer, letters smaller till all six are there
   Equipment.settings.quietText = 200;
   window.preview = Equipment.PREVIEW_LEAST;
   Equipment.placeMadeOf(window);
   said("all six at twice the size in the smallest room", (lines(field) + " / " + lines(side)).split(" / ").length, 6);
   said("laid closer at smaller letters", JSON.stringify(window.madeOfWay), JSON.stringify({head: false, columns: 2, tight: true, size: 18, rows: 3, counted: false}));
   said("the lines closer by a fifth of the letters", field.format.leading, -4);
   said("and inside the room", field._y + field._height <= Equipment.PREVIEW_LEAST - Equipment.WINDOW_PAD, true);
   Equipment.settings.quietText = 100;

   // a count only past every other way, and never of one or two parts. The smallest room holds twelve at the smallest
   // letters, fourteen show eleven and count three, thirteen show all thirteen a row lower
   const many = (count) => ["Made from"].concat(Array.from({length: count}, (_, i) => "Part " + (i + 1)));
   window.madeOfLines = many(12);
   Equipment.placeMadeOf(window);
   said("twelve parts fit at the smallest letters", (lines(field) + " / " + lines(side)).split(" / ").length + " " + window.madeOfWay.size + " " + window.madeOfWay.counted, "12 " + Equipment.MADE_OF_SMALLEST + " false");
   window.madeOfLines = many(14);
   Equipment.placeMadeOf(window);
   said("fourteen, eleven and the count", lines(field) + " | " + lines(side), "Part 1 / Part 2 / Part 3 / Part 4 / Part 5 / Part 6 | Part 7 / Part 8 / Part 9 / Part 10 / Part 11 / and 3 more");
   said("counted", window.madeOfWay.counted, true);
   window.madeOfLines = many(13);
   Equipment.placeMadeOf(window);
   said("thirteen, none hidden for a count of two", (lines(field) + " / " + lines(side)).split(" / ").length + " " + (lines(field) + lines(side)).indexOf("more"), "13 -1");
   said("a row past the room for them", window.madeOfWay.rows + " " + window.madeOfWay.counted, "7 false");

   // the room grows for a long list where the window has room: the head and six parts at their own spacing want a room
   // 146 high under a frame edge of 20, a short list keeps the usual 130
   Equipment.frameEdge = () => 20;
   Equipment.chargeListUp = () => false;
   Equipment.crafting = false;
   Equipment.windowEntry = () => ({formId: 7, formType: 26});
   Equipment.plugin = () => ({Stats: () => ({madeOf: six.slice(1).map((name) => ({name: name.replace(/ \(\d\)$/, ""), count: (name.match(/\((\d)\)$/) || [0, 1])[1]}))})});
   Equipment.fillMadeOf(window);
   said("the whole list's height", near(window.madeOfNeed), near(7 * pitch + 4));
   said("the room it wants", Equipment.previewWanted(window), Math.ceil(20 + Equipment.WINDOW_PAD / 2 + 7 * pitch + 4 + Equipment.WINDOW_PAD));
   window.preview = Equipment.previewWanted(window);
   Equipment.placeMadeOf(window);
   said("in that room the head and all six in one column", lines(field), six.join(" / "));
   said("at their own spacing", side._visible + " " + field.format.leading, "false 0");
   Equipment.plugin = () => ({Stats: () => ({madeOf: [{name: "Iron Ingot", count: 5}, {name: "Leather Strips", count: 3}]})});
   Equipment.fillMadeOf(window);
   said("a short list wants the usual room", Equipment.previewWanted(window), Equipment.PREVIEW_HEIGHT);
   window.madeOfLines = [];
   window.madeOfNeed = 0;
   said("so does none", Equipment.previewWanted(window), Equipment.PREVIEW_HEIGHT);
   window.preview = 130;

   window.madeOfLines = ["Made from", "Dwarven Metal Ingot of the Deep Halls (2)"];
   Equipment.placeMadeOf(window);
   said("a name past its share of the room is cut short", lines(field).endsWith("..."), true);
   said("and keeps to that share", field._width <= (340 - 2 * Equipment.WINDOW_PAD) * Equipment.MADE_OF_WIDE, true);
   window.madeOfLines = [];
   Equipment.placeMadeOf(window);
   said("no lines, no corner", field._visible + " " + side._visible + " '" + field.text + "'", "false false ''");
   said("and no box", Equipment.madeOfBox(window), undefined);

   // the corner goes to the plugin with the room
   Equipment.plugin = () => ({PlacePreview: (...args) => placed.push(args.map(near).join(","))});
   Equipment.share = (x, y) => ({x: x / 1280, y: y / 720});
   Equipment.ownCardNow = () => false;
   Equipment.inspecting = false;
   window.madeOfLines = ["Made from", "Iron Ingot (4)", "Leather Strips (3)"];
   Equipment.placeMadeOf(window);
   Equipment.aimPreview();
   const pad = Equipment.WINDOW_PAD;
   const middleX = 600 + 170;
   const middleY = 100 + (20 + 130) / 2;
   const room = [middleX / 1280, middleY / 720, (130 - 2 * pad) / 720, (130 - 20 - 2 * pad) / 720, (340 - 2 * pad) / 720];
   const right = (600 + field._x + field._width + Equipment.MADE_OF_GAP - middleX) / 720;
   const down = (100 + field._y + field._height + Equipment.MADE_OF_GAP - middleY) / 720;
   said("the room with the corner's right and bottom edges from its middle", placed[0], room.concat([0, right, down]).map(near).join(","));
   said("three lines end left of the middle", right < 0, true);
   said("the room is kept in the panel's units", [window.modelRoom.xMin, window.modelRoom.yMin, window.modelRoom.xMax, window.modelRoom.yMax].join(","), [600 + pad, 100 + 20 + pad, 940 - pad, 230 - pad].join(","));
   window.madeOfLines = [];
   Equipment.placeMadeOf(window);
   Equipment.aimPreview();
   said("an empty corner leaves the room as it was", placed[1], room.map(near).join(","));
   // a slot's window stands square, a window over a row in the list's proportions: the corner's width goes along
   window.across = 1.5;
   window.madeOfLines = ["Made from", "Iron"];
   Equipment.placeMadeOf(window);
   const box = Equipment.madeOfBox(window);
   said("the corner across the window's proportions", near(box.xMax - box.xMin), near(field._width * 1.5));
   said("boxes that share area meet", Equipment.boxesMeet({xMin: 0, yMin: 0, xMax: 10, yMax: 10}, {xMin: 9, yMin: 9, xMax: 20, yMax: 20}), true);
   said("boxes edge to edge don't", Equipment.boxesMeet({xMin: 0, yMin: 0, xMax: 10, yMax: 10}, {xMin: 10, yMin: 0, xMax: 20, yMax: 10}), false);
}

// A broken recipe of a mod in the corner. Html letters, a key with no words, Cyrillic and CJK stay plain letters, a
// line break or a tab becomes a space, a name of 500 letters is cut, a count of 0 or less says no count and a huge one
// stays whole. 200 parts take 32 places and count the rest, with those the plugin left out. Every layout ends inside
// the room whatever comes, a name of 500 letters wide and narrow mixed is cut in a few measures, and nothing of the
// corner waits for a frame
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   const entry = {formId: 0x1000800, formType: 26, keywords: {}};
   let told = {};
   Equipment.plugin = () => ({Stats: () => told, Clock: () => 0});
   Equipment.settings = {quietTags: true, madeOf: 2, quietText: 100};
   const lines = () => Equipment.madeOfLines(entry);
   const parts = (count) => Array.from({length: count}, (_, i) => ({name: "Part " + (i + 1), count: 1}));

   told = {madeOf: [
      {name: "<b>Bold</b> & <i>\"Helm\"</i> 100% <font size='40'>X</font>", count: 2},
      {name: "Line\nbreak\tand\rreturn", count: 1},
      {name: "$IRStressNoSuchKey", count: 3},
      {name: "Залізний злиток", count: 4},
      {name: "鋼のインゴット", count: 5},
      {name: "   ", count: 2},
      {name: "", count: 2},
      {count: 2},
      null,
   ]};
   said("hostile names stay letters on one line, the empty ones go", lines().join(" / "),
      "Made from / <b>Bold</b> & <i>\"Helm\"</i> 100% <font size='40'>X</font> (2) / Line break and return / $IRStressNoSuchKey (3) / Залізний злиток (4) / 鋼のインゴット (5)");
   const long = "Ab".repeat(250);
   told = {madeOf: [{name: long, count: 1}]};
   said("a name of 500 letters is cut to 200 with its dots", lines()[1], long.substr(0, Equipment.MADE_OF_NAME_MOST) + "...");
   told = {madeOf: [{name: "Zero", count: 0}, {name: "Below", count: -5}, {name: "Most", count: 2147483647}, {name: "Past", count: 1e12}, {name: "Half", count: 2.6}, {name: "Word", count: "7"}, {name: "Nothing", count: "many"}]};
   said("counts of 0 or less say none, a huge one stays whole and no more than an int", lines().slice(1).join(" / "), "Zero / Below / Most (2147483647) / Past (2147483647) / Half (3) / Word (7) / Nothing");

   told = {madeOf: parts(200)};
   let made = Equipment.madeOfList(entry);
   said("200 parts take the head and 32 places, the rest counted", made.lines.length + " " + made.lines[32] + " " + made.more, "33 Part 32 168");
   told = {madeOf: parts(32), madeOfMore: 88};
   made = Equipment.madeOfList(entry);
   said("the parts the plugin left out of 120 are counted", made.lines.length + " " + made.more, "33 88");
   told = {madeOf: parts(40), madeOfMore: 88};
   said("and both together", Equipment.madeOfList(entry).more, 96);
   told = {madeOf: []};
   said("no parts and no material say nothing", lines().length, 0);
   told = {madeOf: [], madeOfMore: 5};
   said("a count with no part to show says nothing either", JSON.stringify(Equipment.madeOfList(entry)), JSON.stringify({lines: [], more: 0}));
   told = {madeOf: {length: 1e9}};
   said("a list that claims a billion places reads 32 of them", lines().length, 0);
   told = {madeOf: "nonsense"};
   said("words in place of a list say nothing", lines().length, 0);
   told = undefined;
   said("nothing told says nothing", lines().length, 0);

   // the corner laid out in the window, fields that measure like the game's small lines
   const madeField = () => {
      const field = {_x: 0, _y: 0, _width: 10, _height: 10, text: "", format: {size: 12, leading: 0}, measures: 0};
      field.getNewTextFormat = () => Object.assign({}, field.format);
      field.setNewTextFormat = (format) => Object.assign(field.format, format);
      Object.defineProperty(field, "textWidth", {get: () => (field.measures++, Math.max(0, ...String(field.text).split("\n").map((one) => one.length)) * field.format.size * 0.3)});
      Object.defineProperty(field, "textHeight", {get: () => String(field.text) == "" ? 0 : String(field.text).split("\n").length * (field.format.size * 1.306 + field.format.leading)});
      return field;
   };
   const field = madeField();
   const side = madeField();
   const shownLines = () => (side._visible ? String(field.text) + "\n" + String(side.text) : String(field.text)).split("\n");
   const pad = Equipment.WINDOW_PAD;
   Equipment.styleText = (one, size) => (one.format.size = size);
   const window = {_x: 600, _y: 100, wide: 340, across: 1, preview: Equipment.PREVIEW_LEAST, high: 400, madeOf: field, madeOfSide: side, sheet: {framed: true}, hole: {top: 20}, _visible: true};
   Equipment.window = window;
   Equipment.windowWide = () => 340;
   Equipment.windowEntry = () => entry;
   Equipment.chargeListUp = () => false;
   Equipment.crafting = false;
   Equipment.frameEdge = () => 20;
   const inside = () => field._y + field._height <= window.preview - pad + 0.5 && (!side._visible || side._y + side._height <= window.preview - pad + 0.5);

   told = {madeOf: parts(200)};
   Equipment.fillMadeOf(window);
   Equipment.placeMadeOf(window);
   let all = shownLines();
   said("200 parts in the smallest room end in a count of all the rest", all[all.length - 1] + " " + all.length, "and 189 more 12");
   said("at the smallest letters in two columns, lines closer", JSON.stringify(window.madeOfWay), JSON.stringify({head: false, columns: 2, tight: true, size: Equipment.MADE_OF_SMALLEST, rows: 6, counted: true}));
   said("inside the room", inside(), true);
   Equipment.settings.quietText = 300;
   Equipment.placeMadeOf(window);
   said("at three times the size the letters still come down to the smallest", window.madeOfWay.size + " " + inside(), Equipment.MADE_OF_SMALLEST + " true");
   Equipment.settings.quietText = 100;

   // 120 parts where the plugin sent 32: in a room that holds them all, the count of the 88 ends the list
   window.preview = 900;
   told = {madeOf: parts(32), madeOfMore: 88};
   Equipment.fillMadeOf(window);
   Equipment.placeMadeOf(window);
   all = shownLines();
   said("every part sent and the count of the rest", all.length + " " + all[all.length - 1] + " " + window.madeOfWay.counted, "34 and 88 more true");
   said("the whole list's height counts that line too", Math.round(window.madeOfNeed), Math.round(34 * 12 * 1.306 + 4));
   said("still inside the room", inside(), true);

   // one part with a name of 500 letters: cut to its column in a few measures
   window.preview = 130;
   told = {madeOf: [{name: "W".repeat(500), count: 2}]};
   Equipment.fillMadeOf(window);
   field.measures = 0;
   Equipment.placeMadeOf(window);
   said("a name of 500 letters cut to its column", shownLines()[1].endsWith("...") && field._width <= (340 - 2 * pad) * Equipment.MADE_OF_WIDE, true);
   said("in a handful of measures", field.measures <= 12, true);
   const widths = (words) => words.split("").reduce((sum, letter) => sum + (letter == "W" ? 20 : 2), 0);
   let measured = 0;
   const counting = (words) => (measured++, widths(words));
   said("wide letters first, narrow after, cut where it fits", Equipment.cutToFit("W".repeat(100) + "i".repeat(400), 300, counting), "W".repeat(14) + "...");
   said("by halves, not letter by letter", measured <= 2 + Math.ceil(Math.log2(500)), true);
   measured = 0;
   said("a guess that fits stays", Equipment.cutToFit("i".repeat(400) + "W".repeat(100), 300, counting), "i".repeat(54) + "...");
   said("after two measures", measured, 2);

   // a room of nothing or of no number still ends, and so does an empty list
   for (const preview of [0, -50, NaN]) {
      window.preview = preview;
      told = {madeOf: parts(200)};
      Equipment.fillMadeOf(window);
      Equipment.placeMadeOf(window);
      said(`a room of ${preview} ends`, window.madeOfWay != undefined, true);
   }
   window.preview = 130;
   told = {madeOf: []};
   Equipment.fillMadeOf(window);
   Equipment.placeMadeOf(window);
   said("an empty recipe leaves no corner", field._visible + " " + side._visible + " " + window.madeOfMore, "false false 0");

   // the test report lays the corner once more under the plugin's clock
   const logged = [];
   freshPanel.context.skse.Log = (words) => logged.push(words);
   Equipment.screenRect = () => ({x: 0, y: 0, width: 1280, height: 720});
   told = {madeOf: parts(32), madeOfMore: 88};
   Equipment.fillMadeOf(window);
   Equipment.placeMadeOf(window);
   Equipment.madeOfReport("broken");
   said("the report counts the parts left out and the time", /88 more, [\s\S]*laid again in 0 ms/.test(logged[0]), true);

   // the corner lays out when the window does, nothing of it runs every frame
   const corner = fs.readFileSync(path.join(source, "36-made-of.as"), "utf8");
   said("no frame handler or timer in the corner's part", /onEnterFrame|setInterval|setTimeout/.test(corner), false);
}

// quiet lines, junk, weight warnings, the queue of many moves
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(true);
   Equipment.settings = {quietTags: true, modOrigin: true, questLine: true, slotNumbers: false, junk: true, weightWarnings: true, newMarks: true};
   const mine = (more) => Object.assign({side: 2048, formType: 32, count: 1, infoWeight: 1}, more);
   const theirs = (more) => Object.assign({side: 4096, formType: 32, count: 1, infoWeight: 1}, more);
   Equipment.ownFlags = () => [2048];
   said("a quest keeps it", Equipment.questLine({equipmentQuest: 1, equipmentQuestName: "The Golden Claw"}), "Still needed for The Golden Claw");
   said("a quest follows it", Equipment.questLine({equipmentQuest: 2, equipmentQuestName: "Delivery"}), "Still needed, Delivery follows it");
   said("an objective names it", Equipment.questLine({equipmentQuest: 3, equipmentQuestName: "Few and Far Between"}), "Still needed, Few and Far Between asks for it");
   said("the quest is done", Equipment.questLine({equipmentQuest: 4, equipmentQuestName: "Bleak Falls"}), "No longer needed, Bleak Falls is done");
   said("a quest with no name", Equipment.questLine({equipmentQuest: 1}), "Still needed for a quest");
   said("a running quest points at it", Equipment.questLine({equipmentQuest: 5, equipmentQuestName: "Lost Legacy"}), "Still needed for Lost Legacy");
   said("a quest of a place with no name", Equipment.questLine({equipmentQuest: 5, equipmentQuestName: "Shroud Hearth Barrow", equipmentQuestPlace: true}), "Still needed for a quest at Shroud Hearth Barrow");
   said("a quest not begun", Equipment.questLine({equipmentQuest: 6, equipmentQuestName: "Lost Legacy"}), "Needed later, Lost Legacy hasn't begun");
   said("a place's quest not begun", Equipment.questLine({equipmentQuest: 6, equipmentQuestName: "Shroud Hearth Barrow", equipmentQuestPlace: true}), "Needed later for a quest at Shroud Hearth Barrow");
   said("a quest that is over", Equipment.questLine({equipmentQuest: 7, equipmentQuestName: "Shroud Hearth Barrow", equipmentQuestPlace: true}), "No longer needed, the quest at Shroud Hearth Barrow is over");
   said("an unnamed quest that is over", Equipment.questLine({equipmentQuest: 7}), "No longer needed, its quest is over");
   said("how many you have, in a chest", Equipment.quietLines(theirs({equipmentCarried: 3})).join("|"), "You have 3");
   said("nothing of it on your own row", Equipment.quietLines(mine({equipmentCarried: 3})).join("|"), "");
   said("silver and the plugin", Equipment.quietLines(mine({keywords: {WeapMaterialSilver: true}, equipmentOrigin: "Silverware.esp"})).join("|"), "Silver|From Silverware.esp");
   Equipment.settings.modOrigin = false;
   said("the plugin's line switched off alone", Equipment.quietLines(mine({keywords: {WeapMaterialSilver: true}, equipmentOrigin: "Silverware.esp"})).join("|"), "Silver");
   Equipment.settings.modOrigin = true;
   Equipment.settings.linesOff = 1 << 2;
   said("silver switched off on its own", Equipment.quietLines(mine({keywords: {WeapMaterialSilver: true}, equipmentOrigin: "Silverware.esp"})).join("|"), "From Silverware.esp");
   Equipment.settings.linesOff = 1 << 1;
   said("and how many you have", Equipment.quietLines(theirs({equipmentCarried: 3})).join("|"), "");
   Equipment.settings.linesOff = 0;
   const wanted = mine({equipmentQuest: 1, equipmentQuestName: "The Golden Claw", equipmentOrigin: "Claws.esp"});
   Equipment.settings.quietTags = false;
   said("the quest's line stays with the quiet tags off", Equipment.quietLines(wanted).join("|"), "Still needed for The Golden Claw");
   Equipment.settings.quietTags = true;
   Equipment.settings.questLine = false;
   said("the quest's line off, the quiet tags stay", Equipment.quietLines(wanted).join("|"), "From Claws.esp");
   Equipment.settings.questLine = true;
   expect("a plain keyword is no silver", Equipment.silver({keywords: {SilverSword: true}}) ? 1 : 0, 0);
   expect("worn stays", Equipment.locked(mine({equipState: 1})) ? 1 : 0, 1);
   expect("a favorite stays", Equipment.locked(mine({favorite: true})) ? 1 : 0, 1);
   expect("what a quest keeps stays", Equipment.locked(mine({equipmentQuest: 1})) ? 1 : 0, 1);
   expect("what a done quest left may go", Equipment.locked(mine({equipmentQuest: 4})) ? 1 : 0, 0);
   expect("what a running quest points at stays", Equipment.locked(mine({equipmentQuest: 5})) ? 1 : 0, 1);
   expect("what a quest not begun wants stays", Equipment.locked(mine({equipmentQuest: 6})) ? 1 : 0, 1);
   expect("what an ended quest wanted may go", Equipment.locked(mine({equipmentQuest: 7})) ? 1 : 0, 0);
   const rows = [mine({formId: 1, text: "Bone", equipmentJunk: true}), mine({formId: 2, text: "Cup", equipmentJunk: true, favorite: true}), theirs({formId: 3, text: "Pot", equipmentJunk: true}), mine({formId: 4, text: "Gem"})];
   Equipment.menu.inventoryLists.itemList = {entryList: rows, requestUpdate: () => {}};
   said("junk that may go", Equipment.junkRows().map((row) => row.text).join(","), "Bone");
   let carry = {carried: 290, most: 300};
   Equipment.plugin = () => ({Carry: () => carry});
   Equipment.kind = "container";
   const heavy = [theirs({infoWeight: 20}), theirs({infoWeight: 4, count: 5}), theirs({infoWeight: 2}), mine({infoWeight: 50})];
   Equipment.tintWeights(heavy, [2048]);
   expect("one is too heavy", heavy[0].equipmentWeightColor, Equipment.TOO_HEAVY);
   expect("the whole stack is too heavy", heavy[1].equipmentWeightColor, Equipment.HEAVY_STACK);
   expect("it fits", heavy[2].equipmentWeightColor, undefined);
   expect("your own rows say nothing", heavy[3].equipmentWeightColor, undefined);
   carry = {carried: 90000, most: 2000000};
   Equipment.tintWeights(heavy, [2048]);
   expect("no real limit, no warning", heavy[0].equipmentWeightColor, undefined);
   carry = {carried: 1990, most: 2000};
   said("taking all says its weight and what goes over", Equipment.takeAllWords("Gems", [theirs({infoWeight: 4, count: 5})]), "Take all Gems (5), weight 20, 10 over your limit");
   said("what the chest holds already", Equipment.heldThere([mine({formId: 3, text: "Pot"}), mine({formId: 4, text: "Gem"})]).map((row) => row.text).join(","), "Pot");
   Equipment.menu.itemCard = {addEventListener: () => {}};
   Equipment.menu.createEmptyMovieClip = () => ({});
   Equipment.menu.getNextHighestDepth = () => 1;
   Equipment.closeContext = () => {};
   Equipment.pickRow = () => true;
   const moves = [];
   Equipment.menu.onQuantityMenuSelect = (event) => moves.push(event.amount);
   let result;
   Equipment.menu.inventoryLists.itemList = {entryList: [mine({formId: 1, text: "Bone", count: 3}), mine({formId: 5, text: "Rag", count: 2})]};
   Equipment.startQueue([mine({formId: 1, text: "Bone"}), mine({formId: 5, text: "Rag"})], (moved, kept, stopped) => result = [moved, kept, stopped]);
   Equipment.queueTick();
   Equipment.queueTick();
   expect("the first whole stack moves", moves[0], 3);
   Equipment.menu.inventoryLists.itemList.entryList = [mine({formId: 5, text: "Rag", count: 2})];
   Equipment.queueListed();
   Equipment.queueTick();
   Equipment.queueTick();
   expect("then the next one", moves[1], 2);
   Equipment.queueListed();
   Equipment.queueTick();
   said("a row the game kept is counted", String(result), "1,1,false");
   moves.length = 0;
   const stolenDaggers = mine({formId: 9, text: "Dagger", count: 3, equipmentStolen: 3});
   Equipment.menu.inventoryLists.itemList = {entryList: [mine({formId: 9, text: "Dagger", count: 2}), stolenDaggers]};
   Equipment.startQueue([stolenDaggers], (moved, kept, stopped) => result = [moved, kept, stopped]);
   Equipment.queueTick();
   Equipment.queueTick();
   expect("the stolen row of an item moves, not its own row beside it", moves[0], 3);
   Equipment.menu.inventoryLists.itemList.entryList = [mine({formId: 9, text: "Dagger", count: 2})];
   Equipment.queueListed();
   Equipment.queueTick();
   said("it went and the own row stays", String(result), "1,0,false");
   const marks = freshPanel(false);
   marks.settings = {newMarks: true};
   expect("new until the pointer passed", marks.isNew({equipmentNew: true, formId: 7}) ? 1 : 0, 1);
   marks.newSeen.f7 = true;
   expect("passed once it stays seen in the menu", marks.isNew({equipmentNew: true, formId: 7}) ? 1 : 0, 0);
}

// the queue moves the rows the filters hide and never a worn row of the same name as one it moves
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(true);
   Equipment.settings = {junk: true};
   Equipment.ownFlags = () => [2048];
   const mine = (more) => Object.assign({side: 2048, formType: 32, count: 1}, more);
   // SkyUI's list selects only a row its filters let through, the category in view shows armor. A worn helmet and
   // its spare are two rows of one name, the spare is junk
   const list = {
      _selectedIndex: -1,
      disableSelection: false,
      getListEnumIndex(index) { return this.entryList[index] !== undefined && this.entryList[index].formType == 26 ? index : undefined; },
      get selectedIndex() { return this._selectedIndex; },
      set selectedIndex(index) { if (!this.disableSelection && (index == -1 || this.getListEnumIndex(index) !== undefined)) this._selectedIndex = index; },
      get selectedEntry() { return this.entryList[this._selectedIndex]; },
   };
   const listed = (entries) => {
      list.entryList = entries;
      entries.forEach((entry, index) => entry.itemIndex = index);
      list._selectedIndex = -1;
   };
   const worn = mine({formId: 9, formType: 26, text: "Iron Helmet", equipState: 1, equipmentJunk: true});
   const spare = mine({formId: 9, formType: 26, text: "Iron Helmet", equipmentJunk: true});
   const bone = mine({formId: 4, text: "Bone", count: 2, equipmentJunk: true});
   const moves = [];
   let result;
   Equipment.menu.inventoryLists.itemList = list;
   Equipment.menu.inventoryLists.dispatchEvent = () => {};
   Equipment.menu.itemCard = {addEventListener: () => {}};
   Equipment.menu.createEmptyMovieClip = () => ({});
   Equipment.menu.getNextHighestDepth = () => 1;
   Equipment.closeContext = () => {};
   Equipment.menu.onQuantityMenuSelect = (event) => moves.push((list.selectedEntry === worn ? "worn " : "") + list.selectedEntry.text + " x" + event.amount);
   listed([worn, spare, bone]);
   said("junk of both kinds may go", Equipment.junkRows().map((row) => row.text).join(","), "Iron Helmet,Bone");
   Equipment.startQueue(Equipment.junkRows(), (moved, kept, stopped) => result = [moved, kept, stopped]);
   Equipment.queueTick();
   Equipment.queueTick();
   said("the spare goes and the worn helmet of the same name stays", moves[0], "Iron Helmet x1");
   listed([worn, bone]);
   Equipment.queueListed();
   Equipment.queueTick();
   Equipment.queueTick();
   said("a row the category hides goes too", moves[1], "Bone x2");
   listed([worn]);
   Equipment.queueListed();
   Equipment.queueTick();
   said("both are counted as moved", String(result), "2,0,false");
   listed([worn, spare]);
   list.disableSelection = true;
   Equipment.startQueue([spare], (moved, kept, stopped) => result = [moved, kept, stopped]);
   Equipment.queueTick();
   Equipment.queueTick();
   Equipment.queueTick();
   said("a row the list won't select stays and is counted", String(result), "0,1,false");
}

// the two ways to sort go into the columns a UI mod brings under its own names
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   Equipment.plugin = () => ({});
   Equipment.settings = {lastAdded: true, stackWeight: true};
   const weight = (order) => ({sortAttributes: ["infoWeight", "text"], label: {text: "$WGT", arrowDown: order}});
   const columns = {
      gearNameColumn: {type: 3, states: 2, state1: {sortAttributes: ["text"]}, state2: {sortAttributes: ["text"]}},
      bookNameColumn: {type: 3, states: 2, state1: {sortAttributes: ["text"]}, state2: {sortAttributes: ["text"]}},
      itemWtColumn: {type: 2, states: 2, state1: weight(true), state2: weight(false)},
      itemTWtColumn: {type: 2, states: 2, state1: {sortAttributes: ["infoTotalWeight", "text"]}, state2: {}},
   };
   Equipment.addSorting({ListLayout: {columns}});
   said("last added in the names of gear", columns.gearNameColumn.state2.label.text, "LAST ADDED");
   expect("and of books", columns.bookNameColumn.states, 3);
   said("the sum in the weight of one item", columns.itemWtColumn.state2.label.text, "SUMW");
   expect("both ways of it", columns.itemWtColumn.states, 4);
   said("the weight of one item stays first", columns.itemWtColumn.state1.label.text, "$WGT");
   expect("a total weight column of its own is left alone", columns.itemTWtColumn.states, 2);

   // Kome's Inventory Tweaks brings an iconColumn with nothing in it, ActionScript 2 looped forever over its states
   Equipment.sortingAdded = false;
   const bare = {iconColumn: {}, nameColumn: {type: 3}};
   Equipment.addSorting({ListLayout: {columns: bare}});
   said("a column with no states stays as it came", JSON.stringify(bare.iconColumn), "{}");
   said("a name column with no states gets none", bare.nameColumn.states, undefined);
   said("a loop bound of nothing counts nothing", Equipment.count(undefined), 0);
   said("nor of a word", Equipment.count("some"), 0);
   said("a count written as text still counts", Equipment.count("2"), 2);
}

// a gamepad walks the panel: two columns of five slots, a strip between a slot and the doll, the subcategories above
// the top row, the drawer under the bottom one, the buttons of a slot window left and right
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const where = (at) => at.kind + (at.column !== undefined ? ` ${at.column},${at.row}` : "") + (at.cell !== undefined ? ` ${at.cell}` : "") + (at.index !== undefined ? ` ${at.index}` : "") + (at.scroll !== undefined ? ` scroll ${at.scroll}` : "");
   const slot = (column, row) => ({kind: "slot", column, row});
   const plain = {rows: 5, chips: 0, chipStart: 0, hero: false, heroOpen: false, last: slot(1, 0)};
   const world = (extra) => Object.assign({}, plain, extra || {});
   const go = (at, way, extra) => where(Equipment.padNext(at, way, world(extra)));

   said("down a column", go(slot(0, 1), "down"), "slot 0,2");
   said("up a column", go(slot(1, 3), "up"), "slot 1,2");
   said("the left column goes right across the doll", go(slot(0, 2), "right"), "slot 1,2");
   said("the right column goes left across the doll", go(slot(1, 2), "left"), "slot 0,2");
   said("nothing past the outer edge", go(slot(0, 2), "left"), "slot 0,2");
   said("nothing past the right edge", go(slot(1, 2), "right"), "slot 1,2");
   said("the top row without subcategories stays", go(slot(0, 0), "up"), "slot 0,0");
   said("the top row goes up to the subcategories, the chosen one first", go(slot(1, 0), "up", {chips: 6, chipStart: 2}), "chip 2");
   said("the bottom row without the drawer stays", go(slot(1, 4), "down"), "slot 1,4");
   said("the bottom row goes down to the drawer", go(slot(1, 4), "down", {hero: true}), "hero");

   const ring = {strip: {column: 0, row: 4, cells: 4}};
   said("toward the doll into the strip of the slot", go(slot(0, 4), "right", ring), "mini 0");
   said("another slot passes its strip", go(slot(0, 3), "right", ring), "slot 1,3");
   said("along the strip", go({kind: "mini", cell: 1}, "right", ring), "mini 2");
   said("the strip ends", go({kind: "mini", cell: 3}, "right", ring), "mini 3");
   said("back along the strip", go({kind: "mini", cell: 2}, "left", ring), "mini 1");
   said("out of the strip back to its slot", go({kind: "mini", cell: 0}, "left", ring), "slot 0,4");
   said("up out of the strip", go({kind: "mini", cell: 2}, "up", ring), "slot 0,3");
   const other = {strip: {column: 1, row: 4, cells: 3}};
   said("a strip of the right column goes left", go(slot(1, 4), "left", other), "mini 0");
   said("and its pieces go on to the left", go({kind: "mini", cell: 0}, "left", other), "mini 1");
   said("right goes back toward its slot", go({kind: "mini", cell: 1}, "right", other), "mini 0");

   said("along the subcategories", go({kind: "chip", index: 2}, "right", {chips: 4}), "chip 3");
   said("the subcategories end", go({kind: "chip", index: 3}, "right", {chips: 4}), "chip 3");
   said("and start", go({kind: "chip", index: 0}, "left", {chips: 4}), "chip 0");
   said("down from the subcategories to the top of the last column", go({kind: "chip", index: 1}, "down", {chips: 4, last: slot(0, 3)}), "slot 0,0");
   said("nothing above the subcategories", go({kind: "chip", index: 1}, "up", {chips: 4}), "chip 1");

   said("up from a closed drawer to the last column", go({kind: "hero"}, "up", {hero: true, last: slot(0, 2)}), "slot 0,4");
   said("left from the drawer", go({kind: "hero"}, "left", {hero: true}), "slot 0,4");
   said("right from the drawer", go({kind: "hero"}, "right", {hero: true}), "slot 1,4");
   said("an open drawer scrolls up", go({kind: "hero"}, "up", {hero: true, heroOpen: true}), "hero scroll -1");
   said("and down", go({kind: "hero"}, "down", {hero: true, heroOpen: true}), "hero scroll 1");

   const window = {actions: 3, anchor: slot(1, 1)};
   said("along the buttons of a window", go({kind: "action", index: 0}, "right", window), "action 1");
   said("the buttons end", go({kind: "action", index: 2}, "right", window), "action 2");
   said("down leaves the window as from its slot", go({kind: "action", index: 1}, "down", window), "slot 1,2");
   said("a window of a piece leaves as from the piece", go({kind: "action", index: 0}, "up", Object.assign({actions: 2, anchor: {kind: "mini", cell: 2}}, ring)), "slot 0,3");
}

// the buttons of a gamepad on the panel: A presses, B steps back, X works the eye, a held button acts once, and a B
// that left the panel or closed the inspect view doesn't go on to close the menu while it's held
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const done = [];
   const key = (value, nav, code) => ({value, navEquivalent: nav, skseKeycode: code});
   Equipment.panel = {};
   Equipment.padBuilt = true;
   Equipment.menu._platform = 1;
   Equipment.padFocus = {kind: "slot", column: 0, row: 0};
   Equipment.padLast = Equipment.padFocus;
   Equipment.padMove = (way) => done.push(way);
   Equipment.padPress = () => done.push("press");
   Equipment.padBack = () => done.push("back");
   Equipment.padHide = () => done.push("hide");
   Equipment.padSettle = () => undefined;
   Equipment.listsAnswer = () => true;
   said("a move on the panel", Equipment.padInput(key("keyDown", "down")), true);
   said("a held move repeats", Equipment.padInput(key("keyHold", "down")), true);
   said("A presses", Equipment.padInput(key("keyDown", "enter-gamepad_A", 276)), true);
   said("its hold is kept from the list", Equipment.padInput(key("keyHold", "enter-gamepad_A", 276)), true);
   said("and its let go", Equipment.padInput(key("keyUp", "enter-gamepad_A", 276)), true);
   said("X by its code", Equipment.padInput(key("keyDown", undefined, 278)), true);
   said("a shoulder goes on to SkyUI's sort", Equipment.padInput(key("keyDown", undefined, 275)), false);
   said("what the panel did", done.join(","), "down,down,press,hide");
   done.length = 0;
   Equipment.padBack = () => { done.push("back"); Equipment.padFocus = undefined; };
   said("B as the game sends it", Equipment.padInput(key("keyDown", "tab", 277)), true);
   said("B held after it left the panel stays off the list", Equipment.padInput(key("keyHold", "tab", 277)), true);
   said("its let go too", Equipment.padInput(key("keyUp", "tab", 277)), true);
   said("the next B on the list is SkyUI's", Equipment.padInput(key("keyDown", "tab", 277)), false);
   Equipment.padFocus = {kind: "slot", column: 0, row: 0};
   Equipment.listsAnswer = () => false;
   said("a dialog of SkyUI over the lists takes the cross", Equipment.padInput(key("keyDown", "down")), false);
   Equipment.listsAnswer = () => true;
   Equipment.padFocus = undefined;
   said("B stepped back once", done.join(","), "back");
   said("a move on the list is SkyUI's", Equipment.padInput(key("keyDown", "down")), false);

   const zoom = [];
   Equipment.plugin = () => ({InspectZoom: (factor) => zoom.push(factor > 1 ? "in" : "out"), InspectTurn: (yaw) => zoom.push("turn " + yaw)});
   Equipment.INSPECT_ZOOM = 1.15;
   Equipment.inspecting = true;
   said("up in the inspect view", Equipment.padInput(key("keyDown", "up")), true);
   said("down in the inspect view", Equipment.padInput(key("keyDown", "down")), true);
   said("left in the inspect view", Equipment.padInput(key("keyDown", "left")), true);
   said("the view zooms and turns", zoom.join(","), "in,out,turn -15");
   said("B in the inspect view goes to the view, which closes", Equipment.padInput(key("keyDown", "escape-gamepad_B", 277)), false);
   Equipment.inspecting = false;
   said("and held after it stays off the list", Equipment.padInput(key("keyHold", "escape-gamepad_B", 277)), true);

   Equipment.menu._platform = 0;
   Equipment.padFocus = {kind: "slot", column: 0, row: 0};
   said("the keyboard never comes here", Equipment.padInput(key("keyDown", "down")), false);
   said("which button is which", ["enter-gamepad_A", "tab", "escape-gamepad_B", "shifttab"].map((nav) => Equipment.padButton(nav, undefined)).join(",") + "," + Equipment.padButton(undefined, 278), "press,back,back,back,hide");
}

// the way back from the panel, the inspect view closing under the panel, and the bottom bar that holds six at most
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const calls = [];
   const buttons = [];
   const list = {selectedIndex: -1, getListEnumIndex: (index) => index < 10 ? index : undefined};
   const clip = () => ({clear: () => undefined});
   const menu = Object.assign(Equipment.menu, {
      _platform: 1,
      createEmptyMovieClip: clip,
      getNextHighestDepth: () => 1,
      handleInput: () => true,
      updateBottomBar: () => calls.push("skyui bar"),
      SetPlatform: () => undefined,
      navPanel: {clearButtons: () => { buttons.length = 0; }, addButton: (data) => buttons.push(data.text), updateButtons: () => undefined},
      _acceptControls: {}, _cancelControls: {},
   });
   menu.inventoryLists.itemList = list;
   menu.inventoryLists.zoomButtonHolder = {};
   Object.assign(Equipment, {panel: {}, viewer: {}, window: {_visible: false}, hero: {_visible: true, high: 0}, actions: {}, chips: {}, settings: {popup: true, pieceStrips: true}});
   Equipment.under = Equipment.over = {createEmptyMovieClip: clip, getNextHighestDepth: () => 1};
   Equipment.plugin = () => ({PadTurns: (what) => calls.push("turns " + what)});
   Equipment.leaveInspect = () => { Equipment.inspecting = false; };
   Equipment.closePopup = () => undefined;
   Equipment.closePieces = () => undefined;
   Equipment.closeContext = () => undefined;
   // the inspect part and the slots built on screen aren't loaded here, a helmet in the head slot stands in
   const helmet = {name: "head", entries: [{formId: 1}], box: {}};
   Equipment.inspectable = () => true;
   Equipment.padCell = () => helmet;
   Equipment.hasPieces = () => false;
   Equipment.canToggle = () => true;
   Equipment.looksHidden = () => false;
   Equipment.buildPad();
   Equipment.padMark = () => calls.push("mark");
   Equipment.padUnmark = () => undefined;

   Equipment.padFocus = {kind: "slot", column: 1, row: 0};
   Equipment.padKept = 4;
   list.selectedIndex = 7;
   Equipment.leavePad(false);
   said("a row the panel found stays selected on the list", list.selectedIndex, 7);
   Equipment.padFocus = {kind: "slot", column: 1, row: 0};
   Equipment.padKept = 4;
   list.selectedIndex = -1;
   Equipment.leavePad(false);
   said("with none found the row it came from comes back", list.selectedIndex, 4);
   said("and the stick turns nothing on the list", calls.filter((one) => one.startsWith("turns")).pop(), undefined);

   calls.length = 0;
   Equipment.padFocus = {kind: "slot", column: 1, row: 0};
   Equipment.inspecting = true;
   Equipment.leaveInspect();
   said("the inspect view closed by B marks the focus again", calls.includes("mark"), true);
   said("and the stick turns the doll again", calls.filter((one) => one.startsWith("turns")).pop(), "turns 1");

   // the most a state of the panel asks of the bar: a slot with a piece that hides and can be inspected
   Equipment.padHints();
   said("a slot with a piece", buttons.join(" | "), "Details | Hide | Back | List | Inspect (hold)");
   Equipment.look = {_visible: false};
   Equipment.lookButton = {_visible: true};
   Equipment.padHints();
   said("Y for the sheet of the look makes six", buttons.join(" | "), "Details | Hide | Look | Back | List | Inspect (hold)");
   Equipment.look = undefined;
   Equipment.padFocus = {kind: "hero"};
   Equipment.hero.high = 200;
   Equipment.padCell = () => undefined;
   Equipment.padHints();
   said("the open drawer", buttons.join(" | "), "Close | Scroll | Back | List");
   Equipment.padFocus = undefined;
   buttons.length = 0;
   ["Equip", "Drop", "Favorite", "Charge"].forEach((text) => buttons.push(text));
   list.selectedEntry = {formId: 2};
   Equipment.padListHint();
   said("the list with a row that charges, SkyUI's four and two more", buttons.length, 6);
}

// the quest sign of a row: gold while needed, dimmer gold for a quest not begun, grey once over, and it stands
// before the junk sign so the two never overlap
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   Equipment.plugin = () => undefined;
   Equipment.readSettings();
   const look = (kind) => Equipment.questLook(kind).color + "/" + Equipment.questLook(kind).alpha;
   said("held by a running quest", look(1), Equipment.GOLD + "/100");
   said("followed by a quest", look(2), Equipment.GOLD + "/100");
   said("named by an objective", look(3), Equipment.GOLD + "/100");
   said("pointed at by a running quest", look(5), Equipment.GOLD + "/100");
   said("wanted by a quest not begun", look(6), Equipment.GOLD + "/" + Equipment.QUEST_LATER);
   said("its quest done", look(4), Equipment.inkOf("quiet") + "/" + Equipment.QUEST_DONE);
   said("its quest over", look(7), Equipment.inkOf("quiet") + "/" + Equipment.QUEST_DONE);
   said("no quest, no sign", Equipment.questShown({equipmentQuest: 0}), false);
   said("a done quest still has its sign", Equipment.questShown({equipmentQuest: 4}), true);
   const row = {bestIcon: {_width: 10}};
   const field = {_x: 10, _width: 100};
   const both = {equipmentQuest: 1, equipmentJunk: true};
   const icons = Equipment.iconsEnd(row, field, both, {});
   const junkAt = Equipment.questEnd(row, field, both, {});
   expect("the junk sign starts after the quest sign", junkAt, icons + Equipment.QUEST_SIGN + Equipment.ICON_GAP);
   expect("the arrow after both", Equipment.afterIcons(row, field, both, {}), junkAt + Equipment.JUNK_SIGN + Equipment.ICON_GAP);
   expect("junk alone stands where the icons end", Equipment.questEnd(row, field, {equipmentJunk: true}, {}), icons);
   Equipment.settings.questMarks = false;
   said("switched off", Equipment.questShown({equipmentQuest: 1}), false);
   expect("and takes no room", Equipment.afterIcons(row, field, both, {}), icons + Equipment.JUNK_SIGN + Equipment.ICON_GAP);
}

// the stolen line of the item window counts the copies that belong to someone else
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   said("one stolen item", Equipment.stolenLine({count: 1, equipmentStolen: 1}), "Stolen");
   said("some of a stack", Equipment.stolenLine({count: 5, equipmentStolen: 3}), "Stolen: 3 of 5");
   said("a whole stack, a row of stolen copies of its own", Equipment.stolenLine({count: 4, equipmentStolen: 4}), "Stolen");
   said("nothing stolen", Equipment.stolenLine({count: 2, equipmentStolen: 0}), "");
   said("the game's own mark when the plugin counted none", Equipment.stolenLine({count: 2, isStolen: true}), "Stolen");
   said("never more than the stack", Equipment.stolenLine({count: 2, equipmentStolen: 5}), "Stolen");
   const own = {formId: 9, text: "Iron Dagger", count: 2};
   const stolen = {formId: 9, text: "Iron Dagger", count: 3, equipmentStolen: 3};
   expect("the stolen row of an item is told from its own row", Equipment.isRow(stolen, Equipment.rowKey(own)) ? 1 : 0, 0);
   expect("and the own row from the stolen one", Equipment.isRow(own, Equipment.rowKey(stolen)) ? 1 : 0, 0);
   expect("a stolen row found again by the game's mark alone", Equipment.isRow({formId: 9, text: "Iron Dagger", isStolen: true}, Equipment.rowKey(stolen)) ? 1 : 0, 1);
   const inChest = {equipmentStolen: 3, isStolen: false};
   const ownInChest = {equipmentStolen: 0};
   Equipment.fillStolen(inChest);
   Equipment.fillStolen(ownInChest);
   expect("a chest's row of stolen copies gets the stolen mark the game left off", inChest.isStolen ? 1 : 0, 1);
   expect("the own row beside it stays without", ownInChest.isStolen ? 1 : 0, 0);
   Equipment.window = {statLines: [], bodySlots: {_visible: false}, stolen: {_visible: true, _height: 18}};
   Equipment.anchorSlot = Equipment.slotNamed("body");
   expect("a slot window grows by the stolen line", Equipment.underCard(), 18 + Equipment.STOLEN_GAP + Equipment.ACTION_HIGH + 2 * Equipment.ACTION_GAP + Equipment.ACTION_EDGE);
   Equipment.window.stolen._visible = false;
   expect("and not without it", Equipment.underCard(), Equipment.ACTION_HIGH + 2 * Equipment.ACTION_GAP + Equipment.ACTION_EDGE);
}

// a click on a filled slot never touches the category, the chips, the search or the filter of a slot. A row the list
// shows is selected, one it hides is selected past the filters and opens the window of the slot
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const done = [];
   const listed = [2, 3];
   const list = {
      _selectedIndex: -1,
      entryList: [],
      listState: {},
      getListEnumIndex: (index) => listed.includes(index) ? listed.indexOf(index) : undefined,
      getClipByIndex: () => ({setEntry: () => done.push("redrawn")}),
      get selectedIndex() { return this._selectedIndex; },
      set selectedIndex(index) {
         if (index == -1 || listed.includes(index)) {
            this._selectedIndex = index;
            done.push("select " + index);
         }
      },
      get selectedEntry() { return this.entryList[this._selectedIndex]; },
   };
   const lists = Equipment.menu.inventoryLists;
   lists.itemList = list;
   lists.dispatchEvent = (event) => done.push("highlight " + event.index);
   lists.categoryList.onItemPress = () => done.push("category changed");
   Equipment.drawFrame = () => undefined;
   Equipment.openPopup = (slot) => { Equipment.anchorSlot = slot; done.push("window of " + slot.name); };
   Equipment.closePopup = () => done.push("closed");
   Equipment.settings = {popup: false};
   const helmet = {itemIndex: 3, text: "Helmet", clipIndex: 1};
   const boots = {itemIndex: 7, text: "Boots", clipIndex: 4};
   list.entryList[3] = helmet;
   list.entryList[7] = boots;
   const head = Object.assign(Equipment.slotNamed("head"), {entries: [helmet]});
   const feet = Object.assign(Equipment.slotNamed("feet"), {entries: [boots]});
   Equipment.showWorn(head, false);
   said("a row in the list is selected with the window under it", done.join(","), "closed,select 3");
   said("and no slot window", Equipment.anchorSlot, undefined);
   done.length = 0;
   Equipment.showWorn(feet, false);
   said("a row the list hides is selected past it, the row before drawn plain, and the slot opens its window", done.join(","), "redrawn,highlight 7,window of feet");
   said("the list's own index names it", list._selectedIndex, 7);
   said("its old row clip is forgotten", boots.clipIndex, undefined);
   list._selectedIndex = -1;
   Equipment.keepApart();
   said("a list made anew lets go of it, the window takes it back", list._selectedIndex, 7);
   said("nothing in the list was changed", done.join(",").indexOf("category"), -1);
   said("the list shows the helmet", Equipment.listShows(helmet), true);
   said("not the boots", Equipment.listShows(boots), false);
}

// a gamepad passes the slots the player took off the panel
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const where = (at) => at.kind + (at.column !== undefined ? ` ${at.column},${at.row}` : "");
   const slot = (column, row) => ({kind: "slot", column, row});
   const world = (extra) => Object.assign({rows: 5, chips: 0, chipStart: 0, hero: false, heroOpen: false, last: slot(1, 0)}, extra);
   const go = (at, way, extra) => where(Equipment.padNext(at, way, world(extra)));
   const column = ["0,0", "0,1", "0,2", "0,3", "0,4"];
   said("down past a slot off the panel", go(slot(0, 1), "down", {gone: ["0,2"]}), "slot 0,3");
   said("up past it", go(slot(0, 3), "up", {gone: ["0,2"]}), "slot 0,1");
   said("across to the nearest slot on the panel", go(slot(1, 2), "left", {gone: ["0,2"]}), "slot 0,1");
   said("from the subcategories to the first slot on", go({kind: "chip", index: 1}, "down", {chips: 4, last: slot(0, 3), gone: ["0,0"]}), "slot 0,1");
   said("the drawer from the last slot on", go(slot(1, 3), "down", {hero: true, gone: ["1,4"]}), "hero");
   said("a column all off, across stays", go(slot(1, 2), "left", {gone: column}), "slot 1,2");
   said("the drawer to a column all off goes to the other", go({kind: "hero"}, "left", {hero: true, gone: column}), "slot 1,4");
   Equipment.settings = {popup: false};
   Equipment.padCell = () => ({name: "head", entries: [{itemIndex: 1}]});
   Equipment.hasPieces = () => false;
   Equipment.listShows = () => false;
   said("A on a slot whose row the list hides opens its window", Equipment.padPressWords(slot(1, 0)), "Details");
   Equipment.listShows = () => true;
   said("one the list shows finds it", Equipment.padPressWords(slot(1, 0)), "Find in list");
}

// the sheet of the panel's look: its words, its steps within their range, what it tells the plugin, the slots off
// the panel and the width of the list
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const told = [];
   Equipment.plugin = () => undefined;
   Equipment.readSettings();
   said("full size", Equipment.lookWords("dollScale", 100), "100%");
   said("in the middle", Equipment.lookWords("dollRight", 0), "Middle");
   said("to the left", Equipment.lookWords("dollRight", -15), "15% left");
   said("up", Equipment.lookWords("dollUp", 10), "10% up");
   said("down", Equipment.lookWords("dollUp", -5), "5% down");
   said("a narrowed panel", Equipment.lookWords("panelSize", 88), "88%");
   said("a panel in the middle", Equipment.lookWords("panelShift", 0), "Middle");
   said("a panel moved left", Equipment.lookWords("panelShift", -6), "6% left");
   expect("a size step", Equipment.lookStepped("dollScale", 1), 105);
   Equipment.settings.dollScale = 140;
   expect("never past the largest", Equipment.lookStepped("dollScale", 1), 140);
   Equipment.settings.dollRight = -40;
   expect("never past the left end", Equipment.lookStepped("dollRight", -1), -40);
   expect("the minus narrows the panel", Equipment.lookStepped("panelSize", -1), 96);
   expect("a full panel can't widen", Equipment.lookStepped("panelSize", 1), 100);
   expect("a full panel has no room to move", Equipment.lookStepped("panelShift", 1), 0);
   said("so its Sideways goes quiet", Equipment.lookQuiet("panelShift"), true);
   Equipment.settings.panelSize = 88;
   expect("a narrowed one moves a step", Equipment.lookStepped("panelShift", 1), 2);
   Equipment.settings.panelShift = 6;
   expect("and no further than it narrowed", Equipment.lookStepped("panelShift", 1), 6);
   expect("the same to the left", (Equipment.settings.panelShift = -6, Equipment.lookStepped("panelShift", -1)), -6);

   Equipment.plugin = () => ({SetSetting: (id, value) => told.push(id + "=" + value)});
   Equipment.changeSetting("doll", "bShow:Doll", false);
   said("a switch goes to the plugin as a number under the menu's id", told[0], "bShow:Doll=0");
   said("and holds in the panel", Equipment.settings.doll, false);

   Equipment.settings.slotsOff = 1 << 2;
   said("the ammo slot is off", Equipment.slotShown(Equipment.slotNamed("ammo")), false);
   said("the ring slot is on", Equipment.slotShown(Equipment.slotNamed("ring")), true);
   said("a small slot goes with its slot", Equipment.slotShown({parent: Equipment.slotNamed("ammo")}), false);
   expect("the slots on the panel", Equipment.cells().length, 9);
   Equipment.closePopup = () => undefined;
   Equipment.closePieces = () => undefined;
   Equipment.layout = () => undefined;
   Equipment.showModels = () => undefined;
   Equipment.flipSlot(Equipment.slotNamed("ammo"));
   said("a slot put back is told by its own switch", told[1], "bShowAmmo:Slots=1");
   expect("and all are on again", Equipment.cells().length, 10);

   freshPanel.context.gfx.io = {GameDelegate: {call: () => undefined}};
   Equipment.look = {lines: []};
   Equipment.relayout = () => undefined;
   Object.assign(Equipment.settings, {panelSize: 76, panelShift: 12});
   Equipment.stepLook("panelSize", 1);
   said("a wider panel pulls its shift back into its room", told.slice(2).join(";"), "iPanelSize:Panel=80;iPanelShift:Panel=10");
   Equipment.stepLook("panelShift", -1);
   said("a step sideways goes alone", told.slice(4).join(";"), "iPanelShift:Panel=8");
}

// Width on the look sheet narrows the panel beside the list from both sides, so the character between the columns
// stays in the middle, Sideways moves it within what it narrowed. A skin or a screen whose list was measured short put
// the left column of slots over the rows
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const near = (value) => Math.round(value * 100) / 100;
   const laid = (size, shift) => {
      Object.assign(Equipment.settings, {panelSize: size, panelShift: shift});
      Equipment.layout();
      return {left: Equipment.frame.left, right: Equipment.frame.right};
   };
   Equipment.screenRect = () => ({x: 0, y: 0, width: 1280, height: 720});
   Equipment.safeInset = () => ({x: 0, y: 0});
   Equipment.listEdge = () => ({right: 600, wide: 560});
   Equipment.menu.bottomBar = {_y: 680};
   Equipment.placeStage = () => undefined;
   Equipment.SLOTS = [];
   Equipment.settings = {};
   const whole = laid(100, 0);
   const full = whole.right - whole.left;
   said("at full width the panel starts by the list", whole.left, 600 + Equipment.MARGIN / 2);
   const narrow = laid(76, 0);
   said("the narrowest keeps its share of that", near(narrow.right - narrow.left), near(full * 0.76));
   said("equal insets keep the middle", near((narrow.left + narrow.right) / 2), near((whole.left + whole.right) / 2));
   const moved = laid(76, 6);
   said("a shift moves the left column", near(moved.left - narrow.left), near(full * 0.06));
   said("and the right one as far", near(moved.right - narrow.right), near(full * 0.06));
   said("the right edge stops where it stands at full width", laid(76, 20).right, whole.right);
   said("the left one too", laid(76, -20).left, whole.left);
   const full20 = laid(100, 20);
   said("a full panel doesn't move", full20.left + "," + full20.right, whole.left + "," + whole.right);
   const old = laid(88, 6);
   said("88% and 6 right is the old Narrow", near(old.left), near(whole.right - full * 0.88));
   said("with its right edge where it was", old.right, whole.right);
}

// The item window's lines and the card's place on the sheet: a tick goes to the plugin under its own id, the rows
// draw their quest marks again at once, the mod's line goes quiet without the quiet tags, the card's place is a
// switch that waits for the next opening and the sheet says so, the doll's numbers alone go quiet without the doll
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   const told = [];
   let redrawn = 0;
   freshPanel.context.gfx.io = {GameDelegate: {call: () => undefined}};
   Equipment.plugin = () => undefined;
   Equipment.readSettings();
   Equipment.plugin = () => ({SetSetting: (id, value) => told.push(id + "=" + value)});
   Equipment.menu.inventoryLists.itemList = {UpdateList: () => redrawn++};
   Equipment.look = {lines: []};
   Equipment.showPlayer = () => undefined;

   Equipment.flipLook("stats");
   said("combat numbers off", told.join(";"), "bStats:Window=0");
   said("and off in the panel", Equipment.lookOn("stats"), false);
   said("the rows aren't drawn again for a window line", redrawn, 0);
   Equipment.flipLook("questMarks");
   said("quest marks go under the list's id", told[1], "bQuestMarks:List=0");
   said("and the rows lose them at once", redrawn, 1);
   said("the mod's line counts while the quiet tags are on", Equipment.lookQuiet("modOrigin"), false);
   Equipment.flipLook("quietTags");
   said("without them it's quiet", Equipment.lookQuiet("modOrigin"), true);
   Equipment.settings.doll = false;
   said("without the doll its size is quiet", Equipment.lookQuiet("dollScale"), true);
   said("the window's size isn't", Equipment.lookQuiet("windowSize"), false);

   const showWindow = Equipment.showWindow;
   Equipment.showWindow = () => undefined;
   Equipment.look._visible = true;
   Equipment.onHighlight({type: "showItemsList", index: 2});
   said("under the sheet a list's own event brings no window", Equipment.windowWanted, false);
   Equipment.look._visible = false;
   Equipment.onHighlight({type: "showItemsList", index: 2});
   said("with the sheet shut it does", Equipment.windowWanted, true);
   Equipment.showWindow = showWindow;

   Equipment.settings.doll = true;
   Equipment.window = {};
   Equipment.leftCard = false;
   said("the card in the window", Equipment.lookWords("leaveCard", 0), "In the window");
   expect("one step puts it in the UI's place", Equipment.lookStepped("leaveCard", 1), 1);
   expect("and no further", (Equipment.settings.leaveCard = true, Equipment.lookStepped("leaveCard", 1)), 1);
   Equipment.settings.leaveCard = false;
   Equipment.sizeWindow = Equipment.showWindow = Equipment.wantWindow = () => undefined;
   Equipment.stepLook("leaveCard", 1);
   said("kept as a switch", Equipment.settings.leaveCard, true);
   said("told as one", told[told.length - 1], "bLeaveCard:Window=1");
   said("the card stays as the menu opened", Equipment.leavesCard(), false);
   said("and the sheet says it waits", Equipment.cardLater(), true);
   Equipment.stepLook("leaveCard", -1);
   said("back as it opened, nothing waits", Equipment.cardLater(), false);
   Equipment.settings.windowShow = Equipment.WINDOW_OWN_CARD;
   said("with the UI's own card its place is quiet", Equipment.lookQuiet("leaveCard"), true);
   Equipment.ownCard = true;
   Equipment.settings.windowShow = 0;
   said("opened with the UI's own card, a window back waits for the next opening", Equipment.cardLater(), true);
   Equipment.settings.windowShow = Equipment.WINDOW_OWN_CARD;
   Equipment.settings.leaveCard = true;
   said("the UI's own card and the UI's place change nothing", Equipment.cardLater(), false);
   Equipment.settings.leaveCard = false;
   Equipment.settings.quietTags = true;
   said("the kind is quiet while the card stays the UI's", Equipment.lookQuiet("kind"), true);
   said("what it's made of with it", Equipment.lookQuiet("madeOf"), true);
   Equipment.ownCard = false;
   said("and counts with the card in the window", Equipment.lookQuiet("kind"), false);
   said("what it's made of too", Equipment.lookQuiet("madeOf"), false);
   Equipment.settings.quietTags = false;

   // the character switched off is only the model gone, the card goes where its own switches say
   Equipment.settings.windowShow = 0;
   Equipment.settings.doll = false;
   said("a doll switched off moves no card", Equipment.cardLater(), false);
   said("and leaves the card's place to say", Equipment.lookQuiet("leaveCard"), false);
   Equipment.settings.doll = true;
   Equipment.settings.windowShow = Equipment.WINDOW_OWN_CARD;

   told.length = 0;
   Equipment.flipLook("dps");
   said("a line of the numbers goes under its own id", told.join(";"), "bDPS:Numbers=0");
   expect("and is a bit of the numbers' mask", Equipment.settings.numbersOff, 2);
   said("the window drops just that line", Equipment.numberShown("dps") + " " + Equipment.numberShown("dpm"), "false true");
   Equipment.flipLook("dps");
   expect("back on", Equipment.settings.numbersOff, 0);
   Equipment.flipLook("stolen");
   said("a small line under its own id", told[2] + " " + Equipment.settings.linesOff, "bStolen:Lines=0 8");
   said("and the sheet shows it off", Equipment.lookOn("stolen"), false);
   Equipment.flipLook("stolen");
   Equipment.settings.stats = false;
   said("the lines of the numbers are quiet without the numbers", Equipment.lookQuiet("reach"), true);
   said("the kind is one of the quiet tags", Equipment.lookQuiet("kind"), true);
   said("so is what it's made of", Equipment.lookQuiet("madeOf"), true);
   said("the stolen line isn't", Equipment.lookQuiet("stolen"), false);

   let made = 0;
   Equipment.makeLook = () => made++;
   Equipment.turnLook("window");
   said("a tab turns the page", Equipment.lookPage + " " + made, "window 1");
   Equipment.turnLook("window");
   said("the page shown stays", made, 1);
}

// Text size on the Item window page: a head and a value between arrows for each of the five sizes, after the card's
// place and over the combat numbers, in the words of the translation file. A step is 10 from 80 to 200, goes to the
// plugin under the menu's id and lays out the window and the card where it stands at once. Six lines taller the page
// still keeps clear of SkyUI's bar on a 16:9 screen, 1280x720 and 1920x1080 alike, a skin's higher bar makes it smaller
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false, {"$IR_Card in the UI's place": "Karte am Platz der UI"});
   const context = freshPanel.context;
   const clip = () => {
      const made = {_x: 0, _y: 0, _xscale: 100, _yscale: 100};
      for (const call of ["clear", "lineStyle", "beginFill", "beginGradientFill", "endFill", "moveTo", "lineTo", "curveTo"]) {
         made[call] = () => undefined;
      }
      made.createEmptyMovieClip = (name) => (made[name] = clip(), made[name]._parent = made, made[name]);
      made.createTextField = (name, depth, x, y, wide, high) => (made[name] = {_x: x, _y: y, _width: wide, _height: high, setNewTextFormat: () => undefined}, made[name]);
      return made;
   };
   const told = [];
   let laid = 0;
   let carded = 0;
   context.TextFormat = function() {};
   context.flash = {geom: {Matrix: function() { this.createGradientBox = () => undefined; }}};
   context.gfx.io = {GameDelegate: {call: () => undefined}};
   Equipment.plugin = () => undefined;
   Equipment.readSettings();
   Equipment.look = clip();
   Equipment.lookPage = "window";
   Equipment.frame = {left: 600, top: 29};
   Equipment.menu.bottomBar = {_y: 662};
   Equipment.makeLook();
   const lines = Equipment.look.lines;
   const line = (key) => lines.find((one) => one.key == key);
   const keys = lines.map((one) => one.key).filter((key) => key != undefined);
   const sizes = ["nameText", "wordsText", "numbersText", "quietText", "cardText"].map(line);
   const heads = Object.keys(Equipment.look).filter((name) => name.startsWith("head")).map((name) => Equipment.look[name].t0.text);
   said("a head of its own after the window's", heads.slice(0, 3).join(" | "), "ITEM WINDOW | TEXT SIZE | COMBAT NUMBERS");
   said("five sizes after the card's place, before the numbers", keys.slice(keys.indexOf("leaveCard"), keys.indexOf("stats") + 1).join(" "), "leaveCard nameText wordsText numbersText quietText cardText stats");
   said("their words come through the translation file", sizes.map((one) => one.said).join(" | "), "Name | Effects and descriptions | Numbers | Small lines | Karte am Platz der UI");
   said("each a value between a minus and a plus", sizes.every((one) => one.kind == "size" && one.less != undefined && one.more != undefined), true);
   said("each at its size", sizes.map((one) => one.value.text).join(" "), "100% 100% 100% 100% 100%");
   said("a size in words", Equipment.lookWords("numbersText", 150), "150%");
   // Made from takes the row the material's tick left, the page stays 634 high and clear of SkyUI's bar
   said("the Item window page keeps its height", Equipment.look.high, 634);
   said("Made from steps through its values on a tick's row", line("madeOf").kind + " " + line("madeOf").high + " " + line("madeOf").value.text, "across " + Equipment.LOOK_SLOT_LINE + " Components");
   said("right under the quiet tags, the ticks after it in pairs", keys.slice(keys.indexOf("quietTags")).join(" "), "quietTags madeOf kind have silver modOrigin slotNumbers stolen questLine questMarks");
   said("its arrows within the line", line("madeOf").less._y >= 0 && line("madeOf").less._y + Equipment.LOOK_ARROW <= Equipment.LOOK_SLOT_LINE, true);

   const bottom = () => Equipment.look._y + Equipment.look.high * Equipment.look._yscale / 100;
   said("over SkyUI's bar the page keeps its size", Equipment.look._yscale, 100);
   said("rises over the panel's top within the screen", Equipment.look._y >= 0 && Equipment.look._y < 29, true);
   said("and stays clear of the bar", bottom() <= 662 - Equipment.MARGIN, true);
   Equipment.menu.bottomBar = {_y: 600};
   Equipment.placeLook();
   said("a higher bar makes it smaller", Equipment.look._yscale < 100, true);
   said("from the screen's top down to the bar", Equipment.look._y + " " + Math.round(bottom()), "0 " + (600 - Equipment.MARGIN));
   said("its left column stays by the slots", Math.round(Equipment.look._x + Equipment.look.wide * Equipment.look._yscale / 100), 600 - Equipment.POPUP_GAP);
   Equipment.menu.bottomBar = {_y: 662};
   Equipment.placeLook();

   expect("a step is ten", Equipment.lookStepped("nameText", 1), 110);
   Equipment.settings.wordsText = 80;
   expect("80 can't go lower", Equipment.lookStepped("wordsText", -1), 80);
   Equipment.settings.cardText = 200;
   expect("200 can't go higher", Equipment.lookStepped("cardText", 1), 200);
   Equipment.settings.quietText = 90;
   expect("down to 80 and no further", Equipment.lookStepped("quietText", -1), 80);
   Equipment.showLookValues();
   said("the minus at 80 goes faint", line("wordsText").less.can + " " + line("wordsText").more.can, "false true");
   said("the plus at 200 too", line("cardText").less.can + " " + line("cardText").more.can, "true false");
   Equipment.settings.stats = false;
   said("the numbers' size is quiet without the numbers", Equipment.lookQuiet("numbersText"), true);
   said("the card's size isn't", Equipment.lookQuiet("cardText"), false);
   Equipment.settings.stats = true;

   Equipment.plugin = () => ({SetSetting: (id, value) => told.push(id + "=" + value)});
   Equipment.showWindow = () => laid++;
   Equipment.cardNumbersLater = () => carded++;
   Equipment.stepLook("nameText", 1);
   said("a step goes to the plugin under the menu's id", told.join(";"), "iNameText:Window=110");
   said("and holds in the panel", Equipment.settings.nameText, 110);
   said("the window and the card where it stands are laid out again", laid + " " + carded, "1 1");
   said("the sheet shows the new size", line("nameText").value.text, "110%");
   Equipment.stepLook("cardText", 1);
   said("a step past the end tells nothing and lays out nothing", told.length + " " + laid + " " + carded, "1 1 1");
   Equipment.stepLook("cardText", -1);
   said("the card's size steps down", told[1], "iCardText:Window=190");
   said("and lays out again", laid + " " + carded, "2 2");
}

// With the card left in the UI's place no window comes over the rows, the card shows the item. A row's Details bring
// its window up whatever Pops up says, until another row is selected. With the card at home the window takes the
// card and the model along and gives them back, a card left for the skin stays the skin's
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   Equipment.plugin = () => undefined;
   Equipment.readSettings();
   Equipment.leftCard = true;
   Equipment.menu.inventoryLists.itemList = {selectedEntry: {formId: 5, text: "Iron Sword"}};
   Equipment.wantWindow(true);
   said("no window over the rows at once", Equipment.windowWanted, false);
   const holder = {_x: 700, _y: 400, _xscale: 90, _yscale: 90, _visible: true};
   const remade = [];
   const card = {_parent: holder, background: {_visible: true}, StolenTextInstance: {_visible: false}, gotoAndStop: (frame) => remade.push(frame)};
   Equipment.menu.itemCard = card;
   Equipment.sizeWindow = () => undefined;
   let numbersAgain = 0;
   Equipment.cardNumbersLater = () => numbersAgain++;
   Equipment.cardNumbers = {_visible: true};
   Equipment.cardFrameAsSkyUI = () => undefined;
   const shown = Equipment.showWindow;
   Equipment.showWindow = () => undefined;
   Equipment.pinWindow({formId: 5, text: "Iron Sword"});
   said("Details bring the window up", Equipment.windowWanted, true);
   said("with the card and the model", Equipment.leavesCard() + " " + Equipment.ownCardNow(), "false false");
   said("the card's numbers step out", Equipment.cardNumbers._visible, false);
   said("the card is laid out anew for the window", remade.join(","), "Empty");
   Equipment.wantWindow(false);
   said("a list laid out anew lets the card go home", Equipment.cardBorrowed == true, false);
   Equipment.wantWindow(true);
   said("and the row back takes it again", Equipment.windowWanted + " " + Equipment.leavesCard(), "true false");
   holder._x = 250;
   holder._yscale = 120;
   card.background._visible = false;
   Equipment.menu.inventoryLists.itemList.selectedEntry = {formId: 6, text: "Iron Dagger"};
   Equipment.wantWindow(true);
   said("another row lets it go", Equipment.windowWanted + " " + Equipment.pinnedRow, "false undefined");
   said("the card goes home as it was", holder._x + " " + holder._yscale + " " + card.background._visible, "700 90 true");
   said("laid out anew each way", remade.length, 4);
   said("and stays the UI's again, its numbers laid out each time it came home", Equipment.leavesCard() + " " + Equipment.ownCardNow() + " " + numbersAgain, "true true 2");
   // a slot's window takes the card along too, the card at home and the window lay over each other
   Equipment.anchorSlot = {name: "feet", entries: [{formId: 7, text: "Ebony Boots"}]};
   Equipment.menu.inventoryLists.itemList.selectedEntry = {formId: 7, text: "Ebony Boots"};
   Equipment.wantWindow(true);
   said("a slot's window takes the card", Equipment.cardBorrowed + " " + Equipment.leavesCard(), "true false");
   Equipment.anchorSlot = undefined;
   Equipment.wantWindow(false);
   said("and gives it back as it closes", Equipment.cardBorrowed + " " + Equipment.leavesCard(), "false true");
   Equipment.ownCard = false;
   Equipment.leftCard = true;
   Equipment.settings.windowShow = Equipment.WINDOW_AT_ONCE;
   Equipment.menu.inventoryLists.itemList.selectedEntry = {formId: 6, text: "Iron Dagger"};
   Equipment.wantWindow(true);
   said("the card left in the UI's place brings no window over the rows", Equipment.windowWanted + " " + Equipment.leavesCard() + " " + Equipment.ownCardNow(), "false true true");
   Equipment.settings.windowShow = Equipment.WINDOW_AFTER_REST;
   Equipment.wantWindow(true);
   said("not after a pause either", Equipment.restSince, undefined);
   Equipment.pinWindow({formId: 6, text: "Iron Dagger"});
   said("its Details take the card and the model along as with the character off", Equipment.windowWanted + " " + Equipment.leavesCard() + " " + Equipment.ownCardNow(), "true false false");
   Equipment.menu.inventoryLists.itemList.selectedEntry = {formId: 5, text: "Iron Sword"};
   Equipment.wantWindow(true);
   said("and lets it go home", Equipment.ownCardNow(), true);
   Equipment.leftCard = Equipment.ownCard = false;
   Equipment.settings.windowShow = Equipment.WINDOW_AFTER_REST;
   Equipment.pinWindow({formId: 5, text: "Iron Sword"});
   said("after a pause too, at once", Equipment.windowWanted + " " + (Equipment.cardBorrowed == true), "true false");
   Equipment.showWindow = shown;
}

// Skins built on SkyUI 5 with paper looks, Dear Diary here: weapon kinds, the first strip, the list's picture,
// the card's paper, the bottom bar laid out around its hints, inks on the panel's own dark boxes
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   const weapon = (subType, anim, worn) => ({formType: W.WEAPON, subType: subType, weaponType: anim, infoDamage: 10, equipState: worn || 0});

   // SkyUI 5 menus number keyword kinds from 13 (spear 13, pike 15, halberd 16, rapier 17, gun 23), SkyUI 6 has its
   // fishing rod at 13. The game's own kind of swing decides the hands
   const halberd = weapon(16, 6);
   const pike = weapon(15, 5);
   const rapier = weapon(17, 1);
   const katana = weapon(21, 11);
   const gun = weapon(23, 9);
   const fishingRod = weapon(13, 1);
   said("a halberd is two handed", Equipment.twoHanded(halberd), true);
   said("and not one handed", Equipment.oneHanded(halberd), false);
   said("its chip is Two-Handed", Equipment.chipHolds("twoHanded", halberd), true);
   said("a pike's kind under its name", Equipment.kindLine(pike), "Two-Handed");
   said("a pike swings like a greatsword", Equipment.swingOf(pike), Equipment.SWING.twoHanded);
   said("a rapier fits the left hand", Equipment.fits(rapier, Equipment.slotNamed("left")), true);
   said("a rapier's chip is One-Handed", Equipment.chipHolds("oneHanded", rapier), true);
   said("a katana of the second ten of kinds is one handed", Equipment.oneHanded(katana), true);
   said("a gun on a crossbow's swing is ranged", Equipment.ranged(gun), true);
   said("and shoots bolts", Equipment.shoots(gun, bolt(10)), true);
   said("but no arrows", Equipment.shoots(gun, arrow(10)), false);
   said("SkyUI 6's fishing rod stays one handed", Equipment.oneHanded(fishingRod), true);
   said("a row with no kind of the game goes by SkyUI's numbers", Equipment.twoHanded(greatsword(18)), true);
   said("a bow with no kind of the game", Equipment.ranged(bow(9)), true);
   Equipment.place(Equipment.worn([weapon(16, 6, 4)], undefined));
   said("a halberd in both hands takes the left one", Equipment.slotNamed("left").taken, true);

   // The list starts with no strip. A menu with no call to fit its list keeps its own height until a strip opens
   const fresh = freshPanel(false);
   const lists = fresh.menu.inventoryLists;
   const list = {_y: 100, listHeight: 480, entryHeight: 24, _maxListIndex: 20, requestUpdate() {}};
   lists.showItemsList = () => undefined;
   lists.addEventListener = () => undefined;
   lists.panelContainer = {createEmptyMovieClip: () => ({}), getNextHighestDepth: () => 1};
   lists.itemList = list;
   fresh.settings = {subcategories: false};
   fresh.showChips = () => undefined;
   fresh.menu.createEmptyMovieClip = () => ({});
   fresh.menu.getNextHighestDepth = () => 1;
   fresh.startRows({});
   fresh.openStrip(false);
   expect("no strip at the start leaves a SkyUI 5 list as it is", list.listHeight, 480);
   expect("and in its place", list._y, 100);
   fresh.openStrip(true);
   expect("a strip cuts it", list.listHeight, 450);
   expect("and moves it down", list._y, 130);
   fresh.openStrip(false);
   expect("and gives the height back", list.listHeight, 480);
   // Edge UI lays a picture of the whole screen inside the list, it stays on the screen as the list moves
   const context = freshPanel.context;
   list.backdrop = Object.assign(new context.MovieClip(), {_y: -68, getBounds: () => ({yMin: -68, yMax: 654})});
   list.header = Object.assign(new context.MovieClip(), {_y: 3, getBounds: () => ({yMin: 3, yMax: 40})});
   fresh.openStrip(true);
   expect("the list moves down", list._y, 130);
   expect("its backdrop stays where it was on the screen", list._y + list.backdrop._y, 100 - 68);
   expect("the column names go with the list", list.header._y, 3);
   fresh.openStrip(false);
   expect("and back with the strip gone", list._y + list.backdrop._y, 100 - 68);

   // Dear Diary's page and binder reach 80 past the rows, the window keeps to the rows
   lists.getContentBounds = () => [-21, 0, 641, 720];
   lists._x = 16;
   lists.itemList = {getBounds: () => ({xMin: 35, xMax: 577})};
   expect("the slots keep clear of the whole picture", fresh.listEdge().right, 661);
   expect("what lies over the list ends at the rows", fresh.rowsEdge().right, 581);
   expect("and is as wide as the page less what hangs past them", fresh.rowsEdge().wide, 561);
   lists.getContentBounds = () => [0, 0, 557, 720];
   lists._x = 0;
   lists.itemList = {getBounds: () => ({xMin: 35, xMax: 578})};
   expect("SkyUI's own frame", fresh.rowsEdge().right, fresh.listEdge().right);
   lists.itemList = {getBounds: () => ({xMin: 35, xMax: 575})};
   lists.getContentBounds = () => [0, 0, 430, 720];
   expect("a list SkyUI narrowed keeps its frame", fresh.rowsEdge().right, 455);
   // a crafting menu with no picture behind its rows (Edge UI) ends where the rows do
   lists.getContentBounds = () => [undefined, undefined, undefined, undefined];
   lists.itemList = {getBounds: () => ({xMin: 30, xMax: 550})};
   expect("no picture, the rows end the list", fresh.listEdge().right, 550 + fresh.LIST_FRAME);
   expect("as wide as the rows", fresh.listEdge().wide, 520);

   // SkyUI's hints stand under the bar's corner, Dear Diary's over it in the strip of its binder
   fresh.menu.bottomBar = {_y: 645, _yscale: 100, buttonPanel: {_y: 15}};
   expect("SkyUI's bar starts at its corner", fresh.barTop(), 645);
   fresh.menu.bottomBar.buttonPanel._y = -35;
   expect("Dear Diary's at its hints", fresh.barTop(), 610);
   delete fresh.menu.bottomBar;

   // the card's paper of Dear Diary has a clear margin of 20, SkyUI's frame starts at the card's corner
   const card = (box, scale) => ({_xscale: scale, _parent: {_width: 900, _xscale: 100}, background: {_width: box.xMax - box.xMin, getBounds: () => box}});
   fresh.menu.itemCard = card({xMin: -19.75, yMin: -20, xMax: 448.25, yMax: 205}, 100);
   expect("the paper of a picture counts without its margin", fresh.cardWidth(), 428.5);
   expect("and from the card's corner", fresh.frameBox(fresh.menu.itemCard).xMin, 0);
   expect("its bottom too", fresh.frameBox(fresh.menu.itemCard).yMax, 185.25);
   fresh.menu.itemCard = card({xMin: 0, yMin: 0, xMax: 427.85, yMax: 221.65}, 85);
   expect("SkyUI's frame at Vel'dun's 85%", fresh.cardWidth(), 427.85 * 0.85);
   fresh.menu.itemCard = {_xscale: 100, _parent: {_width: 500, _xscale: 50}, background: {_width: 0}};
   expect("a frame still loading leaves the holder", fresh.cardWidth(), 1000);

   // the look sheet is a dark box of its own on any skin
   fresh.readSkin({Appearance: {colors: {text: {enabled: 0x141414}}}});
   said("quiet words over paper", fresh.inkOf("quiet"), 0x54473A);
   said("quiet words on the look sheet over paper", fresh.inkOf("quiet", true), 0x9C978B);
   said("a sign on paper", fresh.inkOf("sign"), 0x2A2420);
   fresh.readSkin({});
   said("a sign on a dark skin", fresh.inkOf("sign"), fresh.PARCHMENT);

   // The kind line goes under the name and what stands under it moves down a line. Vel'dun's fields of numbers are
   // taller than their figures and reach up past the bottom of the name's letters
   {
      const same = {localToGlobal: () => undefined, globalToLocal: () => undefined};
      const kindCard = (numbersTop) => {
         const made = Object.assign({_visible: true, _alpha: 100, parts: []}, same);
         const part = (name, top, bottom) => (made[name] = {_name: name, _parent: made, _visible: true, _alpha: 100, _x: 0, _y: top, _width: 300, _height: bottom - top});
         made.ItemText = {_name: "ItemText", _parent: made, _visible: true, _alpha: 100, getBounds: () => ({xMin: 40, xMax: 260, yMin: 30, yMax: 70}), ItemTextField: {_y: 0, textHeight: 26, getTextFormat: () => ({align: made.nameAlign})}, localToGlobal: (point) => (point.y += 30)};
         made.nameAlign = "center";
         part("ItemType", 10, 24);
         part("ArmorValue", numbersTop, numbersTop + 34);
         part("ArmorLabel", 96, 110);
         made.createTextField = (name) => {
            const field = {_name: name, _parent: made, _visible: false, _alpha: 100, _x: 0, _y: 0, _width: 0, _height: 0, format: {}};
            field.getNewTextFormat = () => Object.assign({}, field.format);
            field.setNewTextFormat = (format) => (field.format = format);
            field.setTextFormat = () => undefined;
            return (made[name] = field);
         };
         return made;
      };
      fresh.settings = {quietTags: true};
      fresh.styleText = () => undefined;
      fresh.windowEntry =() => ({formType: 26, weightClass: 1, partMask: 4, subTypeDisplay: "Body"});
      fresh.menu.itemCard = kindCard(52);
      fresh.kindMoved = undefined;
      fresh.layKind();
      said("Vel'dun's numbers that reach up into the name move down", fresh.menu.itemCard.ArmorValue._y, 52 + fresh.KIND_LINE);
      said("and their labels", fresh.menu.itemCard.ArmorLabel._y, 96 + fresh.KIND_LINE);
      said("the type over the name stays", fresh.menu.itemCard.ItemType._y, 10);
      said("the kind line stands under the letters", fresh.menu.itemCard.equipmentKind._y, 60);
      fresh.layKind();
      said("laid out again it doesn't move twice", fresh.menu.itemCard.ArmorValue._y, 52 + fresh.KIND_LINE);
      fresh.menu.itemCard = kindCard(62);
      fresh.kindMoved = undefined;
      fresh.layKind();
      said("SkyUI's numbers under the name move down too", fresh.menu.itemCard.ArmorValue._y, 62 + fresh.KIND_LINE);
      said("under a name in the middle the line stands in the middle", fresh.menu.itemCard.equipmentKind.format.align, "center");
      // Edge UI writes the name from the left, the kind line under it centred stood apart from it
      fresh.menu.itemCard = kindCard(62);
      fresh.menu.itemCard.nameAlign = "left";
      fresh.kindMoved = undefined;
      fresh.layKind();
      said("under a name from the left the line starts on the left", fresh.menu.itemCard.equipmentKind.format.align, "left");

      // a field with no words takes no room: Edge UI keeps the empty fields of Survival Mode in sight
      const card = kindCard(62);
      card.Exposure = {_name: "Exposure", _parent: card, _visible: true, _alpha: 100, _x: 0, _y: 140, _width: 60, _height: 30, text: ""};
      card.Rain = {_name: "Rain", _parent: card, _visible: true, _alpha: 100, _x: 0, _y: 140, _width: 60, _height: 30, text: " \r"};
      card.Warmth = {_name: "Warmth", _parent: card, _visible: true, _alpha: 100, _x: 0, _y: 140, _width: 60, _height: 30, text: "12"};
      fresh.menu.itemCard = card;
      const shown = fresh.shownParts().map((part) => part._name);
      said("an empty field is no part shown", shown.includes("Exposure") || shown.includes("Rain"), false);
      said("a field with words is", shown.includes("Warmth"), true);
      said("a clip with nothing drawn is empty", fresh.emptyPart({getBounds: () => ({xMin: 6710886.4, xMax: -6710886.4, yMin: 6710886.4, yMax: -6710886.4})}), true);
      said("a drawn clip isn't", fresh.emptyPart({getBounds: () => ({xMin: 0, xMax: 10, yMin: 0, yMax: 4})}), false);
   }

   // The words of the window at the player's sizes: a field grows from the size the card gave it, what lies
   // under it moves down by what it grew, and every layout starts again from the card as the menu left it
   {
      const context = freshPanel.context;
      context.TextField = function() {};
      context.TextFormat = function() {};
      const field = (name, parent, y, high, size, options) => {
         const made = Object.assign(new context.TextField(), {_name: name, _parent: parent, _visible: true, _alpha: 100, _x: 0, _y: y, _width: 300, _height: high,
            _xscale: 100, _yscale: 100, text: "words", wordWrap: true, size: size, lines: 2, chars: 10, sets: 0}, options || {});
         Object.defineProperty(made, "textHeight", {get: () => made.lines * made.size * 1.2});
         Object.defineProperty(made, "textWidth", {get: () => made.chars * made.size * 0.5});
         made.getTextFormat = () => ({size: made.size});
         made.getNewTextFormat = () => ({size: made.size});
         made.setTextFormat = (format) => {
            if (format.size !== undefined && format.size !== null) {
               made.size = format.size;
            }
            made.sets++;
         };
         return made;
      };
      const textCard = (nameChars) => {
         const card = {_visible: true, _alpha: 100, localToGlobal: () => undefined, globalToLocal: () => undefined};
         card.ItemText = {_name: "ItemText", _parent: card, _visible: true, _alpha: 100, _y: 0, _yscale: 100, getBounds: () => ({xMin: 0, xMax: 300, yMin: 0, yMax: 40}),
            localToGlobal: () => undefined};
         card.ItemText.ItemTextField = field("ItemTextField", card.ItemText, 0, 30, 20, {wordWrap: false, lines: 1, chars: nameChars});
         card.PotionsLabel = field("PotionsLabel", card, 60, 60, 15);
         card.WeightLabel = field("WeightLabel", card, 140, 22, 14, {wordWrap: false, lines: 1, text: "WEIGHT"});
         return card;
      };
      fresh.settings = undefined;
      said("with no settings the words keep their size", fresh.textShare("words"), 1);
      fresh.settings = {nameText: 0, wordsText: 400};
      said("a size out of reach is the own size", fresh.textShare("name") + fresh.textShare("words"), 2);
      fresh.menu.itemCard = textCard(12);
      fresh.settings = {nameText: 100, wordsText: 100, numbersText: 100, quietText: 100};
      fresh.unsizeCardText();
      fresh.sizeCardText(true);
      said("at their own size the card's fields aren't touched", fresh.menu.itemCard.PotionsLabel.sets + fresh.menu.itemCard.ItemText.ItemTextField.sets, 0);
      said("and nothing moves", fresh.menu.itemCard.WeightLabel._y, 140);
      fresh.settings.wordsText = 150;
      fresh.unsizeCardText();
      fresh.sizeCardText(true);
      said("the effects of a potion grow by half", fresh.menu.itemCard.PotionsLabel.size, 23);
      said("what lies under them moves down by what they grew", fresh.menu.itemCard.WeightLabel._y, 140 + 2 * (23 - 15) * 1.2);
      said("the name stays", fresh.menu.itemCard.ItemText.ItemTextField.size, 20);
      fresh.unsizeCardText();
      fresh.sizeCardText(true);
      said("laid out again they grow once", fresh.menu.itemCard.PotionsLabel.size, 23);
      said("and what lies under them moves once", fresh.menu.itemCard.WeightLabel._y, 140 + 2 * (23 - 15) * 1.2);
      // the card fills the field anew at the size SkyUI gives it, that's the size to grow from
      fresh.menu.itemCard.PotionsLabel.size = 15;
      fresh.unsizeCardText();
      fresh.sizeCardText(true);
      said("a field the card filled anew grows from the card's size", fresh.menu.itemCard.PotionsLabel.size, 23);
      fresh.settings.wordsText = 100;
      fresh.unsizeCardText();
      fresh.sizeCardText(true);
      said("back at 100 the field gets the card's size again", fresh.menu.itemCard.PotionsLabel.size, 15);
      said("and what lies under it goes back", fresh.menu.itemCard.WeightLabel._y, 140);
      // a name too long for its line comes out as big as still fits
      fresh.menu.itemCard = textCard(20);
      fresh.settings.nameText = 200;
      fresh.unsizeCardText();
      fresh.sizeCardText(true);
      said("a long name grows as far as its line holds it", fresh.menu.itemCard.ItemText.ItemTextField.size, 29);
      said("and the effects under it move down", fresh.menu.itemCard.PotionsLabel._y, 60 + (29 - 20) * 1.2);
      // the card's rule under the name lies inside the name's clip, below its letters, and goes down with the name
      fresh.menu.itemCard = textCard(12);
      const card = fresh.menu.itemCard;
      card.Rule = {_name: "Rule", _parent: card, _visible: true, _alpha: 100, _x: 0, _y: 32, _width: 300, _height: 2, getBounds: () => ({xMin: 0, xMax: 300, yMin: card.Rule._y, yMax: card.Rule._y + 2})};
      fresh.settings = {nameText: 200, wordsText: 100};
      fresh.unsizeCardText();
      fresh.sizeCardText(true);
      said("the name grows to twice", card.ItemText.ItemTextField.size, 40);
      said("the rule under its letters goes down with it", card.Rule._y, 32 + (40 - 20) * 1.2);
      fresh.settings = {numbersText: 150, quietText: 150};
      said("the numbers block at 150%", fresh.statsText(), 20);
      said("its lines with it", fresh.statsLine(), 27);

      // a spell's description longer than its box: SkyUI lets the box grow down to the words (origHeight is the box it
      // had) and leaves the cost where it stood. The cost moves down past the words and a line of air under them
      const spellCard = (lines, high, box) => {
         const made = textCard(12);
         delete made.PotionsLabel;
         made.MagicEffectsLabel = field("MagicEffectsLabel", made, 60, high, 20, {lines: lines, numLines: lines, origHeight: box});
         made.MagicCostLabel = field("MagicCostLabel", made, 130, 22, 14, {wordWrap: false, lines: 1, text: "COST"});
         return made;
      };
      const line = 20 * 1.2;
      fresh.settings = {nameText: 100, wordsText: 100};
      fresh.menu.itemCard = spellCard(3, 79, 59);
      fresh.unsizeCardText();
      fresh.sizeCardText(true);
      said("the box SkyUI grew keeps its height", fresh.menu.itemCard.MagicEffectsLabel._height, 79);
      said("the cost under it moves past the words and a line of air", fresh.menu.itemCard.MagicCostLabel._y, 130 + 3 * line + 4 + line - 59);
      fresh.unsizeCardText();
      fresh.sizeCardText(true);
      said("laid out again it moves once", fresh.menu.itemCard.MagicCostLabel._y, 130 + 3 * line + 4 + line - 59);
      fresh.unsizeCardText();
      said("the next layout starts from the card's place", fresh.menu.itemCard.MagicCostLabel._y, 130);
      fresh.menu.itemCard = spellCard(2, 59, 59);
      fresh.unsizeCardText();
      fresh.sizeCardText(true);
      said("two lines that fill the box get their line of air too", fresh.menu.itemCard.MagicCostLabel._y, 130 + 2 * line + 4 + line - 59);
      said("and the box stays as it is", fresh.menu.itemCard.MagicEffectsLabel._height, 59);
      fresh.menu.itemCard = spellCard(1, 59, 59);
      fresh.unsizeCardText();
      fresh.sizeCardText(true);
      said("one line has its air in the box and moves nothing", fresh.menu.itemCard.MagicCostLabel._y, 130);
      fresh.menu.itemCard = spellCard(3, 59);
      fresh.unsizeCardText();
      fresh.sizeCardText(true);
      said("words past a box SkyUI never fitted grow it", fresh.menu.itemCard.MagicEffectsLabel._height, 3 * line + 4);
      said("and the cost moves by as much, no air added", fresh.menu.itemCard.MagicCostLabel._y, 130 + 3 * line + 4 - 59);
      fresh.unsizeCardText();
      said("the box gets the card's height back", fresh.menu.itemCard.MagicEffectsLabel._height, 59);
      // bigger words on a grown box: the box's move and the words' growth add up once each
      fresh.menu.itemCard = spellCard(3, 79, 59);
      fresh.settings.wordsText = 150;
      fresh.unsizeCardText();
      fresh.sizeCardText(true);
      said("bigger words move the cost by both", fresh.menu.itemCard.MagicCostLabel._y, 130 + 3 * line + 4 + line - 59 + 3 * (30 - 20) * 1.2);
      fresh.settings.wordsText = 100;
      fresh.unsizeCardText();
      fresh.sizeCardText(true);
      said("back at 100 only the box's move stays", fresh.menu.itemCard.MagicCostLabel._y, 130 + 3 * line + 4 + line - 59);
      said("and the box SkyUI's height", fresh.menu.itemCard.MagicEffectsLabel._height, 79);
      fresh.unsizeCardText();
      fresh.sizeCardText();
      said("a chest's card is left as moreHUD lays it out", fresh.menu.itemCard.MagicCostLabel._y, 130);
   }
}

// Subcategories in a narrow list go a group a line instead of shrinking: Edge UI made them tiny in one line
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel();
   said("a strip that fits keeps its size", Equipment.fitScale(400, 600), 100);
   said("a wider one shrinks to the room", Equipment.fitScale(800, 600), 75);
   said("nothing drawn is no shrink", Equipment.fitScale(0, 600), 100);
   const made = [];
   Equipment.chips = {createEmptyMovieClip: () => ({}), lineStyle: () => undefined, moveTo: () => undefined, lineTo: () => undefined};
   Equipment.chosenNow = () => [];
   Equipment.translated = (chip) => chip.key;
   Equipment.makeChip = (name, words, icon, x) => {
      const chip = {_x: x, _y: 0, wide: 50};
      made.push(chip);
      return chip;
   };
   const rows = [[{key: "light"}, {key: "heavy"}], [{key: "head"}, {key: "body"}, {key: "feet"}]];
   said("one line holds both groups", Equipment.layChips(rows, 0, false, false), 1);
   said("the second group follows the first", made[2]._x > made[1]._x && made[2]._y == 0, true);
   made.length = 0;
   said("a group a line takes two", Equipment.layChips(rows, 0, false, true), 2);
   said("the second group starts under the first", made[2]._x == 0 && made[2]._y == Equipment.STRIP_HIGH, true);
   made.length = 0;
   said("a group with nothing to show takes no line", Equipment.layChips([[], [{key: "head"}]], 0, false, true), 1);
}

// Menus made on SkyUI 5 have a stage 2560x720 the game stretches over the screen, the panel squeezes its own drawing
// back. The window over a row keeps the list's proportions, beside a slot it's square
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const squashOf = (stage, screen) => {
      const Equipment = freshPanel(false, undefined, {visibleRect: stage, safeRect: {x: 20, y: 10}});
      Equipment.plugin = () => (screen ? {ScreenSize: () => screen} : undefined);
      Equipment.readSquash();
      return Equipment;
   };
   expect("Dear Diary on 16:9 shows a unit across half as wide", squashOf({x: 0, y: 0, width: 2560, height: 720}, {width: 1920, height: 1080}).squash, 0.5);
   expect("and on 16:10 less than half", squashOf({x: 0, y: 0, width: 2560, height: 720}, {width: 1920, height: 1200}).squash, 0.45);
   expect("SkyUI 6 on 16:10 keeps its proportions", squashOf({x: 0, y: -40, width: 1280, height: 800}, {width: 1920, height: 1200}).squash, 1);
   expect("a pixel of rounding is no stretch", squashOf({x: 0, y: 0, width: 1280, height: 720}, {width: 1366, height: 768}).squash, 1);
   expect("without the plugin nothing changes", squashOf({x: 0, y: 0, width: 2560, height: 720}, undefined).squash, 1);

   const Equipment = squashOf({x: 0, y: 0, width: 2560, height: 720}, {width: 1920, height: 1080});
   expect("the screen in the panel's units is as wide as SkyUI 6's", Equipment.screenRect().width, 1280);
   expect("the margin of the screen across too", Equipment.safeInset().x, 10);
   expect("a point of the stage into the panel's units", Equipment.toPanel({x: 600, y: 300}).x, 300);
   expect("and back", Equipment.toStage({x: 300, y: 300}).x, 600);
   said("a share is the same in both", Equipment.share(640, 360).x, Equipment.screenShare(1280, 360).x);

   const lists = Equipment.menu.inventoryLists;
   lists.getContentBounds = () => [-21, 0, 641, 720];
   lists._x = 16;
   lists.itemList = {getBounds: () => ({xMin: 35, xMax: 577})};
   expect("Dear Diary's page ends in the panel's units", Equipment.listEdge().right, 330.5);
   expect("its rows", Equipment.rowsEdge().right, 290.5);
   expect("as wide as its page less what hangs past them", Equipment.rowsEdge().wide, 280.5);

   const card = {_yscale: 63};
   Equipment.menu.itemCard = {_parent: card};
   Equipment.window = {wide: 269};
   Equipment.placeWindowLeft();
   expect("over a row the window stands where it stood on the stretched stage", Equipment.window.left, 146.5);
   Equipment.windowUnits(Equipment.squash);
   expect("in the list's proportions", Equipment.window._xscale, 50);
   expect("its card too", card._xscale, 63);
   expect("as wide in the panel's units as half its own", Equipment.windowWide(), 134.5);
   Equipment.windowUnits(1);
   expect("beside a slot it's square", Equipment.window._xscale, 100);
   expect("the card in it too", card._xscale, 126);
   expect("and as wide as its own units", Equipment.windowWide(), 269);
}

// The game equips the selected row on a press whenever the pointer is over it. A press a line of a menu, the lens or
// the dark sheet took must not equip the row under it, in either order of the game's call and the press
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   const box = freshPanel.context;
   let now = 10000;
   box.getTimer = () => now;
   Equipment.menu._platform = 0;
   Equipment.over = {_parent: undefined};
   Equipment.under = {_parent: undefined};
   const list = {};
   const row = {_parent: list, itemIndex: 0, _visible: true};
   const line = {_parent: {_parent: Equipment.over}};
   const sheet = {_parent: {_parent: Equipment.under}};
   box.Mouse.getTopMostEntity = () => row;
   said("a press on a row is the row's", Equipment.pressUsed(), false);
   box.Mouse.getTopMostEntity = () => line;
   said("the game's equip before the line had the press", Equipment.pressUsed(), true);
   box.Mouse.getTopMostEntity = () => sheet;
   said("the dark sheet under the panel is the panel's too", Equipment.pressUsed(), true);
   Equipment.menu._platform = 1;
   said("a pad equips whatever the pointer rests on", Equipment.pressUsed(), false);
   Equipment.menu._platform = 0;
   box.Mouse.getTopMostEntity = () => row;
   Equipment.usePress();
   now += 50;
   said("the game's equip after the line had the press and closed the menu", Equipment.pressUsed(), true);
   now += Equipment.PRESS_USED;
   said("a later press on a row equips again", Equipment.pressUsed(), false);
   box.Mouse.getTopMostEntity = () => undefined;
   said("nothing under the pointer", Equipment.pressUsed(), false);
}

// The lens sits under the right end of the selected row. A row the pointer crosses on its way there waits, the
// window stays with the row it was on, and the row is selected once the pointer turns away or stops on it
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   const box = freshPanel.context;
   let now = 10000;
   box.getTimer = () => now;
   const ray = (x, y, dx, dy) => Equipment.stepsToBox(x, y, dx, dy, {xMin: 100, yMin: 40, xMax: 120, yMax: 60});
   said("a step that ends short of the box", ray(0, 50, 50, 0), 2.4);
   said("a step inside the box", ray(0, 50, 110, 0), 120 / 110);
   said("a step past the box", ray(0, 50, 200, 0) < 1, true);
   said("a step away from it", ray(0, 50, -10, 0), -1);
   said("a step down beside it", ray(0, 0, 0, 10), -1);

   const list = {entryList: [{text: "a"}, {text: "b"}, {text: "c"}], selectedIndex: 0};
   list.selectedEntry = list.entryList[0];
   list.onItemRollOver = function(index) { this.selectedIndex = index; this.selectedEntry = this.entryList[index]; };
   Equipment.menu.inventoryLists.itemList = list;
   Equipment.menu._platform = 0;
   // rows 30 high from 0 down, the lens 22 square under the right end of row a
   const rows = list.entryList.map((entry, i) => ({_parent: list, itemIndex: i, _visible: true}));
   const lens = {_visible: true, getBounds: () => ({xMin: 400, yMin: 30, xMax: 422, yMax: 52})};
   lens.hitTest = (x, y) => x >= 400 && x <= 422 && y >= 30 && y <= 52;
   Equipment.lens = lens;
   box.Mouse.getTopMostEntity = () => lens.hitTest(box._root._xmouse, box._root._ymouse) ? lens : rows[Math.floor(box._root._ymouse / 30)];
   // a move of the pointer as the menu sees it: the mouse listener, then a row the pointer came onto rolls over
   const move = (x, y) => {
      box._root._xmouse = x;
      box._root._ymouse = y;
      const under = box.Mouse.getTopMostEntity();
      Equipment.followLensAim();
      if (under !== lens && under !== move.last) {
         move.last = under;
         list.onItemRollOver(under.itemIndex);
      }
   };
   const backOnRowA = () => {
      list.equipmentRollOver(0);
      Equipment.lensWait = undefined;
      Equipment.lensFrom = undefined;
      move.last = rows[0];
   };
   Equipment.aimForLens();
   move(100, 15);
   move(110, 15);
   move(250, 32);
   said("row b waits while the pointer heads for the lens", list.selectedIndex, 0);
   now += Equipment.LENS_AIM_MS - 50;
   move(330, 32);
   now += Equipment.LENS_AIM_MS - 50;
   Equipment.lensWaitFrame();
   said("a slow hand still on the way", list.selectedIndex, 0);
   move(405, 35);
   said("on the lens the window stays with row a", list.selectedIndex, 0);
   said("and row b gave up its turn", Equipment.lensWait, undefined);

   backOnRowA();
   move(370, 15);
   move(380, 15);
   move(390, 35);
   said("a step down toward the lens waits", list.selectedIndex, 0);
   move(200, 45);
   said("turning away from the lens selects the row under the pointer", list.selectedIndex, 1);

   backOnRowA();
   move(150, 15);
   move(160, 15);
   move(330, 33);
   said("waits again", list.selectedIndex, 0);
   now += Equipment.LENS_AIM_MS;
   Equipment.lensWaitFrame();
   said("a pointer that stops on the row it crossed selects it in a moment", list.selectedIndex, 1);

   backOnRowA();
   move(150, 15);
   move(160, 15);
   move(330, 33);
   Equipment.endLensWait();
   said("a press on the waiting row selects it first", list.selectedIndex, 1);

   backOnRowA();
   move(100, 15);
   move(100, 75);
   said("straight down far from the lens never waits", list.selectedIndex, 2);

   backOnRowA();
   lens._visible = false;
   move(100, 15);
   move(110, 15);
   move(250, 32);
   said("no lens, no wait", list.selectedIndex, 1);
}

// All parts share one Equipment object, a function a later part names again replaces the earlier one. The strip
// of pieces once took the name of the strip of subcategories and the menu hung. Only the stubs that a later
// part fills in on purpose may share a name
{
   const stubs = ["listReady", "started", "categoryShown"];
   const seen = {};
   for (const part of fs.readdirSync(source).filter((name) => name.endsWith(".as"))) {
      for (const match of fs.readFileSync(path.join(source, part), "utf8").matchAll(/^Equipment\.(\w+) = function/gm)) {
         (seen[match[1]] = seen[match[1]] || []).push(part);
      }
   }
   for (const [name, parts] of Object.entries(seen)) {
      if (parts.length > 1 && !stubs.includes(name)) {
         failed++;
         console.log(`FAIL Equipment.${name} is defined in ${parts.join(" and ")}`);
      } else {
         passed++;
      }
   }
}

// a request for an update while one waits starts no second timer, SkyUI's own would leave the first behind
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   let timers = 0;
   const list = {
      requestUpdate() { this._bRequestUpdate = true; if (this._invalidateRequestID) { return; } this._updateRequestID = ++timers; },
      commitUpdate() { delete this._updateRequestID; this._bRequestUpdate = false; },
   };
   Equipment.guardUpdates(list);
   list.requestUpdate();
   list.requestUpdate();
   list.requestUpdate();
   said("three requests before the update, one timer", timers, 1);
   list.commitUpdate();
   list.requestUpdate();
   said("a request after the update starts a new one", timers, 2);
   list.commitUpdate();
   list._invalidateRequestID = 7;
   list.requestUpdate();
   said("a waiting invalidate takes the update along", timers, 2);
   said("and the update is still wanted", list._bRequestUpdate, true);
   Equipment.guardUpdates(list);
   delete list._invalidateRequestID;
   list.requestUpdate();
   list.requestUpdate();
   said("guarded twice, still one timer a request", timers, 3);
}

// the card's frame grows by its plain strip only: the top stays, the bottom edge moves down under the numbers
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const art = { yMin: 0, yMax: 208 };
   let pieces = Equipment.framePieces(art, 170, 290, 30, 4);
   said("the last 30 units are the bottom edge", pieces.bottomFrom, 178);
   said("the frame ends where it's asked to", pieces.shift, 82);
   said("the slice is taken right under the cut", pieces.sliceTop, 170);
   said("the slice is thin", pieces.sliceHigh, 4);
   said("the fill reaches the moved edge", pieces.fillHigh, 90);
   pieces = Equipment.framePieces(art, 100, 150, 30, 4);
   said("numbers that fit move nothing", pieces.shift, 0);
   pieces = Equipment.framePieces(art, 190, 260, 30, 4);
   said("a frame with no room under the cut keeps what it has as its edge", pieces.bottomFrom, 190);
   said("and takes its slice from above the cut", pieces.sliceTop, 186);
   said("a chest's frame never rises", pieces.rise, 0);

   // the item window's frame: the top edge goes up over the model, the bottom one down under the numbers
   const sky = { yMin: 0, yMax: 153 };
   pieces = Equipment.windowPieces(sky, -100, 300, 30, 4);
   said("the top edge rises to the window's top", pieces.rise, 100);
   said("the window's frame is cut under its top edge", pieces.cut, 30);
   said("the bottom edge goes to the window's bottom", pieces.shift, 147);
   said("the fill runs between the two edges", pieces.cut - pieces.rise + pieces.fillHigh, pieces.bottomFrom + pieces.shift);
   pieces = Equipment.windowPieces(sky, 20, 120, 30, 4);
   said("a window shorter than the frame pulls the bottom edge up", pieces.shift, -33);
   said("and still fills between", pieces.cut - pieces.rise + pieces.fillHigh, pieces.bottomFrom + pieces.shift);
   pieces = Equipment.windowPieces({ yMin: 0, yMax: 60 }, 0, 200, 30, 4);
   said("a short frame keeps a third as each edge", pieces.cut, 20);
   const box = { numbersTop: 100, rowHigh: 30, names: { _visible: true, textHeight: 120 }, quiet: { _visible: false } };
   said("all lines show when they fit", Equipment.shownLines(box, 200, 300), 200);
   said("whole lines show when they don't", Equipment.shownLines(box, 200, 195), 90);
   said("one line at the least", Equipment.shownLines(box, 200, 110), 30);
   // two rows of numbers, two small lines of 25 under them from 70: You have 3 was cut through its middle on Dragonborn UI
   const quiet = { numbersTop: 100, rowHigh: 30, names: { _visible: true, textHeight: 60 }, quiet: { _visible: true, _y: 70, textHeight: 50, bottomScroll: 2 } };
   said("the cut lands under a small line, not in its middle", Equipment.shownLines(quiet, 130, 200), 95);
   said("with room for the rows only the small lines go", Equipment.shownLines(quiet, 130, 185), 60);
}

// while the card asks how many the rows stay still and the box under the card keeps off its Yes and No
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const itemList = {};
   const categoryList = {};
   let later = 0;
   Equipment.menu = { inventoryLists: { itemList, categoryList } };
   Equipment.cardNumbers = { _visible: true };
   Equipment.cardNumbersLater = () => later++;
   Equipment.cardAsks({ opening: true, menu: "quantity" });
   said("the rows hold while the card asks", itemList.disableSelection && itemList.disableInput && categoryList.disableSelection && categoryList.disableInput, true);
   said("the box under the card goes", Equipment.cardNumbers._visible, false);
   Equipment.cardAsks({ opening: false, canceled: true, menu: "quantity" });
   said("the rows answer again", itemList.disableSelection || itemList.disableInput || categoryList.disableSelection || categoryList.disableInput, false);
   said("the box is measured again", later, 1);
}

// the look sheet lies over a still list, a letting go of the inspect view keeps it still while the sheet is up
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const itemList = {};
   const categoryList = {};
   Equipment.menu = { inventoryLists: { itemList, categoryList } };
   Equipment.look = { _visible: true };
   Equipment.holdRows(true);
   said("the rows hold under the sheet", itemList.disableInput && categoryList.disableSelection, true);
   Equipment.inspecting = false;
   Equipment.holdRows(false);
   said("an inspect view that ends keeps them held under the sheet", itemList.disableSelection && itemList.disableInput, true);
   Equipment.look._visible = false;
   Equipment.holdRows(false);
   said("with the sheet gone they answer", itemList.disableSelection || itemList.disableInput || categoryList.disableInput, false);
}

// the item window takes half the list, never less than four tenths of the screen's height, the size the player
// chose on top, and never more than eight tenths of the list
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   said("a wide list gives its share", Equipment.windowWideFor(800, 720, 100, 1), 384);
   said("a narrow list keeps a share of the screen", Equipment.windowWideFor(500, 720, 100, 1), 288);
   said("a bigger window by the player's size", Equipment.windowWideFor(800, 720, 130, 1), 499);
   said("never over the names of the rows", Equipment.windowWideFor(500, 720, 160, 1), 400);
   said("in the skin's units of a stretched menu", Equipment.windowWideFor(800, 720, 100, 1.5), 256);
}

// the item window comes up over a row at once, once the row has stayed selected a moment, or never
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   const box = freshPanel.context;
   let now = 10000;
   let shown = 0;
   box.getTimer = () => now;
   Equipment.menu = { inventoryLists: { itemList: { selectedIndex: 3 } } };
   Equipment.showWindow = () => shown++;
   Equipment.settings = {windowShow: 0};
   Equipment.wantWindow(true);
   said("on hover it comes at once", Equipment.windowWanted, true);
   Equipment.settings.windowShow = 1;
   Equipment.wantWindow(true);
   said("after a pause it waits", Equipment.windowWanted, false);
   now += 200;
   Equipment.windowRestFrame();
   said("not yet a moment later", Equipment.windowWanted, false);
   now += 250;
   Equipment.windowRestFrame();
   said("it comes once the row stayed", Equipment.windowWanted, true);
   said("and is shown then", shown, 1);
   Equipment.wantWindow(true);
   Equipment.menu.inventoryLists.itemList.selectedIndex = -1;
   now += 500;
   Equipment.windowRestFrame();
   said("a row let go before the pause brings nothing", Equipment.windowWanted, false);
   Equipment.settings.windowShow = Equipment.WINDOW_OWN_CARD;
   Equipment.openedPopUp = Equipment.WINDOW_OWN_CARD;
   Equipment.ownCard = true;
   Equipment.menu.inventoryLists.itemList.selectedIndex = 3;
   Equipment.wantWindow(true);
   now += 1000;
   Equipment.windowRestFrame();
   said("the UI's own card brings no window after a pause either", Equipment.windowWanted, false);
}

// all junk at once asks first with the whole list, yes moves it, no leaves it
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   const box = freshPanel.context;
   box.gfx.io = {GameDelegate: {call: () => {}}};
   box.gfx.ui = {NavigationCode: {ENTER: "enter", ESCAPE: "escape", TAB: "tab", UP: "up", DOWN: "down"}};
   box.Shared = {GlobalFunc: {IsKeyPressed: () => true}};
   box.skse.Log = () => {};
   const rows = [{text: "Bone", count: 3, infoValue: 2, infoWeight: 0.5, equipmentJunk: true}, {text: "Rag", count: 1, value: 1, infoWeight: 0.1, equipmentJunk: true}];
   let queued;
   Equipment.junkVerb = () => "sell";
   Equipment.junkRows = () => rows;
   Equipment.listsAnswer = () => true;
   Equipment.holdRows = () => {};
   Equipment.closeContext = () => {};
   Equipment.closePopup = () => {};
   Equipment.drawJunkAsk = () => {};
   Equipment.startQueue = (moving) => (queued = moving);
   Equipment.junkAsk = {_visible: false};
   said("a shop pays for every copy", Equipment.junkWorth("sell", rows[0]), 6);
   said("a row with no shop price takes its value", Equipment.junkWorth("sell", rows[1]), 1);
   said("a chest weighs every copy", Equipment.junkWorthWords("store", Equipment.junkWorth("store", rows[0])), "1.5");
   Equipment.moveJunk();
   said("nothing moves before the answer", queued, undefined);
   said("the window is up", Equipment.junkAsk._visible, true);
   Equipment.answerJunk(false);
   said("no leaves the junk where it is", queued, undefined);
   said("and shuts the window", Equipment.junkAsk._visible, false);
   Equipment.moveJunk();
   said("a key the window has no use for is taken all the same", Equipment.junkAskKey({navEquivalent: "left"}), true);
   Equipment.junkAskKey({navEquivalent: "enter"});
   said("Enter moves the junk", queued === rows, true);
   said("a key with the window gone goes on to the list", Equipment.junkAskKey({navEquivalent: "enter"}), false);
   queued = undefined;
   Equipment.moveJunk();
   Equipment.junkAskKey({navEquivalent: "tab"});
   said("Tab calls it off and keeps the menu", queued, undefined);
   Equipment.askJunk("sell", []);
   said("no junk, no window", Equipment.junkAsk._visible, false);
}

// a window that waits or never comes holds the model of a selected row back until it's up
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   const box = freshPanel.context;
   const calls = [];
   box.gfx.io = {GameDelegate: {call: (name, args) => calls.push(name + " " + args.join(","))}};
   Equipment.menu = { inventoryLists: { itemList: { selectedIndex: 3 } } };
   Equipment.window = {_visible: false};
   Equipment.settings = {windowShow: 1};
   Equipment.holdModels();
   const delegate = box.gfx.io.GameDelegate;
   delegate.call("UpdateItem3D", [true]);
   said("a row selected with no window up asks for no model", calls.join(";"), "");
   delegate.call("PlaySound", ["UIMenuFocus"]);
   said("other calls go on", calls.join(";"), "PlaySound UIMenuFocus");
   Equipment.window._visible = true;
   Equipment.askModel();
   said("the window that comes up asks for it", calls.join(";"), "PlaySound UIMenuFocus;UpdateItem3D true");
   Equipment.askModel();
   said("once", calls.length, 2);
   delegate.call("UpdateItem3D", [true]);
   said("the same row again while its window is up goes on", calls.length, 3);
   Equipment.menu.inventoryLists.itemList.selectedIndex = 4;
   delegate.call("UpdateItem3D", [true]);
   said("the next row waits though the last window is still up", calls.length, 3);
   delegate.call("UpdateItem3D", [false]);
   said("letting a model go goes on", calls[3], "UpdateItem3D false");
   Equipment.anchorSlot = {};
   delegate.call("UpdateItem3D", [true]);
   said("a slot's window asks as before", calls.length, 5);
   Equipment.anchorSlot = undefined;
   Equipment.settings.windowShow = 0;
   Equipment.window._visible = false;
   Equipment.menu.inventoryLists.itemList.selectedIndex = 6;
   delegate.call("UpdateItem3D", [true]);
   said("a window at once asks as before", calls.length, 6);
   Equipment.ownCard = true;
   Equipment.settings.windowShow = Equipment.WINDOW_OWN_CARD;
   Equipment.menu.inventoryLists.itemList.selectedIndex = 7;
   delegate.call("UpdateItem3D", [true]);
   said("the UI's own card asks for the model of a row at once", calls.length, 7);
}

// A tooltip box of another movie on the menu's root (LoreBox) over the window's model: the model steps out while the
// box shows, comes back when it fades, and the panel's own holder never counts
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   const box = freshPanel.context;
   const shown = [];
   const clip = (props, bounds) => Object.assign(new box.MovieClip(), {_visible: true, _alpha: 100, getBounds: () => bounds}, props);
   const root = box._root;
   const holder = clip({_url: "Interface/lorebox_inject.swf", _parent: root}, {xMin: 6710886, yMin: 6710886, xMax: -6710886, yMax: -6710886});
   const tip = clip({_parent: holder, _alpha: 0}, {xMin: 0, yMin: 0, xMax: 0, yMax: 0});
   const back = clip({_parent: tip}, {xMin: 450, yMin: 150, xMax: 750, yMax: 300});
   tip.Background_mc = back;
   holder.ReqTooltips_mc = tip;
   root.LoreBox_0 = holder;
   root.equipmentPanel = clip({_url: "Interface/InventoryReforged/panel.swf", _parent: root}, {xMin: 0, yMin: 0, xMax: 1920, yMax: 1080});
   Equipment.menu = {_url: "Interface/InventoryMenu.swf"};
   Equipment.squash = 1;
   Equipment.window = {_visible: true, _x: 400, _y: 100, previewTop: 0, preview: 300};
   Equipment.windowWide = () => 400;
   Equipment.plugin = () => ({ShowPreview: (on) => shown.push(on)});
   Equipment.watchOverlays();
   said("a faded box hides nothing", shown.length, 0);
   tip._alpha = 100;
   Equipment.watchOverlays();
   said("a box over the model sends it out", shown.join(","), "false");
   Equipment.watchOverlays();
   said("once", shown.length, 1);
   back.getBounds = () => ({xMin: 450, yMin: 500, xMax: 750, yMax: 650});
   Equipment.watchOverlays();
   said("a box below the model brings it back", shown.join(","), "false,true");
   tip._visible = false;
   back.getBounds = () => ({xMin: 450, yMin: 150, xMax: 750, yMax: 300});
   Equipment.watchOverlays();
   said("a hidden box changes nothing", shown.length, 2);
   said("the panel's own clip never counts", Equipment.overlayOnModel(), false);
   tip._visible = true;
   back.getBounds = () => ({xMin: 0, yMin: 0, xMax: 0, yMax: 0});
   const words = Object.assign(new box.TextField(), {_parent: tip, _visible: true, _alpha: 100, text: "Owner: Belethor", _x: 460, _y: 160, _width: 280, _height: 60});
   tip.localToGlobal = () => {};
   tip.TooltipText_tf = words;
   said("words in a text field count", Equipment.overlayOnModel(), true);
   words.text = "";
   said("an empty text field doesn't", Equipment.overlayOnModel(), false);
   back.getBounds = () => ({xMin: 0, yMin: 0, xMax: 1280, yMax: 720});
   said("a box over the whole screen is no tooltip", Equipment.overlayOnModel(), false);
}

// The UI's own card switched on the look sheet halfway through a menu waits whole for the next opening: the window went
// at once while the card still sat in it, no card anywhere and the model in the game's spot over the list. On hover and
// after a pause swap at once
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   const told = [];
   Equipment.plugin = () => ({PreviewHome: () => told.push("home"), PlacePreview: () => told.push("place"), ShowPreview: (shown) => told.push("show " + shown)});
   Equipment.menu = {inventoryLists: {itemList: {selectedIndex: 2}}};
   Equipment.window = {_visible: false, sheet: {}, wide: 300};
   Equipment.windowWide = () => 300;
   Equipment.share = (x, y) => ({x: x, y: y});
   Equipment.openedPopUp = 0;
   Equipment.ownCard = false;
   Equipment.settings = {windowShow: 2};
   said("on to the own card, the card keeps the window's layout", Equipment.leavesCard(), false);
   said("pops up as it opened", Equipment.popUpNow(), 0);
   said("the sheet says it comes on reopening", Equipment.popUpLater(), true);
   Equipment.wantWindow(true);
   said("the window still comes", Equipment.windowWanted, true);
   Equipment.aimPreview();
   said("and takes the model in", told.join(";"), "place");
   told.length = 0;
   Equipment.settings.windowShow = 1;
   said("after a pause swaps at once", Equipment.popUpNow(), 1);
   said("and needs no reopening", Equipment.popUpLater(), false);
   Equipment.wantWindow(true);
   said("the window waits for the pause", Equipment.windowWanted, false);
   Equipment.openedPopUp = 2;
   Equipment.ownCard = true;
   Equipment.settings.windowShow = 0;
   said("off the own card, the card stays home", Equipment.leavesCard(), true);
   said("the own card stays until reopening", Equipment.popUpNow(), 2);
   said("the sheet says so", Equipment.popUpLater(), true);
   Equipment.wantWindow(true);
   said("no window comes", Equipment.windowWanted, false);
   Equipment.aimPreview();
   said("the model goes home", told.join(";"), "home");
   said("and shows", Equipment.previewShown(), true);
   Equipment.browsing = true;
   said("the browser's room keeps the model out", Equipment.previewShown(), false);
}

// Details of a row: the menu of the row lay over other rows and the row under its Details line took the selection as
// the menu went, the window showed that row. While the window of Details stands the pointer passing over rows picks
// none, a click on another row picks it, a click beside the rows and the window takes it down, a pad holds nothing
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   const sword = {formId: 7, text: "Ghostblade"};
   const arrows = {formId: 9, text: "Falmer Arrow (7)"};
   let shown = 0;
   let rolled = [];
   const list = {selectedEntry: sword, selectedIndex: 2, isMouseDrivenNav: true, onItemRollOver: (index) => rolled.push(index)};
   Equipment.menu = {_platform: 0, inventoryLists: {itemList: list}};
   Equipment.window = {_visible: true, sheet: {}};
   Equipment.settings = {windowShow: 0};
   Equipment.openedPopUp = 0;
   Equipment.ownCard = false;
   Equipment.showWindow = () => shown++;
   Equipment.headsForLens = () => false;
   Equipment.aimForLens();
   Equipment.pinWindow(sword);
   said("the window of Details holds the rows", Equipment.pinHolds(), true);
   list.onItemRollOver(11);
   said("the pointer over the arrows picks nothing", rolled.length, 0);
   Equipment.menu._platform = 1;
   said("a pad holds nothing", Equipment.pinHolds(), false);
   Equipment.menu._platform = 0;
   list.selectedEntry = arrows;
   said("a list that lost the row holds nothing", Equipment.pinHolds(), false);
   list.onItemRollOver(11);
   said("the pointer picks again", rolled.join(","), "11");
   Equipment.wantWindow(true);
   said("and the window of Details is over", Equipment.pinnedRow, undefined);
   list.selectedEntry = sword;
   Equipment.pinWindow(sword);
   let under = {itemIndex: 11, formId: 9, text: "Falmer Arrow (7)"};
   Equipment.rowUnderMouse = () => under;
   Equipment.pressBesidePin();
   said("the press on the Details line is left alone", list.selectedIndex, 2);
   Equipment.pinnedAt -= 1000;
   Equipment.pressBesidePin();
   said("a press on another row picks it", list.selectedIndex, 11);
   list.selectedIndex = 2;
   under = {itemIndex: 2, formId: 7, text: "Ghostblade"};
   Equipment.pressBesidePin();
   said("a press on its own row keeps it", Equipment.pinnedRow != undefined && list.selectedIndex == 2, true);
   under = undefined;
   Equipment.window.hitTest = () => true;
   Equipment.lens = {_visible: false};
   Equipment.pressBesidePin();
   said("a press on the window keeps it", Equipment.pinnedRow != undefined, true);
   Equipment.window.hitTest = () => false;
   Equipment.pressBesidePin();
   said("a press beside takes it down and the rows answer again", Equipment.pinnedRow + " " + Equipment.pinHolds(), "undefined false");
}

// A long text of the card grows down in the window. At home its frame doesn't grow, a long description ran past it over
// the bottom bar, so there SkyUI shrinks it as it does without the panel
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   const room = [];
   freshPanel.context._global.Shared = {GlobalFunc: {ApplyTextOverflow: function(field) { room.push(field.maxHeightExpand); }}};
   Equipment.growLongText();
   const overflow = freshPanel.context._global.Shared.GlobalFunc.ApplyTextOverflow;
   const field = {origHeight: 60, _height: 60, maxHeightExpand: 5, getTextFormat: () => ({size: 18})};
   Equipment.leftCard = Equipment.ownCard = false;
   overflow(field);
   said("in the window it grows down", room[0], Equipment.WORDS_ALL);
   Equipment.ownCard = true;
   overflow(field);
   said("at home it keeps SkyUI's own room", room[1], 5);
   Equipment.ownCard = false;
   Equipment.leftCard = Equipment.leftOverDoll = true;
   overflow(field);
   said("in the character's room it grows with its frame", room[2], Equipment.WORDS_ALL);
   Equipment.leftCard = Equipment.leftOverDoll = false;
   Equipment.ownCard = true;
   Equipment.cardBorrowed = true;
   overflow(field);
   said("in the window of Details it grows again", room[3], Equipment.WORDS_ALL);
}

// A box grown to its words gets its height back only for the words it was measured with: Description Framework adds
// its description a frame later, the old height of the enchantment alone squeezed six lines into three
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   const words = {text: "Does Raw Magic damage", _height: 79, equipmentOverHigh: 61, equipmentOverText: "Does Raw Magic damage"};
   Equipment.textOverflowed = [words];
   Equipment.unsizeCardText();
   said("the same words get their box back", words._height, 61);
   words.equipmentOverHigh = 79;
   words.equipmentOverText = "Does Raw Magic damage";
   words.text = "Does Raw Magic damage and a translucent Ancient Nord Sword";
   words._height = 156;
   Equipment.textOverflowed = [words];
   Equipment.unsizeCardText();
   said("words a mod added since keep the box SkyUI gave them", words._height, 156);
}

// The numbers in columns of two, each name beside its value, a window too narrow keeps the list
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   const line = (key, name, value) => Object.assign([name, value, undefined], {key: key});
   const keys = (columns) => columns.map((column) => column.map((one) => one.key).join("+")).join(" | ");
   const sword = [line("swing", "Swing", "0.7 s"), line("dps", "DPS", "~18"), line("dpm", "DPM", "~1100"), line("reach", "Reach", "1.00"), line("stagger", "Stagger", "0.00"), line("crit", "Crit damage", "4")];
   said("a sword", keys(Equipment.statsColumns(sword)), "dps+dpm | swing+reach | stagger+crit");
   said("a bow has no reach", keys(Equipment.statsColumns(sword.filter((one) => one.key != "reach"))), "dps+dpm | swing | stagger+crit");
   const armor = [line("stops", "Stops", "4.1%"), line("set", "Whole set", "63%"), line("health", "Effective health", "541"), line("perWeight", "Armor per weight", "5.2")];
   said("armor", keys(Equipment.statsColumns(armor)), "stops+set | health+perWeight");
   const field = {set htmlText(words) { this.words = words; }, get htmlText() { return this.words; }, setTextFormat(format) { this.format = format; },
      get textWidth() { return String(this.words).replace(/<[^>]*>/g, "").length * 7; }};
   Equipment.inkOf = () => 0xFFFFFF;
   Equipment.settings = {numbersText: 100};
   freshPanel.context.TextFormat = function(font, size) { this.font = font; this.size = size; };
   const window = {wide: 420, statGrid: field};
   said("three columns fit a window of 420", Equipment.layStatsColumns(window, Equipment.statsColumns(sword)), true);
   said("in two rows", window.statRows, 2);
   said("each column at its third, each value at one place in its column", field.format.tabStops.join(","), "25,132,171,264,345");
   said("the second row: DPM, its value, Reach and so on", field.htmlText.split("<br>")[1].replace(/<[^>]*>/g, "").split("\t").join("|"), "DPM|~1100|Reach|1.00|Crit damage|4");
   window.wide = 200;
   said("a narrow window keeps the list", Equipment.layStatsColumns(window, Equipment.statsColumns(sword)), false);
   // letters as wide as their size: changes in brackets fit only a size or two down
   const sized = {set htmlText(words) { this.words = words; }, get htmlText() { return this.words; }, setTextFormat(format) { this.format = format; },
      get textWidth() { const size = Math.max(...[...String(this.words).matchAll(/size='(\d+)'/g)].map((m) => Number(m[1])), 13); return String(this.words).replace(/<[^>]*>/g, "").length * size / 2; }};
   const grimsever = [line("swing", "Swing", "1.07 s"), line("dps", "DPS", "~21.9"), line("dpm", "DPM", "~1314"), line("reach", "Reach", "1.3"), line("stagger", "Stagger", "0.00"), line("crit", "Crit damage", "10")];
   grimsever.forEach((one) => one[2] = {text: "+0.37", role: "better"});
   const wide = {wide: 470, statGrid: sized};
   said("changes in brackets take a size down and keep the columns", Equipment.layStatsColumns(wide, Equipment.statsColumns(grimsever)) + " " + (Equipment.statsSize != Equipment.STATS_SIZES[0]), "true true");
   said("an item without them gets the first sizes again", Equipment.layStatsColumns(wide, Equipment.statsColumns(sword)) + " " + (Equipment.statsSize == Equipment.STATS_SIZES[0]), "true true");
}

// The UI's own card over the character (plain SkyUI) stays out of sight with its model, details only when asked
// for. A card that stands apart from the character's room keeps its place
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   const at = (x, y) => (point) => { point.x += x; point.y += y; };
   Equipment.stage = {touch: {_width: 500, _height: 900}, localToGlobal: at(700, 100)};
   const holder = {getBounds: () => ({xMin: 1000, xMax: 1500, yMin: 750, yMax: 950}), localToGlobal: at(1100, 900)};
   Equipment.menu.itemCard = {_parent: holder};
   said("plain SkyUI's card lies over the character", Equipment.cardOverDoll(), true);
   holder.getBounds = () => ({xMin: 100, xMax: 600, yMin: 750, yMax: 950});
   said("a card under the list stands apart", Equipment.cardOverDoll(), false);
   holder.getBounds = () => ({xMin: 0, xMax: 0, yMin: 0, yMax: 0});
   said("an empty card is told by its place", Equipment.cardOverDoll(), true);
   Equipment.window = {_visible: false};
   Equipment.ownCard = true;
   Equipment.ownCardOverDoll = true;
   said("its model waits for Details", Equipment.previewShown(), false);
   Equipment.ownCardOverDoll = false;
   said("a card apart keeps its model", Equipment.previewShown(), true);
}

// The UI's own card over the character never asks the game for a row's model, so nothing flashes where the character
// stands. The window of Details asks for it and lets it go when the card goes home
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   const calls = [];
   freshPanel.context.gfx.io = {GameDelegate: {call: (name, args) => calls.push(name + " " + args[0])}};
   Equipment.holdModels();
   const list = {selectedIndex: 4, selectedEntry: {formId: 7, text: "Ghostblade"}};
   Equipment.menu.inventoryLists.itemList = list;
   Equipment.window = {_visible: false, sheet: {}};
   Equipment.settings = {windowShow: 2};
   Equipment.openedPopUp = 2;
   Equipment.ownCard = true;
   Equipment.ownCardOverDoll = true;
   freshPanel.context.gfx.io.GameDelegate.call("UpdateItem3D", [true]);
   said("a row selected over the character asks for no model", calls.join(","), "");
   said("its model waits", Equipment.modelHeld, true);
   Equipment.cardBorrowed = true;
   Equipment.window._visible = true;
   Equipment.askModel();
   said("the window of Details asks for it", calls.join(","), "UpdateItem3D true");
   Equipment.cardBorrowed = false;
   Equipment.window._visible = false;
   Equipment.letModelGo();
   said("and the game drops it when the card goes home", calls.join(","), "UpdateItem3D true,UpdateItem3D false");
   said("the row's next window asks again", Equipment.modelHeld, true);
   Equipment.ownCardOverDoll = false;
   calls.length = 0;
   freshPanel.context.gfx.io.GameDelegate.call("UpdateItem3D", [true]);
   said("a card that stands apart shows its model at once", calls.join(","), "UpdateItem3D true");
}

// The game's TO STEAL line under SkyUI's card goes back home before a layout and takes its room under the frame
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   const line = {_y: 178.8, _visible: true, _alpha: 100, getBounds: () => ({xMin: 60, xMax: 360, yMin: line._y, yMax: line._y + 27.7})};
   const holder = {StealTextInstance: line};
   const card = {_parent: holder, _yscale: 100};
   const art = {xMin: 0, xMax: 420, yMin: 0, yMax: 153.35};
   said("the line is found", Equipment.stealLine(card), line);
   said("it reaches 53 under the frame", Math.round(Equipment.stealRoom(card, line, art)), 53);
   line._y = 400;
   Equipment.stealLine(card);
   said("a line moved by the last item goes home first", line._y, 178.8);
   line._visible = false;
   said("a line that's off is none", Equipment.stealLine(card), undefined);
   line._visible = true;
   line.getBounds = () => ({xMin: 500, xMax: 700, yMin: 178.8, yMax: 206.5});
   said("a line beside the card takes no room", Equipment.stealRoom(card, line, art), 0);
   said("a card with no line has nothing", Equipment.stealLine({_parent: {}}), undefined);
}

// The numbers of a card in a chest, a shop or the character's room in the window's columns, in the card's letters
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   const line = (key, name, value) => Object.assign([name, value, undefined], {key: key});
   const sword = [line("swing", "Swing", "0.7 s"), line("dps", "DPS", "~20.0"), line("dpm", "DPM", "~1200"), line("reach", "Reach", "1.00"), line("stagger", "Stagger", "0.00"), line("crit", "Crit damage", "5")];
   freshPanel.context.TextFormat = function() {};
   const field = {_width: 520, set htmlText(words) { this.words = words; }, get htmlText() { return this.words; }, setTextFormat(format) { this.format = format; },
      get textWidth() { return String(this.words).replace(/<[^>]*>/g, "").length * 9; }};
   const letters = {label: undefined, value: undefined, labelSize: 16, valueSize: 24};
   const rows = Equipment.cardGrid({names: field}, letters, Equipment.statsColumns(sword), 1);
   said("two rows", rows, 2);
   said("each column at its share of the card, each value at one place", field.format.tabStops.join(","), String([27 + Equipment.CHEST_GAP / 2, 169, 169 + 45 + Equipment.CHEST_GAP / 2, 339, 339 + 99 + Equipment.CHEST_GAP / 2]));
   said("the first row: DPS and its value, Swing, Stagger", field.htmlText.split("<br>")[0].replace(/<[^>]*>/g, "").split("\t").join("|"), "DPS|~20.0|SWING|0.7 s|STAGGER|0.00");
   field._width = 200;
   said("a card too narrow keeps the list", Equipment.cardGrid({names: field}, letters, Equipment.statsColumns(sword), 1), 0);
}

// The card left in the UI's place and a chest's card at the player's size of the card's text. At 150% WHOLE SET 19.8%
// (cap 80.0 was cut at the card's right edge and two of four numbers were lost under its bottom. A model of SkyUI's
// armor card with seven effects in the character's room (1280x720, the bar at 662, the room from 33 with a quarter of
// the screen kept for the model) and in a chest. Every line of the numbers stays inside the card at 150% and 200%, they
// come down in size only as far as they must, the words keep three lines at least, 100% stays as it was
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   // in the model a letter is this share of its size wide, bold ones wider, and a line is 1.2 of its size high
   const wideOf = (size, bold) => size * (bold ? 0.43 : 0.36);
   const parse = (html, base) => {
      const lines = [[]];
      const sizes = [base.size];
      let bold = false;
      for (const token of html.match(/<[^>]*>|[^<]+/g) || []) {
         const size = token.match(/^<font[^>]*size='(\d+)'/);
         if (token === "<br>") {
            lines.push([]);
         } else if (size) {
            sizes.push(Number(size[1]));
         } else if (token.startsWith("<font")) {
            sizes.push(sizes[sizes.length - 1]);
         } else if (token === "</font>") {
            sizes.pop();
         } else if (token === "<b>" || token === "</b>") {
            bold = token === "<b>";
         } else if (!token.startsWith("<")) {
            lines[lines.length - 1].push({text: token.split("&lt;").join("<").split("&gt;").join(">").split("&amp;").join("&"), size: sizes[sizes.length - 1], bold: bold || base.bold === true});
         }
      }
      return lines;
   };
   const textField = (context, parent, name) => {
      const made = new context.TextField();
      let html = "";
      let stops;
      let high = 10;
      let format = {font: "$EverywhereMediumFont", size: 12, color: 0xFFFFFF, bold: false, align: "left"};
      const given = (to) => Object.fromEntries(Object.entries(Object.assign({}, to)).filter(([, value]) => value !== undefined && value !== null));
      Object.assign(made, {_name: name, _parent: parent, _x: 0, _y: 0, _width: 10, _xscale: 100, _yscale: 100, _visible: true, _alpha: 100, scroll: 1, wordWrap: false, textAutoSize: "none"});
      // the field's width in its own units, _width counts in its parent's
      const inner = () => made._width * 100 / made._xscale;
      const laid = () => parse(html, format).map((runs) => {
         let x = 0;
         let size = 0;
         for (const run of runs) {
            for (const letter of run.text) {
               const stop = letter === "\t" ? (stops || []).find((one) => one > x) : undefined;
               x = letter === "\t" ? (stop !== undefined ? stop : x + 4 * run.size) : x + wideOf(run.size, run.bold);
            }
            size = Math.max(size, run.size);
         }
         return {wide: made.wordWrap ? Math.min(x, inner() - 4) : x, high: (size || format.size) * 1.2, count: made.wordWrap ? Math.max(1, Math.ceil(x / (inner() - 4))) : 1};
      });
      // Scaleform's shrink draws the words smaller till they fit the field's box, its height too
      const shrunk = () => {
         if (made.textAutoSize !== "shrink" || made.wordWrap || html === "") {
            return 1;
         }
         const lines = laid();
         return Math.min(1, (made._height * 100 / made._yscale - 4) / lines.reduce((sum, line) => sum + line.high, 0), (inner() - 4) / Math.max(...lines.map((line) => line.wide)));
      };
      const shownLines = () => Math.max(1, Math.floor((made._height - 4) / (made.textHeight / Math.max(1, made.numLines))));
      Object.defineProperties(made, {
         htmlText: {get: () => html, set: (words) => { html = String(words); stops = format.tabStops; }},
         text: {get: () => parse(html, format).map((runs) => runs.map((run) => run.text).join("")).join("\r"),
            set: (words) => { html = String(words).split("&").join("&amp;").split("<").join("&lt;").split(">").join("&gt;").split("\n").join("<br>"); stops = format.tabStops; }},
         textWidth: {get: () => html === "" ? 0 : Math.max(...laid().map((line) => line.wide)) * shrunk()},
         textHeight: {get: () => html === "" ? 0 : laid().reduce((sum, line) => sum + line.count * line.high, 0) * shrunk()},
         numLines: {get: () => html === "" ? 0 : laid().reduce((sum, line) => sum + line.count, 0)},
         _height: {get: () => made.autoSize === "left" ? made.textHeight + 4 : high, set: (to) => { high = to; }},
         length: {get: () => made.text.length},
         bottomScroll: {get: () => Math.min(made.numLines, made.scroll + shownLines() - 1)},
         maxscroll: {get: () => Math.max(1, made.numLines - shownLines() + 1)},
      });
      made.setNewTextFormat = (to) => { format = Object.assign({}, format, given(to)); };
      made.getNewTextFormat = () => Object.assign({}, format);
      made.getTextFormat = () => Object.assign({}, format);
      made.setTextFormat = (to) => {
         if (to.tabStops) {
            stops = to.tabStops;
         }
         if (typeof to.size === "number") {
            format.size = to.size;
         }
      };
      made.removeTextField = () => { delete parent[name]; };
      return made;
   };
   const clipOf = (context, parent, name) => {
      const made = Object.assign(new context.MovieClip(), {_name: name, _parent: parent, _x: 0, _y: 0, _visible: true, _alpha: 100, _xscale: 100, _yscale: 100,
         clear() {}, beginFill() {}, endFill() {}, moveTo() {}, lineTo() {}, curveTo() {}, lineStyle() {}, setMask() {}, swapDepths() {}, removeMovieClip() {},
         addEventListener() {}, getNextHighestDepth: () => 1, getBounds: () => ({xMin: 0, xMax: 0, yMin: 0, yMax: 0}), localToGlobal() {}, globalToLocal() {},
         duplicateMovieClip: () => undefined});
      made.createEmptyMovieClip = (named) => (made[named] = clipOf(context, made, named));
      made.createTextField = (named) => (made[named] = textField(context, made, named));
      return made;
   };
   const armor = [["Stops", "6.2% of a hit", "stops"], ["Whole set", "19.8% (cap 80.0%)", "set"], ["Effective health", "+7.8%", "health"], ["Armor per weight", "0.9", "perWeight"]]
      .map(([name, value, key]) => Object.assign([name, value, undefined], {key: key}));
   // a card at share percent of the card's text, in the character's room or in a chest (chest true), with other numbers
   // or quiet lines when given
   const layOut = (share, options) => {
      const Equipment = freshPanel(false);
      const context = freshPanel.context;
      const told = [];
      const chest = options !== undefined && options.chest === true;
      context.TextFormat = function(font, size, color, bold) { Object.assign(this, {font: font, size: size, color: color, bold: bold}); };
      context.skse.Log = (text) => told.push(text);
      const menu = {localToGlobal() {}, globalToLocal() {}};
      const holder = clipOf(context, menu, "holder");
      Object.assign(holder, chest ? {_x: 820, _y: 340} : {_x: 700, _y: 307});
      const card = clipOf(context, holder, "itemCard");
      const inCard = (box, viewer) => viewer === card ? box : {xMin: box.xMin + holder._x, xMax: box.xMax + holder._x, yMin: box.yMin + holder._y, yMax: box.yMax + holder._y};
      Object.assign(card, {_currentframe: 1, _currentlabel: "Apparel_reg"});
      card.localToGlobal = (point) => { point.x += holder._x; point.y += holder._y; };
      card.globalToLocal = (point) => { point.x -= holder._x; point.y -= holder._y; };
      const given = (key, otherwise) => options !== undefined && options[key] !== undefined ? options[key] : otherwise;
      context.flash = {geom: {Rectangle: function(x, y, wide, high) { Object.assign(this, {x: x, y: y, width: wide, height: high}); }}};
      // SkyUI's frame with its grid, 300 high. A skin's frame may have no grid (grid false), another height, or keep
      // nothing written on it (forgets, Norden UI's picture loaded into the frame)
      let natural = given("frameHigh", 300);
      const back = card.createEmptyMovieClip("background");
      back._width = 428;
      if (given("grid", true)) {
         back.scale9Grid = {};
      }
      // Norden UI loads its picture into the frame (picture true): the picture's clip stands on the loaded movie's
      // timeline at its lowest depth under no name the frame lists, and grows by a nine-slice grid of its own
      let art;
      const local = () => art !== undefined ? {xMin: 0, xMax: 428, yMin: art._y, yMax: art._y + natural * art._yscale / 100} : {xMin: 0, xMax: 428, yMin: 0, yMax: natural};
      const inBack = (box) => ({xMin: box.xMin, xMax: box.xMax, yMin: back._y + box.yMin * back._yscale / 100, yMax: back._y + box.yMax * back._yscale / 100});
      const loaded = () => {
         art = clipOf(context, back, "picture");
         art.getBounds = (viewer) => viewer === art ? {xMin: 0, xMax: 428, yMin: 0, yMax: natural} : viewer === back ? local() : inCard(inBack(local()), viewer);
         art.globalToLocal = (point) => { point.x -= holder._x; point.y = ((point.y - holder._y - back._y) * 100 / back._yscale - art._y) * 100 / art._yscale; };
         back.getInstanceAtDepth = (depth) => depth === -16384 ? art : undefined;
      };
      if (given("picture", false)) {
         loaded();
      }
      Object.defineProperty(back, "_height", {get: () => (local().yMax - local().yMin) * back._yscale / 100, set: (to) => { back._yscale = to / (local().yMax - local().yMin) * 100; }});
      if (given("forgets", false)) {
         Object.defineProperty(back, "equipmentGrid", {get: () => undefined, set: () => undefined});
      }
      back.getBounds = (viewer) => viewer === back ? local() : inCard(inBack(local()), viewer);
      back.globalToLocal = (point) => { point.x -= holder._x; point.y = (point.y - holder._y - back._y) * 100 / back._yscale; };
      // SkyUI's name shrinks to its box, Norden UI draws its field at 85% (nameScale 0.85)
      const scale = given("nameScale", 1);
      const named = card.createEmptyMovieClip("ItemText");
      Object.assign(named, {_x: 14, _y: 30});
      const name = textField(context, named, "ItemTextField");
      Object.assign(name, {_width: 400 * scale, _xscale: 100 * scale, _yscale: 100 * scale, textAutoSize: "shrink"});
      name._height = 40 * scale;
      name.setNewTextFormat({size: 30, align: "center"});
      name.text = given("nameWords", "IRON ARMOR");
      named.ItemTextField = name;
      named.getBounds = (viewer) => viewer === named ? {xMin: 0, xMax: name._width, yMin: 0, yMax: name._height} : inCard({xMin: named._x, xMax: named._x + name._width, yMin: named._y, yMax: named._y + name._height}, viewer);
      named.localToGlobal = (point) => { point.x += named._x + holder._x; point.y += named._y + holder._y; };
      const put = (fieldName, x, y, wide, high, words, letters, wraps) => {
         const made = textField(context, card, fieldName);
         Object.assign(made, {_x: x, _y: y, _width: wide, wordWrap: wraps === true});
         made._height = high;
         made.setNewTextFormat(letters);
         made.text = words;
         card[fieldName] = made;
         return made;
      };
      put("SkillTextInstance", 20, 6, 200, 24, "Heavy Armor", {size: 16}, true);
      put("ApparelArmorLabel", 20, 100, 60, 22, "ARMOR", {size: 16});
      put("ApparelArmorValue", 84, 92, 60, 36, "27", {size: 30, bold: true});
      put("ApparelWeightLabel", 160, 100, 70, 22, "WEIGHT", {size: 16});
      put("ApparelWeightValue", 232, 92, 60, 36, "30", {size: 30, bold: true});
      // seven effects, five lines at 100%
      const words = put("ApparelEnchantedLabel", 24, 130, 380, 124, "w".repeat(230), {size: 20, align: "center"}, true);
      Object.assign(Equipment.menu, {itemCard: card, _parent: undefined, bNPCMode: false, bottomBar: {_y: 662, _parent: {localToGlobal() {}}, getBounds: () => ({xMin: 0, xMax: 1280, yMin: 662, yMax: 720})}});
      Object.assign(Equipment.menu.inventoryLists, {itemList: {selectedEntry: {formId: 0x12E49, text: "Iron Armor"}}, addEventListener() {}});
      Equipment.under = Equipment.over = {localToGlobal() {}, globalToLocal() {}};
      Equipment.stage = {touch: {_width: 520, _height: 640}, localToGlobal: (point) => { point.x += 660; point.y += 33; }};
      Equipment.window = {};
      Equipment.settings = {stats: true, cardText: share};
      Equipment.statsOf = () => options !== undefined && options.lines !== undefined ? options.lines : armor;
      Equipment.quietLines = () => options !== undefined && options.quiet !== undefined ? options.quiet : [];
      Equipment.kind = chest ? "container" : "inventory";
      Equipment.leftCard = !chest;
      Equipment.leftOverDoll = !chest;
      Equipment.startCardNumbers();
      Equipment.showCardNumbers();
      const box = Equipment.cardNumbers;
      const frame = back.getBounds(card);
      return {Equipment, card, box, holder, words, frame, told, back, name, picture: () => art,
         // the picture loaded into the frame comes in place of its stand-in: what was written on the frame goes, its
         // scale stays
         load: (high) => {
            back.equipmentGrid = undefined;
            natural = high;
            loaded();
            back._url = "deardiary_dm/inventory/itemcard_4_BG.swf";
         },
         // the right edge of the widest line and how far down the numbers reach in sight, in the card's units
         right: box.names._x + 2 + box.names.textWidth,
         end: box.numbersTop + box.shown,
         // the top and the bottom of the card's frame on the stage
         top: holder._y + frame.yMin,
         bottom: holder._y + frame.yMax};
   };

   // at 100% the numbers stand in two columns at the card's own sizes, the words whole, the frame grown under them
   let laid = layOut(100);
   const pad = laid.Equipment.STATS_PAD;
   const below = laid.Equipment.CHEST_BELOW;
   const margin = laid.Equipment.CARD_NUMBERS_MARGIN;
   said("100%, the numbers in columns", laid.box.layout, "columns");
   said("at the card's own size", laid.box.share, 1);
   said("their names as the card's labels, their values a little smaller than its numbers", laid.Equipment.cardNumbers.names.htmlText.match(/size='(\d+)'/g).slice(0, 2).join(","), "size='16',size='21'");
   said("nothing fitted", laid.Equipment.cardFits, undefined);
   said("the words whole", laid.Equipment.wordsCut, undefined);
   said("the card stays at its place", laid.holder._y, 307);
   said("its frame grows under the numbers", Math.round(laid.frame.yMax * 10) / 10, 340.4);
   said("every line in sight", laid.box.scrollMost, 0);

   // the card at 150%. The numbers come down to 130%, in a list where each value has its whole width
   laid = layOut(150);
   said("150%, the numbers fitted", laid.Equipment.cardFits, 1);
   said("as large as still fits", laid.box.share, 1.3);
   said("in a list", laid.box.layout, "list");
   said("no name cut", laid.box.names.text.split("\r").map((line) => line.split("\t")[0]).join(","), "STOPS,WHOLE SET,EFFECTIVE HEALTH,ARMOR PER WEIGHT");
   said("the whole set's value whole", laid.box.names.text.split("\r")[1].split("\t")[1], "19.8% (cap 80.0%)");
   said("no line past the card's right edge", laid.right <= 428 - pad, true);
   said("all four lines in sight", laid.box.scrollMost + "," + Math.round(laid.box.shown * 10) / 10, "0," + Math.round(laid.box.names.textHeight * 10) / 10);
   said("inside the frame as it grew", laid.end + below <= laid.frame.yMax + 0.01, true);
   said("the words keep three lines and scroll", laid.Equipment.wordsCut.field == laid.words && laid.words.bottomScroll - laid.words.scroll + 1, 3);
   said("the card went up no further than the room lets it", laid.top >= 33 + 0.25 * 720 - 0.01, true);
   said("and stays over the bottom bar", laid.bottom <= 662 - margin + 0.01, true);
   said("the report finds nothing out of the card", laid.Equipment.cardPartsReport("150") || laid.told.join(" ").includes("PAST THE FRAME") || laid.told.join(" ").includes("OUT OF SIGHT"), false);
   said("and tells the size and the lines", /numbers at 130% in list.* line 2 "WHOLE SET \| 19\.8% \(cap 80\.0%\)" right \d+ bottom \d+/.test(laid.told[0]), true);

   // at 200% the words take three lines at twice their size, the numbers come down to 120% in columns
   laid = layOut(200);
   said("200%, as large as still fits", laid.box.share, 1.2);
   said("in columns", laid.box.layout, "columns");
   said("200%, no line past the card's right edge", laid.right <= 428 - pad, true);
   said("200%, every line in sight", laid.box.scrollMost, 0);
   said("200%, inside the frame", laid.end + below <= laid.frame.yMax + 0.01, true);
   said("200%, the words keep three lines", laid.words.bottomScroll - laid.words.scroll + 1, 3);
   said("200%, the card within the room", laid.top >= 33 + 0.25 * 720 - 0.01 && laid.bottom <= 662 - margin + 0.01, true);
   laid.Equipment.cardPartsReport("200");
   said("200%, the report finds nothing out of the card", laid.told.join(" ").includes("PAST THE FRAME") || laid.told.join(" ").includes("OUT OF SIGHT"), false);

   // three quiet lines under the numbers at 200% don't fit even at 100%, so the words give lines down to one
   laid = layOut(200, {quiet: ["Wanted by a quest", "You have 3", "From Dawnguard"]});
   said("the numbers at their least", laid.box.share, 1);
   said("the words give lines past their three", laid.words.bottomScroll - laid.words.scroll + 1, 1);
   said("and the quiet lines are in sight too", laid.box.scrollMost + "," + (laid.end + below <= laid.frame.yMax + 0.01), "0,true");

   // a chest's card goes up to the screen's top. At 200% the values left too little of the line for the names, the numbers
   // come down to 150% and the words keep five lines
   laid = layOut(200, {chest: true});
   said("a chest's card at 200%", laid.box.share + " " + laid.box.layout, "1.5 list");
   said("its lines inside the card", laid.right <= 428 - pad && laid.box.scrollMost == 0 && laid.end + below <= laid.frame.yMax + 0.01, true);
   said("its words keep what the numbers leave", laid.words.bottomScroll - laid.words.scroll + 1, 5);
   said("it stays on the screen over the bar", laid.top >= 0 && laid.bottom <= 662 - margin + 0.01, true);
   laid = layOut(150, {chest: true});
   said("at 150% it has the room for the whole size", laid.box.share + " " + laid.Equipment.cardFits + " " + laid.box.scrollMost, "1.5 undefined 0");
   // a card gone up just as far as it needs came back a hair short of that and lost its last row to the scroll
   laid = layOut(100, {chest: true});
   said("a chest's card risen just as far as it needs keeps its last row", laid.box.scrollMost + " " + (laid.holder._y < 340), "0 true");
   // a chest's armor against the worn one has its changes in brackets, too wide at 150% for the names to keep their share
   const better = (text) => ({text: text, role: "better"});
   const steel = [["Stops", "8.1% of a hit", "stops", better("+1.9%")], ["Whole set", "21.7% (cap 80.0%)", "set", better("+1.9%")], ["Effective health", "+9.9%", "health"],
      ["Armor per weight", "0.4", "perWeight", {text: "-0.5", role: "worse"}]].map(([name, value, key, change]) => Object.assign([name, value, change], {key: key}));
   laid = layOut(150, {chest: true, lines: steel});
   said("the changes in brackets take the numbers down for the width alone", laid.box.share + " " + laid.box.layout + " " + (laid.Equipment.wordsCut == undefined), "1.2 list true");
   said("every bracket inside the card, no name cut", (laid.right <= 428 - pad) + " " + laid.box.names.text.split("\r").map((line) => line.split("\t")[0]).join(","), "true STOPS,WHOLE SET,EFFECTIVE HEALTH,ARMOR PER WEIGHT");

   // the report marks a line the card lost
   laid = layOut(150);
   laid.box.shown = laid.box.rowHigh;
   laid.told.length = 0;
   laid.Equipment.cardPartsReport("cut");
   said("a line under the part in sight is told", laid.told[0].includes("line 2 \"WHOLE SET | 19.8% (cap 80.0%)\"") && laid.told[0].includes("OUT OF SIGHT"), true);

   // Norden UI draws the name's field at 85% and SkyUI shrinks the name to its box. At 150% the bigger size was drawn
   // small again, above the top of the card's box. The name comes out at its size with no shrink while it's grown, and
   // what lies under it moves down by what it really grew
   laid = layOut(100, {nameScale: 0.85});
   said("Norden at 100%, the name as the card has it", laid.name.getTextFormat().size + " " + laid.name.textAutoSize + " " + laid.name._height, "30 shrink 34");
   const armorAt = laid.card.ApparelArmorLabel._y;
   laid = layOut(150, {nameScale: 0.85});
   said("Norden at 150%, the name at its size", laid.name.getTextFormat().size + " " + laid.name.textAutoSize, "45 none");
   said("as big as it's set, nothing shrinks it", Math.round(laid.name.textWidth), Math.round(10 * wideOf(45)));
   said("its box takes the letters whole, at the field's 85%", Math.round(laid.name._height * 10) / 10, Math.round((45 * 1.2 + 4) * 0.85 * 10) / 10);
   said("the parts under it move by the kind line's growth and the name's, no more", Math.round((laid.card.ApparelArmorLabel._y - armorAt) * 10) / 10, Math.round(((24 - 16) * 1.2 + (45 - 30) * 1.2 * 0.85) * 10) / 10);
   laid.Equipment.unsizeCardText();
   said("with the card's size the name gets SkyUI's shrink and its box back", laid.name.getTextFormat().size + " " + laid.name.textAutoSize + " " + laid.name._height + " " + laid.card.ApparelArmorLabel._y, "30 shrink 34 " + armorAt);
   // a name too long for its line even at the card's size keeps SkyUI's way and moves nothing
   laid = layOut(150, {nameScale: 0.85, nameWords: "STEEL PLATE ARMOR OF THE NORTHERN WINDS AND THE FROST"});
   said("a name too long for its line keeps SkyUI's shrink", laid.name.getTextFormat().size + " " + laid.name.textAutoSize, "30 shrink");
   said("and moves nothing under it", Math.round((laid.card.ApparelArmorLabel._y - armorAt) * 10) / 10, Math.round((24 - 16) * 1.2 * 10) / 10);

   // Nordic UI's frame of enchanted armor draws itself, has no grid and ends at 209. Seven effects reach past it at 100%,
   // the frame was cut under them, past its bottom, and its slice and edge drew nothing under the numbers. The cut stays
   // above the edge and the slice, and the frame grows by a grid of the panel's at that slice under the card's words
   laid = layOut(100, {grid: false, frameHigh: 209});
   said("Nordic, the frame grows by a grid of the panel's", laid.Equipment.cardFrameWay.indexOf("a grid of the panel's by ") == 0, true);
   said("at a slice inside its picture, above its bottom edge", laid.back.scale9Grid.y + "+" + laid.back.scale9Grid.height, (209 - laid.Equipment.CHEST_KEEP - laid.Equipment.CHEST_SLICE) + "+" + laid.Equipment.CHEST_SLICE);
   said("down to the numbers", laid.end + below <= laid.frame.yMax + 0.01 && laid.box.scrollMost == 0, true);
   laid.Equipment.cardPartsReport("nordic");
   said("the report finds every line on the frame", laid.told[0].includes("PAST THE FRAME") || laid.told[0].includes("OUT OF SIGHT"), false);
   laid.Equipment.cardFrameAsSkyUI(laid.back);
   said("the frame gets its own size back and no grid", laid.back._height + " " + laid.back.scale9Grid, "209 null");
   // words that end above the frame's edge leave a frame with no grid to the copies
   laid = layOut(100, {grid: false, frameHigh: 300});
   said("words above the edge take no grid of the panel's", laid.back.scale9Grid, undefined);

   // Norden UI's picture loaded into the frame keeps nothing written on it: stretched whole, it never got its size back
   // and grew again with every layout. The panel keeps what it was
   laid = layOut(150, {grid: false, forgets: true});
   said("Norden, the frame is stretched whole", laid.Equipment.cardFrameWay.indexOf("stretched whole by ") == 0, true);
   const stretched = laid.back._yscale;
   laid.Equipment.showCardNumbers();
   said("laid out again it's stretched as much, from its own size", Math.round(laid.back._yscale * 1000) / 1000, Math.round(stretched * 1000) / 1000);
   said("its top stays", laid.back.getBounds(laid.card).yMin, 0);
   laid.Equipment.cardFrameAsSkyUI(laid.back);
   said("and it gets its size back", laid.back._yscale + " " + laid.back._y, "100 0");
   laid = layOut(150, {grid: false, forgets: true});
   laid.card._currentframe = 2;
   laid.Equipment.cardFrameAsSkyUI(laid.back);
   said("a frame of another kind of card is left as it came", laid.back._yscale > 100, true);

   // Norden UI's picture is loaded into the frame, its clip found by its depth on the loaded movie's timeline. It grows
   // by a nine-slice grid at the slice, so the frame's top and the clear band over its box keep their place and size at
   // every size of the card's text. Every layout starts from the picture as the card drew it
   for (const size of [100, 150, 200]) {
      laid = layOut(size, {grid: false, picture: true});
      said(`Norden ${size}%, the picture grows by its own grid`, laid.Equipment.cardFrameWay.indexOf("the skin's picture by ") == 0 && laid.picture().scale9Grid != undefined, true);
      said(`Norden ${size}%, the frame's top stays where the card drew it`, Math.round(laid.back.getBounds(laid.card).yMin * 1000) / 1000, 0);
      said(`Norden ${size}%, the frame holds every number`, laid.end + below <= laid.frame.yMax + 0.01 && laid.box.scrollMost == 0, true);
      laid.Equipment.cardPartsReport("norden");
      said(`Norden ${size}%, the report tells the box's top unstretched and the name under it`, /box top 0 drawn at 0, its top part stretched x1, name top \d+ under the box top by \d+ \(drawn by 30\), kind top 6/.test(laid.told[0]), true);
   }
   laid = layOut(150, {grid: false, picture: true});
   const grownBy = laid.picture()._yscale;
   laid.Equipment.showCardNumbers();
   said("laid out again the picture grows from its own size, as much", Math.round(laid.picture()._yscale * 1000) / 1000, Math.round(grownBy * 1000) / 1000);
   laid.Equipment.cardFrameAsSkyUI(laid.back);
   said("and gets it back", laid.picture()._yscale + " " + laid.picture().scale9Grid, "100 null");
   laid = layOut(150, {grid: false, picture: true});
   laid.card._currentframe = 2;
   laid.Equipment.cardFrameAsSkyUI(laid.back);
   said("a picture kept from another kind of card is left alone", laid.picture()._yscale > 100 && laid.Equipment.skinArt == undefined, true);

   // The first layout came while Norden's frame still showed its stand-in, 255 high: words past it, the stand-in grew
   // by a grid of the panel's. The picture loaded into the frame wiped what was written on it and kept its scale, it
   // came in stretched 1.52 times and stayed so (box top 4 drawn at -50 at 100%). The next layout gives the frame its
   // scale back from the panel's own record and grows the picture by its slice
   for (const size of [100, 150, 200]) {
      laid = layOut(size, {grid: false, frameHigh: 255});
      said(`Norden ${size}%, the stand-in grows by a grid of the panel's`, laid.Equipment.cardFrameWay.indexOf("a grid of the panel's by ") == 0 && laid.back._yscale > 100, true);
      laid.load(300);
      laid.Equipment.showCardNumbers();
      said(`Norden ${size}%, with the picture in, the frame's scale comes back`, Math.round(laid.back._yscale * 1000) / 1000 + " " + laid.back._y + " " + laid.back.scale9Grid, "100 0 null");
      said(`Norden ${size}%, and the picture grows by its own grid`, laid.Equipment.cardFrameWay.indexOf("the skin's picture by ") == 0 && laid.picture().scale9Grid != undefined, true);
      said(`Norden ${size}%, every number inside the picture`, laid.box.numbersTop + laid.box.shown + below <= laid.back.getBounds(laid.card).yMax + 0.01 && laid.box.scrollMost == 0, true);
      laid.told.length = 0;
      laid.Equipment.cardPartsReport("norden loaded");
      said(`Norden ${size}%, the report tells the picture's top where the card drew it, unstretched`, /box top 0 drawn at 0, its top part stretched x1, name top/.test(laid.told[0]), true);
   }

   // the tree of the frame names the picture found by its depth on the loaded movie's timeline
   laid = layOut(100, {grid: false, frameHigh: 255});
   laid.load(300);
   laid.Equipment.showCardNumbers();
   laid.told.length = 0;
   laid.Equipment.cardFrameTree("tree");
   said("the tree starts at the frame", laid.told[0].indexOf("PANELTEST card frame tree tree: background depth ") == 0 && laid.told[0].includes(" from deardiary_dm/inventory/itemcard_4_BG.swf"), true);
   said("and finds the picture by its depth, with its grid", laid.told.some((line) => /background\.picture \(by depth\) depth \? clip at 0,0 scale 100\/[\d.]+ box 0,0 to 428,\d+ grid 1,\d+ 426x4 shown true/.test(line)), true);
   said("then the card's own parts", laid.told.some((line) => line.includes("card part ApparelEnchantedLabel depth ? field \"wwwwwwwwwwww\"")), true);
}

// The report counts the frame the copies really draw: each copy where its picture meets its mask, down from the top
// while they join. Nordic UI's copies were cut past the picture's bottom, their slice and edge drew nothing
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const piece = (top, low) => ({_visible: true, getBounds: () => ({xMin: 0, xMax: 428, yMin: top, yMax: low})});
   const card = {background: {_width: 428, getBounds: () => ({xMin: 0, xMax: 428, yMin: 0, yMax: 209})}};
   Object.assign(card, {equipmentFrameTop: piece(0, 209), equipmentFrameTopMask: piece(-1, 264), equipmentFrameFill: piece(-27000, -6000), equipmentFrameFillMask: piece(264, 341),
      equipmentFrameBottom: piece(132, 341), equipmentFrameBottomMask: piece(341, 342)});
   let frame = Equipment.cardFrameNow(card);
   said("copies cut past the picture draw the frame down to its own bottom", frame.yMax + " " + frame.copies, "209 top 0-209 fill none bottom none");
   Object.assign(card, {equipmentFrameTopMask: piece(-1, 175), equipmentFrameFill: piece(-500, 400), equipmentFrameFillMask: piece(175, 311), equipmentFrameBottom: piece(102, 341),
      equipmentFrameBottomMask: piece(311, 342)});
   frame = Equipment.cardFrameNow(card);
   said("copies that join draw it to the bottom copy's end", frame.yMax + " " + frame.copies, "341 top 0-175 fill 175-311 bottom 311-341");
   delete card.equipmentFrameTop;
   said("a frame with no copies counts as it's drawn", Equipment.cardFrameNow(card).yMax, 209);
}

// The card left in the UI's place: with the numbers in it and no window over the rows, the character off and the UI's own
// card say first, over the character it stands in the room as with the character off, Pops up goes quiet on the sheet
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   Equipment.settings = {leaveCard: true, windowShow: 0, doll: true};
   said("Pops up says nothing with the card left", Equipment.lookQuiet("windowShow"), true);
   Equipment.settings.windowShow = 2;
   said("but chooses the UI's own card, which wins", Equipment.lookQuiet("windowShow") + " " + Equipment.lookQuiet("leaveCard"), "false true");
   Equipment.leftCard = true;
   Equipment.leftOverDoll = true;
   said("over the character it stands in the room", Equipment.cardInRoom(), true);
   Equipment.leftOverDoll = false;
   said("a skin's card apart stays where it is", Equipment.cardInRoom(), false);
}

// The card left in the UI's place over the character: its model stands in the room above the card, never under it
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   const placed = [];
   Equipment.plugin = () => ({PlacePreview: (...args) => placed.push(args.map((one) => Math.round(one * 1000) / 1000).join(","))});
   Equipment.stage = {touch: {_width: 500, _height: 900}, localToGlobal: (point) => { point.x += 700; point.y += 100; }};
   Equipment.menu.itemCard = {background: {getBounds: () => ({xMin: 720, xMax: 1180, yMin: 500, yMax: 950})}};
   Equipment.leftCard = true;
   Equipment.leftOverDoll = true;
   said("placed", Equipment.placeRoomModel(), true);
   // the model at the game's own size at most, it never grows past it in the room
   said("in the middle of the room above the card", placed[0], [(950 / 1280), (100 + Equipment.WINDOW_PAD + (400 - 2 * Equipment.WINDOW_PAD) / 2) / 720, Equipment.GAME_MODEL_SHARE, (400 - 2 * Equipment.WINDOW_PAD) / 720, (500 - 2 * Equipment.WINDOW_PAD) / 720, 1].map((one) => Math.round(one * 1000) / 1000).join(","));
   Equipment.cardBorrowed = true;
   said("the window of Details takes the model itself", Equipment.placeRoomModel(), false);
   Equipment.cardBorrowed = false;
   Equipment.leftOverDoll = false;
   said("only in the character's room", Equipment.placeRoomModel(), false);
}

// A crafting station: the slots show what's worn, a piece tried on takes its slots over the worn one, a weapon tried on
// the right hand, a station whose rows hold nothing to wear gets no panel
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   said("a forge's rows hold gear", Equipment.craftingGear([{formType: Equipment.ARMOR}]), true);
   said("a cooking pot's don't", Equipment.craftingGear([{formType: 46}]), false);
   said("no rows yet", Equipment.craftingGear([]), undefined);
   const cuirass = {formId: 1, formType: Equipment.ARMOR, partMask: 4, text: "Steel Armor"};
   const helmet = {formId: 2, formType: Equipment.ARMOR, partMask: 1, text: "Steel Helmet"};
   const sword = {formId: 3, formType: Equipment.WEAPON, equipState: 3, text: "Steel Sword"};
   const tried = {formId: 4, formType: Equipment.ARMOR, partMask: 4, text: "Elven Armor", tried: true};
   const triedBlade = {formId: 5, formType: Equipment.WEAPON, equipState: 3, text: "Elven Sword", tried: true};
   const kept = Equipment.withoutTried([cuirass, helmet, sword, tried, triedBlade], [tried, triedBlade]);
   said("the tried cuirass and blade take the place of the worn ones", kept.map((one) => one.text).join(","), "Steel Helmet");
   Equipment.triedOn = [4];
   said("a tried piece is known by its form", Equipment.isTried({formId: 4}) + " " + Equipment.isTried({formId: 1}), "true false");
}

// for tests, a row found by some words of its name, whatever their case
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   const found = [];
   Equipment.scrollToEntry = (holds) => found.push(holds({text: "Elven Gilded Armor"}), holds({text: "Ebony Boots"}));
   Equipment.aimEntry = () => {};
   Equipment.aimRowWith("elven");
   said("elven finds Elven", found.join(","), "true,false");
}

// The UI's own card: no window over a row, the card stays the UI's, the model of a row goes back to the game's place
// and shows, a slot's window still takes the model in. Read once as the menu opens
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   const told = [];
   const card = {_visible: true};
   Equipment.plugin = () => ({PreviewHome: () => told.push("home"), PlacePreview: () => told.push("place"), ShowPreview: (shown) => told.push("show " + shown)});
   Equipment.menu = {itemCard: {_parent: card}, inventoryLists: {itemList: {selectedIndex: 2, selectedEntry: undefined, getClipByIndex: () => undefined}}};
   Equipment.window = {_visible: false, sheet: {}, wide: 300};
   Equipment.keepCard = () => {};
   Equipment.showLens = () => {};
   Equipment.askModel = () => {};
   Equipment.tellOthersOfCard = () => {};
   Equipment.windowWide = () => 300;
   Equipment.share = (x, y) => ({x: x, y: y});
   Equipment.context = {_visible: false};
   Equipment.settings = {windowShow: 2};
   Equipment.ownCard = Equipment.number(Equipment.settings.windowShow) == Equipment.WINDOW_OWN_CARD;
   said("the UI's own card leaves the card", Equipment.leavesCard(), true);
   Equipment.wantWindow(true);
   said("no window over a row", Equipment.windowWanted, false);
   Equipment.showWindow();
   said("the window stays down", Equipment.window._visible, false);
   said("the card is the UI's to show", card._visible, true);
   said("the model goes home and shows", told.join(";"), "home;show true");
   told.length = 0;
   Equipment.anchorSlot = {};
   Equipment.aimPreview();
   said("a slot's window takes the model in", told.join(";"), "place");
   Equipment.anchorSlot = undefined;
   Equipment.ownCard = false;
   Equipment.settings.windowShow = Equipment.WINDOW_AFTER_REST;
   said("a window after a pause leaves the card only by the ini switch", Equipment.leavesCard(), false);
}

// In a follower's trade the panel stands for the follower: their side of the list is what they wear, their outfit
// fills the slots the list leaves empty, what goes on or off goes through the plugin, a row of the player's side is
// given through the menu's own move first
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(true);
   const box = freshPanel.context;
   const worn = [];
   const moves = [];
   box.skse.plugins.EquipmentPanel = {
      Wear: (index, form, left, on) => (worn.push([index, form, left, on].join(",")), true),
      Outfit: () => [armor(4, 31, 1, {outfit: true, text: "Steel Armor"}), {formType: W.WEAPON, weaponType: 1, infoDamage: 9, equipState: 3, outfit: true}],
   };
   box.gfx.io = {GameDelegate: {call: (name, args) => moves.push(name + " " + args.join(","))}};
   Equipment.kind = "container";
   Equipment.subject = {player: false, name: "Lydia"};
   Equipment.menu.inventoryLists.itemList = {_selectedIndex: 5, entryList: []};
   Equipment.menu.inventoryLists.categoryList.entryList[0].flag = 2048;
   said("the follower's side is before the divider", Equipment.wearerFlags().join(","), "2048,4096");
   const theirs = armor(1, 16, 1, {side: 2048, itemIndex: 0, formId: 7, text: "Iron Helmet"});
   const mine = armor(1, 23, 0, {side: 2, itemIndex: 1, formId: 9, text: "Ebony Helmet"});
   const playerWorn = armor(4, 40, 1, {side: 2, itemIndex: 2, formId: 11, text: "Glass Armor"});
   said("a row of their side is theirs", Equipment.wearersRow(theirs), true);
   said("a row of the player's side is not", Equipment.wearersRow(mine), false);
   const slots = Equipment.addOutfit(Equipment.worn([theirs, mine, playerWorn], Equipment.wearerFlags()));
   said("their worn helmet and the outfit, the player's own armor stays out", slots.armor.map((piece) => piece.infoArmor).join(","), "16,31");
   said("an outfit weapon holds the empty right hand", slots.right.infoDamage, 9);
   const outfit = box.skse.plugins.EquipmentPanel.Outfit;
   box.skse.plugins.EquipmentPanel.Outfit = () => [armor(4, 33, 1, {outfit: true, formId: 80210, text: "Steel Armor"})];
   const listed = armor(4, 33, 1, {side: 2048, itemIndex: 3, formId: 80210, text: "Steel Armor"});
   said("an outfit a mod lists among the rows counts once", Equipment.addOutfit(Equipment.worn([theirs, listed], Equipment.wearerFlags())).armor.map((piece) => piece.text).join(","), "Iron Helmet,Steel Armor");
   box.skse.plugins.EquipmentPanel.Outfit = outfit;
   said("an outfit piece can be taken off", Equipment.canTakeOff({entries: [slots.armor[1]]}), true);
   const offPieces = [];
   box.skse.plugins.EquipmentPanel.TakeOffPiece = (formId) => (offPieces.push(formId), true);
   const piece = armor(4, 31, 1, {outfit: true, formId: 80211, text: "Steel Armor"});
   said("an outfit piece comes off through the plugin by its form", Equipment.dressOther(piece, false, false) && offPieces.join(";"), "80211");
   said("and never goes on that way", Equipment.dressOther(piece, false, true), false);
   said("their own piece can", Equipment.canTakeOff({entries: [theirs]}), true);
   const keptSettings = Equipment.settings;
   Equipment.settings = Object.assign({}, keptSettings, {hideIcons: true});
   said("a follower's slot has an eye", Equipment.canHide(Equipment.slotNamed("head")), true);
   said("but not their hands", Equipment.canHide(Equipment.slotNamed("right")), false);
   box.skse.plugins.EquipmentPanel.ReadOnly = () => true;
   box.skse.plugins.EquipmentPanel.HungPieces = () => [];
   said("nor a follower a mod keeps as they are", Equipment.canHide(Equipment.slotNamed("head")), false);
   said("whose hidden slot isn't shown from here either", Equipment.canToggle(Equipment.slotNamed("head")), false);
   delete box.skse.plugins.EquipmentPanel.ReadOnly;
   Equipment.settings = keptSettings;
   said("their own row goes through the plugin", Equipment.dressOther(theirs, false, false), true);
   said("off, by its row and item", worn.join(";"), "0,7,false,false");
   said("a row of the player's side is given first", Equipment.dressOther(mine, false, true), true);
   said("by the menu's move from the player's side", moves.join(";"), "ItemTransfer 1,false");
   said("the selection is left as it was", Equipment.menu.inventoryLists.itemList._selectedIndex, 5);
   said("nothing taken off the player's side", Equipment.dressOther(mine, false, false), false);
   let later;
   box.setInterval = (run) => (later = run, 7);
   box.clearInterval = () => undefined;
   Equipment.wearGivenNow([mine, armor(1, 23, 0, {side: 2048, itemIndex: 3, formId: 9, text: "Ebony Helmet", count: 0})]);
   said("a gift the game refused leaves what they had", Equipment.wearNext, undefined);
   Equipment.wearGivenNow([mine, armor(1, 23, 0, {side: 2048, itemIndex: 3, formId: 9, text: "Ebony Helmet", count: 1})]);
   said("nothing goes on while the game fills the rows", worn.join(";"), "0,7,false,false");
   later();
   said("the given row goes on a moment after it turned up on their side", worn.join(";"), "0,7,false,false;3,9,false,true");
   said("and is waited for no more", Equipment.wearGiven, undefined);
   const lines = [];
   Equipment.wearLines(sword(9, 0), lines);
   said("their one handed weapon goes on in either hand", lines.map((line) => line.key).join(","), "wear,wearLeft,-");
   const off = [];
   Equipment.wearLines(theirs, off);
   said("their worn piece comes off", off[0].key + " " + off[0].words, "wear Take off");
   Equipment.menu.bFadedIn = true;
   Equipment.menu.inventoryLists.itemList.disableInput = false;
   Equipment.context = {_visible: false};
   said("the rows may be filled anew while nothing holds one", Equipment.refillReady(), true);
   Equipment.context._visible = true;
   said("not under the menu of a row", Equipment.refillReady(), false);
   Equipment.context._visible = false;
   Equipment.cardAsking = true;
   said("not while the slider asks how many", Equipment.refillReady(), false);
   Equipment.cardAsking = false;
   Equipment.heldEquip = {index: 1};
   said("not while a press waits to become a drag", Equipment.refillReady(), false);
   Equipment.heldEquip = undefined;
   box.skse.plugins.EquipmentPanel.ReadOnly = () => true;
   const before = worn.length;
   said("a follower a mod keeps look only takes nothing off", Equipment.dressOther(theirs, false, false), false);
   said("and gets nothing", Equipment.dressOther(mine, false, true), false);
   said("the plugin heard nothing", worn.length, before);
   said("their slot offers no take off", Equipment.canTakeOff({entries: [theirs]}), false);
   const looking = [];
   Equipment.wearLines(theirs, looking);
   said("their rows offer nothing to wear", looking.length, 0);
   Equipment.settings = {hideIcons: true};
   box.skse.plugins.EquipmentPanel.HungPieces = () => [];
   Equipment.hiddenMask = 0;
   Equipment.hiddenPieces = [];
   const why = Equipment.contextLines({name: "head", icon: "helmet", entries: [theirs]}).map((line) => line.key).join(",");
   said("the slot's menu says a mod keeps them as they are", why.indexOf("readOnly") >= 0 && why.indexOf("takeOff") < 0, true);
   box.skse.plugins.EquipmentPanel.ReadOnly = () => false;
   said("dressed again once the mod lets go", Equipment.canTakeOff({entries: [theirs]}), true);
   const spare =armor(1, 18, 0, {side: 2048, itemIndex: 4, formId: 13, text: "Steel Helmet"});
   Equipment.busy = false;
   Equipment.activeSlot = Equipment.slotNamed("head");
   Equipment.menu._platform = 0;
   said("a mouse's click on a row moves it as the game does", Equipment.padWears(spare), false);
   Equipment.menu._platform = 1;
   said("a pad's A on a row of the filtered list puts it in the slot", Equipment.padWears(spare), true);
   said("through the plugin", worn[worn.length - 1], "4,13,false,true");
   Equipment.busy = false;
   said("a row that doesn't fit the slot moves as the game does", Equipment.padWears(sword(9, 0)), false);
   Equipment.activeSlot = undefined;
   Equipment.menu._platform = 0;
   Equipment.subject = {player: true};
   said("a plain chest stands for the player as before", Equipment.wearerFlags().join(","), "2,4");
   said("and has no follower's rows", Equipment.wearersRow(theirs), false);
}

// The last line of a follower's piece in their trade tells which mod put it on them or took it off, as the plugin noted
// it. The player's own change through the panel clears it in the plugin, the card asks each time it draws
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(true);
   const box = freshPanel.context;
   const changes = {7: {by: "AsheCombatHeadgear.esp", on: false}, 80210: {by: "FollowerEquipControl.dll", on: true}};
   const asked = [];
   box.skse.plugins.EquipmentPanel = {
      ChangedBy: (formId) => (asked.push(formId), changes[formId] !== undefined ? Object.assign({name: "Lydia"}, changes[formId]) : undefined),
      Wear: (index, form) => (delete changes[form], true),
   };
   Equipment.settings = {quietTags: true, modOrigin: true, questLine: true, slotNumbers: false};
   Equipment.kind = "container";
   Equipment.subject = {player: false, name: "Lydia"};
   Equipment.menu.inventoryLists.categoryList.entryList[0].flag = 2048;
   const helmet = armor(1, 16, 0, {side: 2048, itemIndex: 0, formId: 7, text: "Iron Helmet", equipmentOrigin: "Helmets.esp"});
   const outfit = armor(4, 31, 1, {outfit: true, formId: 80210, text: "Steel Armor"});
   const plain = armor(8, 9, 1, {side: 2048, itemIndex: 1, formId: 11, text: "Iron Gauntlets"});
   const mine = armor(1, 23, 0, {side: 2, itemIndex: 2, formId: 7, text: "Iron Helmet"});
   said("a piece a mod took off them, the line last under the quiet ones", Equipment.quietLines(helmet).join("|"), "From Helmets.esp|! Taken off Lydia by AsheCombatHeadgear.esp");
   said("a piece of their outfit a plugin put on, in its slot", Equipment.quietLines(outfit).join("|"), "! Put on Lydia by FollowerEquipControl.dll");
   said("with the quiet tags off it stays", (Equipment.settings.quietTags = false, Equipment.quietLines(helmet).join("|")), "! Taken off Lydia by AsheCombatHeadgear.esp");
   Equipment.settings.quietTags = true;
   said("a piece no mod changed has none", Equipment.quietLines(plain).join("|"), "");
   asked.length = 0;
   said("the same item on the player's side has none", Equipment.quietLines(mine).join("|"), "");
   said("and the plugin isn't asked for their rows", asked.length, 0);
   said("the player takes it off through the panel", Equipment.dressOther(helmet, false, false), true);
   said("the line is gone after the player's change", Equipment.quietLines(helmet).join("|"), "From Helmets.esp");
   Equipment.kind = "inventory";
   Equipment.subject = {player: true};
   said("none in the player's own inventory", Equipment.quietLines(armor(4, 31, 1, {side: 2, formId: 80210, text: "Steel Armor"})).join("|"), "");
   Equipment.kind = "container";
   Equipment.subject = {player: false, name: "Lydia"};
   delete box.skse.plugins.EquipmentPanel.ChangedBy;
   said("a plugin without the function gives no line", Equipment.quietLines(outfit).join("|"), "");
}

// Numbers and names from outside the mod: a word where a number goes, NaN, a "#" inside a name. ActionScript 2 reads
// "a <= NaN" as true where node reads it false, so these check what comes out rather than a loop that never ends
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(true);
   const box = freshPanel.context;

   said("a number of a word is 0", Equipment.number("lots"), 0);
   said("a number of NaN is 0", Equipment.number(NaN), 0);
   said("a number written as text counts", Equipment.number("12.5"), 12.5);
   said("a loop bound is capped", Equipment.count(1e9), 32);
   said("an endless one too", Equipment.count(Infinity), 32);
   said("a small one stays", Equipment.count(3), 3);

   said("a name with a sign in a numbered place", Equipment.say("#1 of #2", "Sword #2", "Bow"), "Sword #2 of Bow");
   said("a name with a sign in a place in turn", Equipment.say("# and #", "a#", "b"), "a# and b");
   said("places by number in their own order", Equipment.say("#2 then #1", "x", "y"), "y then x");
   said("words with no values keep their sign", Equipment.say("Slot #"), "Slot #");
   said("a sign with no value left stays", Equipment.say("# and #", "a"), "a and #");
   // the item window's From line: the sign ends the words, its piece is empty (AS2 read NaN there and kept the sign)
   said("a sign at the very end takes its value", Equipment.say("From #", "Fish.esm"), "From Fish.esm");

   Equipment.readSkin({Appearance: {colors: {text: {enabled: "dark"}}}});
   said("a skin's text colour of a word is no paper", Equipment.paper, false);
   Equipment.readSkin({Appearance: {colors: {text: {enabled: "0x141414"}}}});
   said("a colour written as text still counts", Equipment.paper, true);
   Equipment.readSkin({});

   const categories = Equipment.menu.inventoryLists.categoryList;
   categories.dividerIndex = "2";
   said("a divider written as text", Equipment.ownFlags().join(","), "2,4");
   categories.dividerIndex = "none";
   said("a divider of a word splits nothing", Equipment.ownFlags(), undefined);
   Equipment.kind = "container";
   Equipment.subject = {player: false, name: "Lydia"};
   categories.dividerIndex = 1e9;
   said("a divider past the list stops with the list", Equipment.wearerFlags().length, categories.entryList.length);
   categories.dividerIndex = NaN;
   said("a divider of NaN splits nothing", Equipment.wearerFlags(), undefined);
   categories.dividerIndex = 2;
   Equipment.kind = "inventory";
   Equipment.subject = {player: true};

   // a slot's category is looked for on one side, the chest's or follower's side has the player's flags moved up ten
   // bits: the Other slot of a follower's trade sent the list over to the player
   categories.activeSegment = 0;
   said("armor of the follower's side in view", Equipment.categoryWith(4), 1);
   said("their own flag on their side", Equipment.categoryWith(4096), 1);
   categories.activeSegment = 1;
   said("the player's armor on the player's side", Equipment.categoryWith(4), 4);
   said("their flag isn't looked for on the player's side", Equipment.categoryWith(4096), -1);
   categories.activeSegment = 0;
   said("an entry's own side wins over the side in view", Equipment.categoryWith(4, {side: 4}), 4);
   said("and theirs stays theirs", Equipment.categoryWith(4, {side: 4096}), 1);
   categories.activeSegment = undefined;

   // the list of a recharge on the card closes on Tab, Esc and a right press like the panel's menus
   const card = {HandleListMenuInput: () => true};
   card.handleInput = (details) => {
      card.closedBy = details.navEquivalent;
      card.InputHandler = undefined;
   };
   Equipment.menu.itemCard = card;
   said("no list, Tab is the menu's", Equipment.chargeKey({value: "keyDown", navEquivalent: "tab"}), false);
   card.InputHandler = card.HandleListMenuInput;
   said("an arrow walks the list", Equipment.chargeKey({value: "keyDown", navEquivalent: "down"}), false);
   said("Tab closes the list", Equipment.chargeKey({value: "keyDown", navEquivalent: "tab"}), true);
   said("through the card's own cancel", card.closedBy, "tab");
   card.InputHandler = card.HandleListMenuInput;
   said("Esc too", Equipment.chargeKey({value: "keyDown", navEquivalent: "escape-gamepad_B"}), true);
   card.InputHandler = card.HandleListMenuInput;
   said("a key let go does nothing", Equipment.chargeKey({value: "keyUp", navEquivalent: "tab"}), false);
   said("a right press closes it", Equipment.closeChargeList(), true);
   said("and finds nothing more to close", Equipment.closeChargeList(), false);
   Equipment.menu.itemCard = undefined;

   said("no time left for NaN", Equipment.timeLeft(NaN), "");
   said("nor for forever", Equipment.timeLeft(Infinity), "");
   said("nor for a word", Equipment.timeLeft("soon"), "");
   said("a time written as text", Equipment.timeLeft("90"), "1 min");

   const fills = [];
   box.flash = {geom: {Matrix: function() { this.createGradientBox = (wide) => fills.push(wide); }}};
   const page = {lineStyle() {}, beginFill() {}, endFill() {}, beginGradientFill() {}};
   const roundBox = Equipment.roundBox;
   Equipment.roundBox = () => undefined;
   Equipment.heroBar(page, 0, 0, 100, 8, 0 / 0, 0xFF0000);
   said("a pool of 0 of 0 fills nothing", fills.length, 0);
   Equipment.heroBar(page, 0, 0, 100, 8, 0.5, 0xFF0000);
   said("half a pool fills half the bar", fills.join(","), "49");
   Equipment.heroBar(page, 0, 0, 100, 8, Infinity, 0xFF0000);
   said("more than full fills it all", fills.join(","), "49,98");
   Equipment.roundBox = roundBox;

   const field = {_x: 10, _width: 100, _height: 20};
   said("icons step by the row's best icon", Equipment.iconsEnd({bestIcon: {_width: 16}}, field, {favorite: true}, {}), 10 + 100 + Equipment.ICON_GAP + 16 * Equipment.ICON_STEP);
   said("a row with no best icon steps by the name's height", Equipment.iconsEnd({bestIcon: {}}, field, {favorite: true, isEnchanted: true}, {}), 10 + 100 + Equipment.ICON_GAP + 2 * 20);

   // the voice of the magic menu has the ammo's place in the inventory's switches
   const keptSettings = Equipment.settings;
   Equipment.INVENTORY_SLOTS = Equipment.SLOTS;
   Equipment.settings = {slotsOff: 4};
   said("ammo off leaves the voice", Equipment.magicSlotShown(Equipment.MAGIC_SLOTS[2]), true);
   Equipment.settings = {slotsOff: 1};
   said("the right hand off takes the right hand", Equipment.magicSlotShown(Equipment.MAGIC_SLOTS[0]), false);
   said("and leaves the left", Equipment.magicSlotShown(Equipment.MAGIC_SLOTS[1]), true);
   Equipment.settings = keptSettings;
}

// a damage of a word compares as none
expect("sword, the held sword's damage is a word", difference([sword("lots", 3)], sword(10)), 10);
expect("arrow, the worn arrow's damage is a word", difference([bow(9, 3), arrow("lots", 1)], arrow(10)), 10);

// the eyes' own movie draws an eye for every six numbers, a stray number or a list with no length draws none
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const made = [];
   const holder = {createEmptyMovieClip: (name) => (made.push(name), {beginFill() {}, endFill() {}})};
   const context = {Math, _root: {eyes: {removeMovieClip() {}}, createEmptyMovieClip: () => holder}};
   // the movie finds _global's members by their bare names
   context._global = context;
   context.Equipment = {drawRing() {}, drawIcon() {}};
   vm.createContext(context);
   vm.runInContext(fs.readFileSync(path.join(__dirname, "..", "overlay", "eyes.as"), "utf8"), context, {filename: "eyes.as"});
   const eyes = (told) => (made.length = 0, context.Eyes.draw(told, 16 / 9), made.length);
   said("six numbers make an eye", eyes([0.1, 0.2, 0.05, 0, 1, 255]), 1);
   said("a stray seventh makes no second", eyes([0.1, 0.2, 0.05, 0, 1, 255, 0.4]), 1);
   said("twelve make two", eyes(new Array(12).fill(0.1)), 2);
   said("five make none", eyes([0.1, 0.2, 0.05, 0, 1]), 0);
   said("a list with no length makes none", eyes({}), 0);
}

// a row the keys chose stays while the pointer rests off the rows and nudges, a row the mouse chose goes when it leaves
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const list = {selectedIndex: 3, isMouseDrivenNav: false};
   Equipment.menu.inventoryLists.itemList = list;
   Equipment.menu._platform = 0;
   Equipment.context = {_visible: false};
   Equipment.lens = {_visible: false};
   Equipment.listsAnswer = () => true;
   Equipment.rowUnderMouse = () => undefined;
   Equipment.leaveRows();
   said("a row the keys chose stays", list.selectedIndex, 3);
   list.isMouseDrivenNav = true;
   Equipment.rowChosen({index: 3, keyboardOrMouse: 1});
   Equipment.leaveRows();
   said("so does the first one the keys chose, SkyUI leaves the list as the mouse's then", list.selectedIndex, 3);
   Equipment.rowChosen({index: 3, keyboardOrMouse: 0});
   Equipment.leaveRows();
   said("a row the mouse chose goes off the rows", list.selectedIndex, -1);
   list.selectedIndex = 2;
   Equipment.rowUnderMouse = () => ({text: "Iron Sword"});
   Equipment.leaveRows();
   said("and stays while the pointer is on a row", list.selectedIndex, 2);
}

// SkyUI's frame has a nine-slice grid of its own and grows by its height, the size it had comes back from the frame
// itself, a new frame SkyUI put up for another kind of card keeps its own
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const frame = (high, grid) => {
      const back = {_y: 0, _height: high, scale9Grid: grid ? {y: 27, height: 166} : undefined};
      back.getBounds = () => ({xMin: 0, xMax: 428, yMin: back._y, yMax: back._y + back._height});
      return back;
   };
   const card = {};
   Equipment.menu.itemCard = card;
   let back = frame(208, true);
   said("a frame with its own grid grows", Equipment.growByGrid(card, back, {shift: 40}), true);
   said("down by the shift", back.getBounds().yMax, 248);
   said("its top stays", back._y, 0);
   Equipment.cardFrameAsSkyUI(back);
   said("and gets SkyUI's height back", back._height, 208);
   Equipment.growByGrid(card, back, {shift: 40});
   const next = frame(153, true);
   Equipment.cardFrameAsSkyUI(next);
   said("a new frame for another kind keeps its own height", next._height, 153);
   said("a frame without a grid is left to the copies", Equipment.growByGrid(card, frame(208, false), {shift: 40}), false);
   const stiff = frame(208, true);
   stiff.getBounds = () => ({xMin: 0, xMax: 428, yMin: 0, yMax: 208});
   said("one that doesn't take the height stays as it was", Equipment.growByGrid(card, stiff, {shift: 40}), false);
   said("with its height back", stiff._height, 208);
}

// numbers a skin or another mod hands over may be missing: in AS2 a <= b and a >= b are true then, < and > are false
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const card = {background: {_width: 428, getBounds: () => ({xMin: -214, xMax: 214, yMin: -100, yMax: 100})}};
   const box = Equipment.frameBox(card, card);
   said("a frame drawn round its middle keeps its width", box.xMax - box.xMin, 428);
   card.background.getBounds = () => ({xMin: -20, xMax: 448, yMin: -20, yMax: 228});
   said("a frame with a clear margin round it still loses the margin", Equipment.frameBox(card, card).xMax - Equipment.frameBox(card, card).xMin, 428);
   said("edges a unit apart are the same", Equipment.sameEdge(10, 11), true);
   said("two units apart they aren't", Equipment.sameEdge(10, 12), false);
   said("a missing number is never the same edge", Equipment.sameEdge(NaN, 10), false);
   const wanted = [];
   Equipment.menu.inventoryLists.itemList = {selectedEntry: undefined};
   Equipment.wantWindow = (row) => wanted.push(row);
   Equipment.showWindow = () => undefined;
   Equipment.onHighlight({type: "hideItemsList"});
   Equipment.onHighlight({type: "itemHighlightChange", index: 3});
   said("an event of the lists with no index wants no window", wanted.join(","), "false,true");
   const holder = {_yscale: 70, _xscale: 70};
   Equipment.window = {};
   Equipment.menu.itemCard = {_parent: holder};
   Equipment.settings = {windowSize: 100};
   Equipment.squash = 1;
   Equipment.rowsEdge = () => ({wide: 800, right: 800});
   Equipment.cardWidth = () => 0;
   Equipment.windowUnits = () => undefined;
   Equipment.placeWindowLeft = () => undefined;
   Equipment.sizeWindow();
   said("a card with no width keeps its scale", holder._yscale, 70);
}

// a worn thing without its model shows the icon its row has in the list, from a mod's set or the list's own
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const loads = [];
   const fakeClip = () => {
      const clip = {_visible: true, clear: () => undefined};
      clip.createEmptyMovieClip = (name) => (clip[name] = fakeClip(), clip[name]._parent = clip, clip[name]);
      clip.gotoAndStop = (label) => clip.label = label;
      clip.getBounds = () => ({xMin: 0, yMin: 0, xMax: 40, yMax: 40});
      return clip;
   };
   freshPanel.context.MovieClipLoader = function() {
      let listener;
      this.addListener = (one) => listener = one;
      this.loadClip = (source, target) => { loads.push(source); target.loaded = true; listener.onLoadInit(target); };
   };
   freshPanel.context.flash = {geom: {ColorTransform: function() {}, Transform: function() {}}};
   const signs = [];
   Equipment.drawIcon = (clip, icon) => signs.push(icon);
   Equipment.menu.inventoryLists.itemList = {listState: {iconSource: "skyui/icons_item_psychosteve.swf"}};
   Equipment.settings = {slotModels: false};
   Equipment.plugin = () => ({});
   const box = fakeClip();
   box.icon = fakeClip();
   const slot = {name: "body", icon: "body", box, entries: [armor(4, 27, 1, {iconSource: "I4IconAddon/icons.swf", iconLabel: "clothing_backpack", iconColor: 0xe07020})]};
   Equipment.showIcon(slot);
   said("the row's own set is loaded", loads.join(","), "I4IconAddon/icons.swf");
   said("at the row's label", box.icon.row.art.label, "clothing_backpack");
   said("and no sign is drawn", signs.length, 0);
   slot.entries = [armor(4, 27, 1, {iconLabel: "armor_body"})];
   Equipment.showIcon(slot);
   said("a row with no set of its own takes the list's", loads[loads.length - 1], "skyui/icons_item_psychosteve.swf");
   said("at its label", box.icon.row.art.label, "armor_body");
   Equipment.showIcon(slot);
   said("the same set isn't loaded again", loads.length, 2);
   slot.entries = [];
   Equipment.showIcon(slot);
   said("an empty slot hides the icon", box.icon.row._visible, false);
   said("and shows its sign", signs.join(","), "body");
   slot.entries = [armor(4, 27, 1, {iconLabel: "armor_body"})];
   Equipment.settings.slotModels = true;
   Equipment.showIcon(slot);
   said("a slot with its model shows no icon", box.icon.row._visible, false);
}

// A teammate's drained weapon gets recharged in their trade: a line of the row menu, the card's list of the soul gems
// of both, the rows of the weapon and of the gem the player picks go to the plugin
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(true);
   const box = freshPanel.context;
   const calls = [];
   const charges = {21: 40, 22: 100, 23: -1};
   const shown = [];
   box.skse.plugins.EquipmentPanel = {
      ChargeOf: (index, form) => charges[form],
      SoulGems: (index, form) => form == 21 ? {type: 14, currentCharge: 40, listItems: [{text: "Grand Soul Gem", owner: "", count: 1, chargeAdded: 300, itemIndex: 4, formId: 80},
         {text: "Petty Soul Gem", owner: "Lydia", count: 2, chargeAdded: 25, itemIndex: 7, formId: 90}]} : undefined,
      Recharge: (weapon, weaponForm, gem, gemForm) => (calls.push(`Recharge ${weapon},${weaponForm},${gem},${gemForm}`), true),
   };
   box.gfx.io = {GameDelegate: {call: (name, args) => calls.push(name + " " + args.join(","))}};
   Equipment.kind = "container";
   Equipment.settings = {};
   Equipment.subject = {player: true};
   Equipment.closeContext = () => undefined;
   const menu = Equipment.menu;
   menu.bNPCMode = true;
   menu.bFadedIn = true;
   menu.isViewingContainer = () => true;
   menu.itemCard = {itemInfo: {}, ItemList: {entryList: [], addEventListener: () => undefined}};
   menu.UpdateItemCardInfo = (info) => {
      shown.push(info.type + ":" + info.listItems.length);
      menu.itemCard.ItemList.entryList = info.listItems;
   };
   menu.inventoryLists.itemList = {entryList: [], disableInput: false, disableSelection: false};
   const lines = (entry) => Equipment.rowLines(entry).filter((line) => line.key !== "-").map((line) => line.words).join(" | ");
   const blade = (form, extra) => Object.assign(sword(9, 0), {itemIndex: form - 20, formId: form, count: 1, text: "Sword " + form}, extra || {});
   said("a drained sword of the one traded with", lines(blade(21)), "Recharge | Take");
   said("a full one has nothing to recharge", lines(blade(22)), "Take");
   said("one without an enchantment neither", lines(blade(23)), "Take");
   menu.isViewingContainer = () => false;
   said("the player's own side recharges nothing in a trade", lines(blade(21)).indexOf("Recharge"), -1);
   menu.isViewingContainer = () => true;
   menu.bNPCMode = false;
   said("a chest is no teammate", lines(blade(21)), "Take");
   menu.bNPCMode = true;
   Equipment.subject = {player: false, name: "Lydia"};
   said("with the panel up, among what goes on them", lines(blade(21, {side: 2048})), "Equip | Equip in left hand | Recharge | Take");
   Equipment.subject = {player: true};

   const drained = blade(21);
   menu.inventoryLists.itemList.selectedEntry = drained;
   menu.inventoryLists.itemList.entryList = [drained];
   Equipment.pickRow = () => true;
   Equipment.rowAct("charge", drained);
   said("the line puts the list of gems on the card", shown.join(";"), "14:2");
   said("the teammate's gem says whose it is", menu.itemCard.ItemList.entryList.map((line) => line.text).join(" / "), "Grand Soul Gem / Lydia's Petty Soul Gem");
   said("the list holds the row it charges", Equipment.charging.weapon.formId, 21);
   let laidOut = 0;
   Equipment.window = {};
   Equipment.showWindow = () => laidOut++;
   Equipment.chargeAsks({type: "subMenuAction", opening: true, menu: "list"});
   said("the game holds the item menu's keys while the list is up", calls.join(";"), "QuantitySliderOpen true");
   said("the window lays the list out under the model", laidOut, 1);
   Equipment.lineChosen({index: 1});
   said("the weapon's row and the gem's row picked go to the plugin", calls[calls.length - 1], "Recharge 1,21,7,90");
   Equipment.chargeAsks({type: "subMenuAction", opening: false, menu: "list"});
   said("the list gone, the card asks for the item again", calls.slice(-2).join(";"), "QuantitySliderOpen false;RequestItemCardInfo ");
   said("and the window lays the item out again", laidOut, 2);
   said("and the charge is over", Equipment.charging, undefined);
   Equipment.lineChosen({index: 0});
   said("a pick without a list up does nothing", calls.filter((call) => call.indexOf("Recharge") == 0).length, 1);
   shown.length = 0;
   said("a row the plugin can't charge shows no list", Equipment.chargeTeammate(blade(23)) || shown.length, 0);
   Equipment.chargeAsks({type: "subMenuAction", opening: true, menu: "quantity"});
   said("the slider of a move is none of it", calls.filter((call) => call == "QuantitySliderOpen true").length, 1);
}

// Completionist's list takes its colour off after "CompTag" when it draws a row. The panel's fields show the name alone,
// and a name cut to make room for a mark keeps the colour after it
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   said("a name with Completionist's colour shows alone", Equipment.gameName("Amulet of TalosCompTag16753920"), "Amulet of Talos");
   said("a name without it stays", Equipment.gameName("Iron Sword"), "Iron Sword");
   said("a tag word inside a name is a name", Equipment.markupAt("CompTag"), 7);
   const entry = {text: "Ancient Nord Hero WarhammerCompTag16753920", equipmentDifference: 5};
   const drawn = [];
   const row = {equipmentFormatName: (field, shown) => drawn.push(shown.text)};
   const field = {_name: "textField"};
   Equipment.settings = {arrows: true};
   Equipment.menu.inventoryLists.itemList = {layout: {columnLayoutData: [{stageName: "textField", x: 0, width: 100}]}};
   Equipment.junkShown = () => false;
   Equipment.questShown = () => false;
   Equipment.afterIcons = (r, f, e) => e.text.split("CompTag")[0].length * 5;
   Equipment.makeRoom(row, field, entry, {});
   said("the cut name keeps the colour after it", drawn[drawn.length - 1].indexOf("...CompTag16753920") > 0, true);
   said("and the row keeps its whole name after", entry.text, "Ancient Nord Hero WarhammerCompTag16753920");

   // SkyUI shows 77 letters of a longer name and "...", the cut starts from those
   const long = {text: "W".repeat(120), equipmentDifference: 5};
   const longField = {_name: "textField", text: "", textWidth: 0};
   let formats = 0;
   const longRow = {equipmentFormatName: (f, shown) => {
      formats++;
      f.text = shown.text.length > 80 ? shown.text.substr(0, 77) + "..." : shown.text;
      f.textWidth = f.text.length * 5;
   }};
   longRow.equipmentFormatName(longField, long, {});
   formats = 0;
   Equipment.afterIcons = (r, f) => f.textWidth;
   Equipment.makeRoom(longRow, longField, long, {});
   said("a name SkyUI cut itself ends inside its column", longField.textWidth + Equipment.MARK_ROOM <= 100, true);
   said("in a few formats of the row", formats <= 3, true);
   said("and keeps its whole name after", long.text.length, 120);
}

// A follower's own potion or food goes into them from the row menu of their trade, a poison doesn't, nor anything of
// the player's side
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(true);
   const box = freshPanel.context;
   const calls = [];
   let drinks = true;
   box.skse.plugins.EquipmentPanel = {UseOn: (index, form) => (calls.push(`UseOn ${index},${form}`), drinks)};
   box.gfx.io = {GameDelegate: {call: (name, args) => calls.push(name + " " + args.join(","))}};
   Equipment.kind = "container";
   Equipment.settings = {};
   Equipment.closeContext = () => undefined;
   Equipment.pickRow = () => true;
   const menu = Equipment.menu;
   menu.bNPCMode = true;
   menu.isViewingContainer = () => true;
   menu.itemCard = {itemInfo: {}};
   menu.inventoryLists.itemList = {entryList: []};
   Equipment.subject = {player: false, name: "Lydia"};
   const potion = (subType, extra) => Object.assign({formType: Equipment.POTION, subType: subType, side: 2048, itemIndex: 5, formId: 70, count: 3, text: "Potion"}, extra || {});
   const words = (entry) => Equipment.rowLines(entry).filter((line) => line.key !== "-").map((line) => line.words);
   said("her potion can be used on her", words(potion(0))[0], "Use");
   said("her food too", words(potion(Equipment.MEAL))[0], "Use");
   said("not her poison", words(potion(Equipment.POISON_POTION)).indexOf("Use"), -1);
   Equipment.lookOnly = () => true;
   said("not while a mod keeps her look only", words(potion(0)).indexOf("Use"), -1);
   Equipment.lookOnly = () => false;
   menu.isViewingContainer = () => false;
   said("the player's own potion keeps the game's use", words(potion(0, {side: 1})).filter((word) => word == "Use").length, 1);
   menu.isViewingContainer = () => true;

   Equipment.rowAct("useOn", potion(0));
   said("the plugin gets her row", calls[0], "UseOn 5,70");
   said("and the drink is heard", calls[1], "PlaySound ITMPotionUse");
   Equipment.rowAct("useOn", potion(Equipment.MEAL));
   said("food is heard eaten", calls[3], "PlaySound ITMFoodEat");
   drinks = false;
   Equipment.rowAct("useOn", potion(0));
   said("nothing heard when nothing was used", calls.length, 5);
}

// A soul gem's row charges a weapon of the one whose inventory is open: a line of its menu, the card's list of the
// drained weapons, the meter of the one the list points at. The inventory keeps the game's own recharge on its card
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   const box = freshPanel.context;
   const calls = [];
   const shown = [];
   const meter = [];
   const weapons = {type: 14, name: "Choose Soul Gem to Use", listItems: [{text: "Sword of Frost", count: 1, charge: 40, chargeAdded: 25, itemIndex: 3, formId: 21}, {text: "Staff", count: 1, charge: 10, chargeAdded: 8, itemIndex: 5, formId: 33}], currentCharge: 40};
   box.skse.plugins.EquipmentPanel = {
      Weapons: (index, form) => form == 90 ? weapons : undefined,
      Recharge: (weapon, weaponForm, gem, gemForm) => (calls.push(`Recharge ${weapon},${weaponForm},${gem},${gemForm}`), true),
   };
   box.gfx.io = {GameDelegate: {call: (name, args) => calls.push(name + " " + args.join(","))}};
   Equipment.kind = "inventory";
   Equipment.settings = {};
   Equipment.subject = {player: true};
   const menu = Equipment.menu;
   const list = {entryList: [], selectedEntry: undefined, addEventListener: () => undefined};
   const listeners = [];
   menu.itemCard = {itemInfo: {}, ItemList: list, ItemCardMeters: {14: {SetPercent: (to) => meter.push("at " + to), SetDeltaPercent: (to) => meter.push("to " + to)}},
      addEventListener: (event, scope, name) => listeners.push(event + ":" + name)};
   menu.UpdateItemCardInfo = (info) => {
      shown.push(info.name + ":" + info.listItems.length);
      list.entryList = info.listItems;
      list.selectedEntry = info.listItems[0];
   };
   menu.inventoryLists.itemList = {entryList: [], disableInput: false, disableSelection: false};
   const lines = (entry) => Equipment.rowLines(entry).filter((line) => line.key !== "-").map((line) => line.words).join(" | ");
   const gem = (form) => ({formType: 52, itemIndex: form - 80, formId: form, count: 2, text: "Petty Soul Gem", equipState: 0});
   said("a gem that can charge a weapon of the player's", lines(gem(90)), "Recharge a weapon | Drop one | Drop all (2) | Add to favorites");
   said("one with no soul or nothing drained to charge has no such line", lines(gem(91)), "Drop one | Drop all (2) | Add to favorites");
   Equipment.kind = "barter";
   menu.isViewingVendorItems = () => false;
   said("a shop charges nothing", lines(gem(90)), "Sell one | Sell all (2)");
   Equipment.kind = "container";
   menu.bNPCMode = false;
   menu.isViewingContainer = () => true;
   said("nor a chest", lines(gem(90)), "Take one | Take all (2)");
   menu.bNPCMode = true;
   said("a gem of either side of a trade charges the teammate's weapons", lines(gem(90)), "Recharge a weapon | Take one | Take all (2)");
   Equipment.kind = "inventory";

   Equipment.pickRow = () => true;
   Equipment.rowAct("chargeWith", gem(90));
   said("the card asks for the weapon", shown.join(";"), "Choose a weapon to charge:2");
   said("its meter shows the first weapon's charge and what the gem adds", meter.join(", "), "at 40, to 65");
   list.selectedEntry = weapons.listItems[1];
   Equipment.chargeMeter();
   said("and follows the list to the next", meter.slice(-2).join(", "), "at 10, to 18");
   Equipment.chargeAsks({type: "subMenuAction", opening: true, menu: "list"});
   said("the inventory holds its keys itself", calls.length, 0);
   Equipment.lineChosen({index: 1});
   said("the weapon picked and the gem's row go to the plugin", calls[calls.length - 1], "Recharge 5,33,10,90");
   Equipment.chargeAsks({type: "subMenuAction", opening: false, menu: "list"});
   said("the inventory asks for its card again itself", calls.length, 1);
   said("the charge is over", Equipment.charging, undefined);

   const vanilla = [];
   menu.onItemCardListPress = (event) => vanilla.push(event.index);
   Equipment.startCharging();
   said("the card's list goes to the panel", listeners.join(","), "itemPress:lineChosen,subMenuAction:chargeAsks");
   menu.onItemCardListPress({index: 2});
   said("the game's own list of gems for the player's weapon goes on to the game", vanilla.join(","), "2");
   Equipment.charging = {gem: {itemIndex: 10, formId: 90}};
   menu.onItemCardListPress({index: 0});
   said("a list of the panel's never reaches the game's recharge", vanilla.join(","), "2");
   Equipment.charging = undefined;
}


// a chest's side in view takes the chest's junk, the player's side stores the player's
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(true);
   Equipment.kind = "container";
   let chestInView = true;
   Equipment.menu.bNPCMode = false;
   Equipment.menu.isViewingContainer = () => chestInView;
   const mine = {formId: 1, text: "Pelt", equipmentJunk: true, side: 2, count: 3, equipState: 0};
   const theirs = {formId: 2, text: "Plate", equipmentJunk: true, side: 2048, count: 2, equipState: 0};
   const kept = {formId: 3, text: "Cup", side: 2048, count: 1, equipState: 0};
   Equipment.menu.inventoryLists.itemList = {entryList: [mine, theirs, kept]};
   said("the chest's side takes", Equipment.junkVerb(), "take");
   said("the chest's junk", Equipment.junkRows().map((row) => row.text).join(","), "Plate");
   said("its button says so", Equipment.junkWords("take", 2), "Take all junk (2)");
   chestInView = false;
   said("the player's side stores", Equipment.junkVerb(), "store");
   said("the player's junk", Equipment.junkRows().map((row) => row.text).join(","), "Pelt");
   Equipment.menu.bNPCMode = true;
   said("a follower's trade has no junk button", Equipment.junkVerb(), undefined);
}

// the subcategories chosen in a family come back from the plugin's memory, only keys its rows still have
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   const kept = {};
   Equipment.plugin = () => ({Remember: (key, words) => { kept[key] = words; }, Recall: (key) => kept[key] !== undefined ? kept[key] : ""});
   const family = Object.keys(Equipment.CHIP_ROWS)[0];
   const rows = Equipment.CHIP_ROWS[family];
   Equipment.chipsFamily = family;
   Equipment.activeSlot = undefined;
   Equipment.chosenChips = [];
   Equipment.chosenChips[rows.length - 1] = rows[rows.length - 1][0].key;
   Equipment.keepChips();
   const back = Equipment.keptChips(family);
   said("a chosen chip comes back in its row", back[rows.length - 1], rows[rows.length - 1][0].key);
   said("an empty row stays empty", back[0] === undefined || rows.length === 1, true);
   kept["chips"] = family + "|no such chip";
   said("a key the rows lost is dropped", Equipment.keptChips(family)[0], undefined);
   said("a family with nothing kept starts empty", Equipment.keptChips("nothing here").length, 0);
   Equipment.activeSlot = {name: "head"};
   kept["chips"] = "";
   Equipment.chosenChips = [rows[0][0].key];
   Equipment.keepChips();
   said("the chips of a slot filter aren't kept", kept["chips"], "");
   Equipment.activeSlot = undefined;
   kept["chips"] = "armor|clothing";
   said("another family gets nothing of what was kept", Equipment.keptChips("potions").length, 0);
   said("its own family gets it back", Equipment.keptChips("armor")[0], "clothing");

   // a pick that leaves no row with the other groups lets them go
   const lists = Equipment.menu.inventoryLists;
   lists.categoryList.selectedEntry = {flag: 4};
   lists._typeFilter = {isMatch: () => true};
   lists.itemList = {entryList: [armor(4, 0, 0, {weightClass: 3}), armor(0x1000, 10, 0, {weightClass: 0})]};
   Equipment.chipsFamily = "armor";
   Equipment.chosenChips = ["clothing", "other"];
   Equipment.leaveRowsOpen(1);
   said("Other alone stays after Clothing left nothing", Equipment.chosenChips.join(","), ",other");
   Equipment.chosenChips = ["clothing", "body"];
   Equipment.leaveRowsOpen(1);
   said("a pick that leaves rows keeps the other groups", Equipment.chosenChips.join(","), "clothing,body");

   // a chip that would leave nothing with the other group's choice is faint, the first group of a station never is
   lists.itemList = {entryList: [armor(1, 20, 0, {weightClass: 1}), armor(4, 30, 0, {weightClass: 0})]};
   const armorRows = Equipment.CHIP_ROWS.armor;
   let room = Equipment.chipRoom(armorRows, ["light"]);
   said("Light chosen, Head finds no light helmet", Equipment.anyHolds(room[1], "head"), false);
   said("and Body finds the light cuirass", Equipment.anyHolds(room[1], "body"), true);
   said("the group of the choice itself is never faint", room[0], undefined);
   room = Equipment.chipRoom(armorRows, [undefined, "head"]);
   said("Head chosen, Heavy finds the heavy helmet", Equipment.anyHolds(room[0], "heavy"), true);
   said("and Light finds none", Equipment.anyHolds(room[0], "light"), false);
   said("nothing chosen leaves every chip as it is", Equipment.chipRoom(armorRows, []).length, 0);
   Equipment.chipsFamily = "gear";
   said("a station's weapons or armor stays clear", Equipment.chipRoom([[], armorRows[0]], [undefined, "light"])[0], undefined);
   Equipment.chipsFamily = "armor";

   // a station's page of every row is its ALL and has no chips, its weapons and armor pages have theirs
   lists.itemList = {entryList: [armor(1, 20, 0, {weightClass: 1}), sword(8)]};
   lists.categoryList.entryList = [{flag: 63}, {flag: 1}, {flag: 4}];
   lists._typeFilter = {isMatch: (entry, flag) => flag == 63 || (flag == 4) == (entry.formType == W.ARMOR)};
   said("ALL of a forge has no chips", Equipment.stationFamily(63), undefined);
   said("its armor page has the armor chips", Equipment.stationFamily(4), "armor");
   said("its weapons page the weapon chips", Equipment.stationFamily(1), "weapons");
   lists.itemList.entryList.push({formType: W.AMMO});
   lists._typeFilter = {isMatch: (entry, flag) => flag == 63 || flag == 2 && entry.formType == W.AMMO};
   said("a page of ammo alone has no chips", Equipment.stationFamily(2), undefined);
   lists.categoryList.entryList = [{flag: 63}];
   said("a station of one page keeps the choice of both", Equipment.stationFamily(63), "gear");
   lists._typeFilter = {isMatch: () => true};

   // the strip takes two lines when the junk button has its own
   const strip = {_y: 100, listHeight: 600, entryHeight: 30, _maxListIndex: 20, requestUpdate() {}};
   lists.itemList = strip;
   Equipment.menu.updateDynamicListHeight = undefined;
   Equipment.roomHigh = 0;
   Equipment.openStrip(true, 2);
   said("two lines move the list down twice", strip._y, 100 + 2 * Equipment.STRIP_HIGH);
   Equipment.openStrip(true, 1);
   said("one line gives one back", strip._y, 100 + Equipment.STRIP_HIGH);
   said("and the height with it", strip.listHeight, 600 - Equipment.STRIP_HIGH);
}

// a spell in a hand has no row in the inventory, the plugin names it and its slot shows SkyUI's sign of its school
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel(false);
   let hands = [];
   Equipment.plugin = () => ({Hands: () => hands});
   Equipment.settings = {};
   const healing = {formId: 0x12FCC, name: "Healing", item: false, spell: true, school: 22, resistance: -1, cost: 13.4};
   const flames = {formId: 0x12FCD, name: "Flames", item: false, spell: true, school: 20, resistance: 41, cost: 9};
   const empty = {formId: 0, name: "", item: false, spell: false};
   hands = [healing, flames, empty];
   Equipment.place({armor: []});
   const right = Equipment.slotNamed("right").entries[0];
   const left = Equipment.slotNamed("left").entries[0];
   said("a restoration spell takes its school's sign", right.iconLabel, "default_restoration");
   said("with no colour", right.iconColor, undefined);
   said("a fire spell takes the fire sign", left.iconLabel, "magic_fire");
   said("in SkyUI's fire red", left.iconColor, 0xC73636);
   said("the number of a spell is its cost", Equipment.amount(right), "13");
   said("a spell can't be taken off", Equipment.canTakeOff(Equipment.slotNamed("left")), false);
   said("nor inspected", Equipment.inspectable(left), false);
   Equipment.noIconColors = true;
   Equipment.place({armor: []});
   said("SkyUI's plain icons leave the colour out", Equipment.slotNamed("left").entries[0].iconColor, undefined);
   Equipment.noIconColors = false;
   hands = [{formId: 5, name: "Spark", spell: true, school: 20, resistance: -1}, empty, empty];
   Equipment.place({armor: []});
   said("a destruction spell with no element takes the school's sign", Equipment.slotNamed("right").entries[0].iconLabel, "default_destruction");
   hands = [{formId: 6, name: "Odd", spell: true, school: -1, resistance: -1}, empty, empty];
   Equipment.place({armor: []});
   said("a spell of no school takes SkyUI's sign for one", Equipment.slotNamed("right").entries[0].iconLabel, "default_power");
   hands = [healing, flames, empty];
   const held = greatsword(20, 3);
   Equipment.place({armor: [], right: held, left: held});
   said("a weapon in the hand keeps its slot", Equipment.slotNamed("right").entries[0], held);
   said("a two-handed one takes the left hand", Equipment.slotNamed("left").taken, true);
   said("and leaves no room for a spell there", Equipment.slotNamed("left").entries.length, 1);
   Equipment.place({armor: [], left: torch(2)});
   said("a torch keeps the left hand", Equipment.slotNamed("left").entries[0].formType, W.LIGHT);
   said("while the right hand shows its spell", Equipment.slotNamed("right").entries[0].text, "Healing");
   hands = undefined;
   Equipment.plugin = () => ({});
   Equipment.place({armor: []});
   said("a plugin with no hands leaves them empty", Equipment.slotNamed("left").entries.length, 0);
}

// a gamepad reaches the companions' tabs: up from the top row, the subcategories past them, A opens the one under
// the focus and says nothing on the one already shown
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const where = (at) => at.kind + (at.column !== undefined ? ` ${at.column},${at.row}` : "") + (at.index !== undefined ? ` ${at.index}` : "");
   const slot = (column, row) => ({kind: "slot", column, row});
   const world = (extra) => Object.assign({rows: 5, chips: 0, chipStart: 0, people: 0, personStart: 0, hero: false, heroOpen: false, last: slot(1, 0)}, extra);
   const go = (at, way, extra) => where(Equipment.padNext(at, way, world(extra)));
   const person = (index) => ({kind: "person", index});
   said("up from the top row to the tab of the one shown", go(slot(0, 0), "up", {people: 3, personStart: 1}), "person 1");
   said("before the subcategories", go(slot(1, 0), "up", {people: 2, chips: 4}), "person 0");
   said("along the tabs", go(person(0), "right", {people: 3}), "person 1");
   said("the tabs end", go(person(2), "right", {people: 3}), "person 2");
   said("up from the tabs to the subcategories", go(person(1), "up", {people: 3, chips: 4, chipStart: 2}), "chip 2");
   said("nothing above the tabs without them", go(person(1), "up", {people: 3}), "person 1");
   said("down from the tabs to the top of the last column", go(person(1), "down", {people: 3, last: slot(0, 3)}), "slot 0,0");
   said("down from the subcategories to the tabs", go({kind: "chip", index: 1}, "down", {people: 2, chips: 4, personStart: 1}), "person 1");

   const switched = [];
   const you = {_visible: true, shown: true, person: {formId: 0, player: true}};
   const lydia = {_visible: true, shown: false, person: {formId: 0xA2C94, player: false}};
   const far = {_visible: false, shown: false, person: {formId: 7, player: false}};
   Equipment.companions = {_visible: true, tab0: you, tab1: lydia, tab2: far};
   Equipment.switchCompanion = (one) => switched.push(one.formId);
   Equipment.listsAnswer = () => true;
   Equipment.padMark = () => undefined;
   Equipment.padHints = () => undefined;
   said("the tabs with room on the row", Equipment.padPeople().length, 2);
   said("A on the one shown says nothing", Equipment.padPressWords(person(0)), undefined);
   said("A on a companion opens their trade", Equipment.padPressWords(person(1)), "Open");
   Equipment.padFocus = person(1);
   Equipment.padPress();
   said("and opens it", switched.join(","), String(0xA2C94));
   Equipment.companions._visible = false;
   Equipment.padLast = slot(1, 2);
   Equipment.padFocus = person(1);
   Equipment.slotShown = () => true;
   Equipment.padSettle();
   said("tabs gone, the focus goes back to the last slot", where(Equipment.padFocus), "slot 1,2");
}

// a gamepad in the magic menu: three slots walked where they stand, A narrows the list, X takes a weapon off the
// hand, the hold inspects nothing there
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const where = (at) => at.kind + (at.column !== undefined ? ` ${at.column},${at.row}` : "");
   const slot = (column, row) => ({kind: "slot", column, row});
   Equipment.INVENTORY_SLOTS = Equipment.SLOTS;
   Equipment.SLOTS = Equipment.MAGIC_SLOTS;
   Equipment.slotShown = Equipment.magicSlotShown;
   Equipment.settings = {slotsOff: 0};
   Equipment.hero = {};
   Equipment.padLast = slot(0, 0);
   const go = (at, way) => where(Equipment.padNext(at, way, Equipment.padWorld()));
   said("down from the right hand to the left", go(slot(0, 0), "down"), "slot 0,1");
   said("nothing under the left hand", go(slot(0, 1), "down"), "slot 0,1");
   said("across from the right hand to the voice", go(slot(0, 0), "right"), "slot 1,0");
   said("and from the left hand", go(slot(0, 1), "right"), "slot 1,0");
   said("nothing under the voice", go(slot(1, 0), "down"), "slot 1,0");
   said("back across to the right hand", go(slot(1, 0), "left"), "slot 0,0");
   Equipment.settings = {slotsOff: 1};
   said("the right hand off the panel, up from the left stays", go(slot(0, 1), "up"), "slot 0,1");
   Equipment.settings = {slotsOff: 0};

   const taken = [];
   const right = Equipment.slotNamed("right");
   Equipment.buildPad = () => undefined;
   Equipment.readHandsSoon = () => taken.push("read");
   Equipment.plugin = () => ({TakeOffHand: (place) => { taken.push("off " + place); return true; }});
   Equipment.startMagicPad();
   said("the pad comes to the right hand first", where(Equipment.padLast), "slot 0,0");
   said("A narrows the list", Equipment.padPressWords(slot(0, 0)), "Show what fits");
   Equipment.activeSlot = right;
   said("and lets it go again", Equipment.padPressWords(slot(0, 0)), "Show everything");
   Equipment.activeSlot = undefined;
   Equipment.padFocus = slot(0, 0);
   right.entries = [{formId: 0x12EB7, text: "Iron Sword", item: true}];
   right.taken = false;
   said("X takes a sword off", Equipment.padHideWords(), "Take off");
   Equipment.padHide();
   said("by the plugin, the hands read again", taken.join(","), "off 0,read");
   right.entries = [{formId: 0x12FCD, text: "Flames", formType: 22}];
   said("a spell has no X", Equipment.padHideWords(), undefined);
   Equipment.padFocus = slot(1, 0);
   Equipment.slotNamed("voice").entries = [];
   said("nor an empty voice", Equipment.padHideWords(), undefined);

   const inspected = [];
   Equipment.inspectEntry = (entry) => inspected.push(entry.text);
   Equipment.padFocus = slot(0, 0);
   right.entries = [{formId: 0x12EB7, text: "Iron Sword", item: true}];
   Equipment.padInspect();
   said("the hold inspects nothing without the inspect view", inspected.length, 0);
   said("nor offers it", Equipment.padInspectable(right.entries[0]), false);
   const stick = [];
   Equipment.panel = {};
   Equipment.padBuilt = true;
   Equipment.menu._platform = 1;
   Equipment.inspecting = false;
   Equipment.listsAnswer = () => true;
   Equipment.enterPad = () => stick.push("panel");
   Equipment.padInspect = () => stick.push("inspect");
   Equipment.padMark = () => undefined;
   Equipment.padTurns = () => undefined;
   Equipment.padFocus = undefined;
   Equipment.padStick(true);
   said("a slow click of the stick there still goes to the panel", stick.join(","), "panel");
   Equipment.viewer = {};
   said("the inventory's view does", Equipment.padInspectable(right.entries[0]), true);
}

// a gamepad and the menu of a row: a hold of the stick on a row of the list opens it, on the panel the hold inspects,
// with the row menu switched off it inspects on the list too. Up and down walk the lines, A presses the lit one, B
// and the stick close it, and the game's own calls for the row wait while it's up
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const done = [];
   const buttons = [];
   const key = (value, nav, code) => ({value, navEquivalent: nav, skseKeycode: code});
   const line = (name, y) => Object.assign(new freshPanel.context.MovieClip(), {what: {key: name, words: name}, _y: y, onPress: () => done.push("press " + name)});
   const context = {_visible: false};
   const open = () => Object.assign(context, {_visible: true, line3: line("favorite", 65), line0: line("equip", 4), line1: line("drop", 30)});
   freshPanel.context.gfx.io = {GameDelegate: {call: () => undefined}};
   Object.assign(Equipment.menu, {
      _platform: 1,
      _acceptControls: {}, _cancelControls: {},
      navPanel: {clearButtons: () => { buttons.length = 0; }, addButton: (data) => buttons.push(data.text), updateButtons: () => undefined},
   });
   Equipment.menu.inventoryLists.itemList = {selectedEntry: {formId: 7, text: "Iron Sword"}, selectedIndex: 3};
   Object.assign(Equipment, {panel: {}, padBuilt: true, viewer: {}, context, settings: {rowMenu: true}});
   Equipment.listsAnswer = () => true;
   Equipment.padMark = () => undefined;
   Equipment.padTurns = () => undefined;
   Equipment.openRowMenu = (entry) => { done.push("menu of " + entry.text); open(); return true; };
   Equipment.padPlaceMenu = () => undefined;
   Equipment.drawContextLine = (one, lit) => lit && done.push("lit " + one.what.key);
   Equipment.closeContext = () => { context._visible = false; done.push("closed"); };
   Equipment.padInspect = () => done.push("inspect");

   Equipment.padStick(true);
   said("a hold on a row opens its menu, the first line lit", done.join(","), "menu of Iron Sword,lit equip");
   said("the bar tells A and B", buttons.join(" | "), "Choose | Back");
   said("the lines go top to bottom", Equipment.padLines().map((one) => one.what.key).join(","), "equip,drop,favorite");
   done.length = 0;
   said("down walks the menu", Equipment.padInput(key("keyDown", "down")), true);
   Equipment.padInput(key("keyHold", "down"));
   Equipment.padInput(key("keyDown", "down"));
   Equipment.padInput(key("keyDown", "up"));
   said("down and up along the lines, the last one stays", done.join(","), "lit drop,lit favorite,lit favorite,lit drop");
   said("left keeps the category", Equipment.padInput(key("keyDown", "left")), true);
   said("the game's drop of the row waits", Equipment.padHolds(), true);
   done.length = 0;
   Equipment.padInput(key("keyDown", "enter-gamepad_A", 276));
   said("A presses the lit line", done.join(","), "press drop");
   Equipment.padInput(key("keyUp", "enter-gamepad_A", 276));
   done.length = 0;
   Equipment.padInput(key("keyDown", "tab", 277));
   said("B closes the menu", done.join(","), "closed");
   said("held it stays off the list", Equipment.padInput(key("keyHold", "tab", 277)), true);
   Equipment.padInput(key("keyUp", "tab", 277));
   said("nothing waits once it's closed", Equipment.padHolds(), false);
   open();
   done.length = 0;
   Equipment.padStick(false);
   said("the stick closes it as well", done.join(","), "closed");

   done.length = 0;
   Equipment.padFocus = {kind: "slot", column: 1, row: 0};
   Equipment.padStick(true);
   said("a hold on the panel inspects", done.join(","), "inspect");
   Equipment.padFocus = undefined;
   Equipment.settings.rowMenu = false;
   done.length = 0;
   Equipment.padStick(true);
   said("with the row menu off a hold on a row inspects", done.join(","), "inspect");

   Equipment.inspectable = () => true;
   Equipment.settings.rowMenu = true;
   buttons.length = 0;
   Equipment.padListHint();
   said("the list tells the hold for the menu", buttons.join(" | "), "Panel | Menu (hold)");
   Equipment.settings.rowMenu = false;
   buttons.length = 0;
   Equipment.padListHint();
   said("or for inspecting with the menu off", buttons.join(" | "), "Panel | Inspect (hold)");
}

// a gamepad on the sheet of the look: Y on the panel opens it with the first line under the tabs in focus, up and down
// walk its lines, left and right step a value or go to the part beside, A ticks or turns the page, B and Y close it,
// and Y is left alone where the menu has no sheet
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const done = [];
   const buttons = [];
   const key = (value, nav, code) => ({value, navEquivalent: nav, skseKeycode: code});
   freshPanel.context.gfx.io = {GameDelegate: {call: () => undefined}};
   Object.assign(Equipment.menu, {
      _platform: 1,
      _acceptControls: {}, _cancelControls: {},
      navPanel: {clearButtons: () => { buttons.length = 0; }, addButton: (data) => buttons.push(data.text), updateButtons: () => undefined},
   });
   Equipment.menu.inventoryLists.itemList = {selectedIndex: -1};
   Object.assign(Equipment, {panel: {}, padBuilt: true, settings: {}, padRing: {clear: () => undefined}});
   Equipment.padSettle = () => undefined;
   Equipment.padRingAround = () => undefined;
   Equipment.padFocus = {kind: "slot", column: 0, row: 0};
   // the open sheet holds the rows, so the list answers nothing while it's up
   Equipment.listsAnswer = () => !Equipment.look._visible;
   // the sheet as makeLook lays it out: two tabs, a tick across, a value between arrows, two ticks side by side
   const part = (name, x, y, wide, high, more) => Object.assign({_x: x, _y: y, wide, high, name, draw: (one) => one.lit && done.push("lit " + one.name)}, more);
   const sheet = {_visible: false, lines: [
      part("tab panel", 10, 10, 129, 22, {page: "panel", onPress: () => done.push("page panel")}),
      part("tab window", 145, 10, 129, 22, {page: "window", onPress: () => done.push("page window")}),
      part("doll", 10, 38, 264, 26, {key: "doll", onPress: () => done.push("tick doll")}),
      part("size", 10, 64, 264, 26, {key: "dollScale", less: {}, more: {}}),
      part("slot0", 10, 96, 128, 22, {key: "slot0", onPress: () => done.push("tick slot0")}),
      part("slot5", 142, 96, 128, 22, {key: "slot5", onPress: () => done.push("tick slot5")}),
   ]};
   Equipment.look = sheet;
   Equipment.lookButton = {_visible: true};
   Equipment.openLook = () => { sheet._visible = true; };
   Equipment.closeLook = () => { sheet._visible = false; done.push("closed"); };
   Equipment.stepLook = (name, way) => done.push("step " + name + " " + way);
   const press = (nav, code) => { const taken = Equipment.padInput(key("keyDown", nav, code)); Equipment.padInput(key("keyUp", nav, code)); return taken; };

   said("Y on the panel opens the sheet", press(undefined, 279), true);
   said("its first line under the tabs lights", done.join(","), "lit doll");
   said("the bar tells A and the way out", buttons.join(" | "), "Switch | Close");
   done.length = 0;
   press("down");
   said("down to the value", done.join(","), "lit size");
   said("its bar", buttons.join(" | "), "Change | Close");
   done.length = 0;
   press("right");
   press("left");
   said("left and right step the value", done.filter((one) => one.startsWith("step")).join(","), "step dollScale 1,step dollScale -1");
   done.length = 0;
   press("down");
   press("right");
   press("right");
   said("a line across leads down to the left column, then beside it and no further", done.join(","), "lit slot0,lit slot5");
   done.length = 0;
   press("enter-gamepad_A", 276);
   said("A ticks it", done.join(","), "tick slot5,lit slot5");
   done.length = 0;
   press("up");
   press("up");
   press("up");
   press("right");
   said("up to the tabs and along them", done.join(","), "lit size,lit doll,lit tab panel,lit tab window");
   done.length = 0;
   press("enter-gamepad_A", 276);
   said("A on a tab turns the page", done[0], "page window");
   said("its bar", buttons.join(" | "), "Open | Close");
   press("up");
   said("nothing above the tabs", Equipment.padLookAt, 1);
   done.length = 0;
   press("tab", 277);
   said("B closes the sheet", done.join(","), "closed");
   press(undefined, 279);
   done.length = 0;
   press(undefined, 279);
   said("Y closes it again", done.join(","), "closed");
   said("and it opens on the part last in focus", Equipment.padLookAt, 1);
   Equipment.lookButton._visible = false;
   said("Y is the menu's where it has no sheet", press(undefined, 279), false);

   const boxes = sheet.lines.map((one) => ({x: one._x, y: one._y, wide: one.wide, high: one.high}));
   said("down from the right tab goes to the line across", Equipment.padLookNext(boxes, 1, "down"), 2);
   said("up from the right column to the value", Equipment.padLookNext(boxes, 5, "up"), 3);
   said("nothing under the last line", Equipment.padLookNext(boxes, 4, "down"), undefined);
   said("nothing beside a line across", Equipment.padLookNext(boxes, 2, "left"), undefined);
}

// a gamepad in a chest or a shop: no panel there, a hold of the stick on a row opens its menu, the stick closes it, a
// click zooms the game's way and so does any press while that zoom is in. The bar tells Menu (hold) without Panel. The
// zoom key is the pad's there, the keyboard's stays the game's, and the game's zoom leaves the chest's mouse area as it was
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const done = [];
   const buttons = [];
   const context = {_visible: false};
   let zoomed = false;
   freshPanel.context.gfx.io = {GameDelegate: {call: () => undefined}};
   Object.assign(Equipment.menu, {
      _platform: 1,
      navPanel: {clearButtons: () => { buttons.length = 0; }, addButton: (data) => buttons.push(data.text), updateButtons: () => undefined},
      mouseRotationRect: {_xscale: 100, _yscale: 100},
   });
   Equipment.menu.inventoryLists.itemList = {selectedEntry: {formId: 7, text: "Iron Sword"}, selectedIndex: 3};
   Object.assign(Equipment, {padBuilt: true, context, settings: {rowMenu: true}});
   Equipment.plugin = () => ({Zoomed: () => zoomed, GameZoom: () => { zoomed = !zoomed; done.push("zoom " + (zoomed ? "in" : "out")); return true; }});
   Equipment.listsAnswer = () => true;
   Equipment.padRowMenu = (entry) => { if(entry == undefined) return false; done.push("menu of " + entry.text); context._visible = true; return true; };
   Equipment.closeContext = () => { context._visible = false; done.push("closed"); };

   Equipment.padStick(false);
   Equipment.padStick(true);
   Equipment.padStick(true);
   Equipment.padStick(false);
   said("a click zooms, any press zooms back, a hold opens the menu, the stick closes it", done.join(","), "zoom in,zoom out,menu of Iron Sword,closed");
   done.length = 0;
   Equipment.padStick(true);
   Equipment.padStick(false);
   Equipment.settings.rowMenu = false;
   Equipment.padStick(true);
   Equipment.padStick(false);
   Equipment.settings.rowMenu = true;
   Equipment.menu.inventoryLists.itemList.selectedEntry = undefined;
   Equipment.padStick(true);
   said("a hold with the row menu off or no row is a click", done.join(","), "menu of Iron Sword,closed,zoom in,zoom out,zoom in");
   Equipment.menu.inventoryLists.itemList.selectedEntry = {formId: 7};
   Equipment.inspectable = () => true;
   Equipment.padListHint();
   said("the bar tells the hold for the menu and no panel", buttons.join(" | "), "Menu (hold)");
   said("the zoom key is the pad's in a chest", Equipment.zoomKey(), true);
   Equipment.menu._platform = 0;
   said("and the keyboard's stays the game's", Equipment.zoomKey(), false);
   Equipment.gameZoom(false);
   said("the game's zoom leaves the chest's area for the mouse", Equipment.menu.mouseRotationRect._xscale, 100);
}

// the right stick scrolls the cut words a line a step as the plugin tells, up for the lines above, within the words, and
// they stop moving by themselves for that item. Nothing while inspecting, on the keyboard or with nothing cut
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const field = {scroll: 1, maxscroll: 6, _visible: true};
   Equipment.padBuilt = true;
   Equipment.menu._platform = 1;
   Equipment.menu.itemCard = {_parent: {_visible: true}};
   Equipment.wordsCut = {field, held: false};
   Equipment.drawWordsBar = () => undefined;
   // the browser of Know your Skyrim lives in its own mod, here it holds the stick or not
   let browserHolds = true;
   Equipment.browserTakesStick = () => browserHolds;
   Equipment.padWords(-2);
   said("the browser's page takes the stick while it holds the input", field.scroll, 1);
   browserHolds = false;
   Equipment.padWords(-2);
   said("down brings the lines under", field.scroll, 3);
   said("and holds them", Equipment.wordsCut.held, true);
   Equipment.padWords(-9);
   said("no further than the last", field.scroll, 6);
   Equipment.padWords(1);
   Equipment.padWords(9);
   said("up to the first", field.scroll, 1);
   Equipment.inspecting = true;
   Equipment.padWords(-1);
   Equipment.inspecting = false;
   Equipment.menu._platform = 0;
   Equipment.padWords(-1);
   said("not while inspecting nor on the keyboard", field.scroll, 1);
   Equipment.menu._platform = 1;
   Equipment.wordsCut = undefined;
   Equipment.padWords(-1);
   said("nothing cut, nothing moves", field.scroll, 1);
}

// A chest's card: under a description the numbers and quiet lines get a gap, the quest line read as
// the description's next line
{
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const Equipment = freshPanel();
   const card = {localToGlobal: () => undefined, globalToLocal: () => undefined};
   card.background = {};
   Equipment.menu.itemCard = card;
   const field = (y, high, wraps) => ({_x: 0, _y: y, textHeight: high, text: "words", wordWrap: wraps});
   Equipment.shownParts = () => [card.background, field(75, 37, false), field(115, 23, true)];
   said("the description's bottom", Equipment.cardWordsBottom(0, card), 115 + 23 + 4);
   said("is a paragraph", Equipment.cardWordsWrap, true);
   Equipment.shownParts = () => [card.background, field(115, 23, true), field(150, 37, false)];
   Equipment.cardWordsBottom(0, card);
   said("numbers under it are no paragraph", Equipment.cardWordsWrap, false);
}

// the inventory's list widens over its first frames, the strip is laid again once it stands and only then
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   let shown = 0;
   let wide = 443;
   Equipment.chips = {};
   Equipment.stripMeasured = 443;
   Equipment.stripCentred = false;
   Equipment.stripSeen = undefined;
   Equipment.stripRoom = () => ({left: 0, right: wide});
   Equipment.labelCentred = () => false;
   Equipment.showChips = () => { shown++; Equipment.stripMeasured = wide; };
   for (const step of [443, 459, 475, 490, 506, 521, 537, 546, 546, 546, 546, 546, 546]) {
      wide = step;
      Equipment.followStrip();
   }
   said("a list that widens gets its strip laid once", shown, 1);
   said("at the width it stands at", Equipment.stripMeasured, 546);
}

// ALL has one subcategory, the rows marked as junk, while the junk of the mod is on
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   said("ALL is a family of its own", Equipment.chipFamily(Equipment.FLAG_ALL), "all");
   said("and so is a chest's ALL", Equipment.chipFamily(Equipment.FLAG_ALL << 10), "all");
   Equipment.settings = {junk: true};
   said("its chip is Junk", Equipment.chipRowsOf("all")[0][0].key, "junk");
   said("a row marked as junk passes", Equipment.chipHolds("junk", {equipmentJunk: true}), true);
   said("another doesn't", Equipment.chipHolds("junk", {}), false);
   Equipment.settings.junk = false;
   said("with the junk off ALL has no chips", Equipment.chipRowsOf("all"), undefined);
}

// Long words keep their letters: a card or a window with no more room keeps whole lines of them, never under three, the
// parts under them move up and come back down, the wheel over them moves them a line a notch
{
   const Equipment = freshPanel(false);
   const context = freshPanel.context;
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const drawn = () => ({clear() {}, beginFill() {}, endFill() {}, moveTo() {}, lineTo() {}, curveTo() {}});
   const holder = {_visible: true, _yscale: 100, getNextHighestDepth: () => 1, createEmptyMovieClip: (name) => (holder[name] = drawn())};
   const card = {_parent: holder, _yscale: 100, background: {_name: "background"}, getNextHighestDepth: () => 1, localToGlobal() {}, globalToLocal() {},
      createEmptyMovieClip: (name) => (card[name] = drawn())};
   const words = new context.TextField();
   Object.assign(words, {_name: "words", _parent: card, _visible: true, _alpha: 100, _x: 10, _y: 100, _width: 300, _height: 304, wordWrap: true, text: "long", textHeight: 300, numLines: 20, scroll: 1});
   Object.defineProperty(words, "bottomScroll", {get() { return this.scroll + Math.floor((this._height - 4) / 15) - 1; }});
   Object.defineProperty(words, "maxscroll", {get() { return this.numLines - Math.floor((this._height - 4) / 15) + 1; }});
   const numbers = {_name: "numbers", _parent: card, _visible: true, _alpha: 100, _x: 10, _y: 420, _width: 300, _height: 20, text: "DPS"};
   card.words = words;
   card.numbers = numbers;
   Equipment.menu.itemCard = card;
   said("the words give whole lines", Equipment.cutWords(100), 105);
   said("and keep 13 of 20", words._height, 199);
   said("what lies under them moves up", numbers._y, 315);
   said("the cut field is known", Equipment.cutField(), words);
   context._root._xmouse = 50;
   context._root._ymouse = 150;
   said("the wheel over the words is theirs", Equipment.scrollWords(-1), true);
   said("a line a notch", words.scroll, 2);
   context._root._xmouse = 500;
   said("the wheel beside them isn't", Equipment.scrollWords(-1), false);
   Equipment.uncutWords();
   said("the words get their height back", words._height, 304);
   said("from the top", words.scroll, 1);
   said("and what moved goes back", numbers._y, 420);
   said("nothing stays cut", Equipment.cutField(), undefined);
   Equipment.cutWords(1000);
   said("never under three lines", words._height, 49);
   Equipment.uncutWords();
   // SkyUI's box taller than the words (16:10): the lines go by the words, the layouts measure those
   words._height = 340;
   numbers._y = 450;
   Equipment.cutWords(100);
   said("a box taller than its words gives what the words have to", words._height, 199);
   said("and moves what lies under the box by all it gave", numbers._y, 450 - 141);
   Equipment.uncutWords();
   said("the tall box comes back", words._height + "," + numbers._y, "340,450");
   words.numLines = 3;
   said("three lines are never cut", Equipment.cutWords(100), 0);
}

// SkyUI draws the enchantment of a weapon smaller to fit its box (textAutoSize shrink). The words keep their size: a
// chest's card grows the box, the window makes room past it, a card at home keeps SkyUI's way, all goes back after
{
   const Equipment = freshPanel(false);
   const context = freshPanel.context;
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const card = {ItemText: {}};
   context.TextFormat = function() {};
   const words = new context.TextField();
   Object.assign(words, {_name: "WeaponEnchantedLabel", _parent: card, _visible: true, _alpha: 100, _height: 60, wordWrap: true, text: "long", textHeight: 200, textAutoSize: "shrink",
      getTextFormat: () => ({size: 20}), setTextFormat() {}});
   card.WeaponEnchantedLabel = words;
   Equipment.menu.itemCard = card;
   Equipment.shownParts = () => [];
   Equipment.sizeCardText(false);
   said("a chest's card takes its words at their size", words.textAutoSize, "none");
   said("and grows their box", words._height, 204);
   Equipment.unsizeCardText();
   said("then SkyUI's way comes back", words.textAutoSize + "," + words._height, "shrink,60");
   Equipment.sizeCardText(true);
   said("the window leaves the box to fitOverflow", words.textAutoSize, "none");
   Equipment.unsizeCardText();
   Equipment.leftCard = true;
   Equipment.cardInRoom = () => false;
   Equipment.sizeCardText(false);
   said("a card at home keeps SkyUI's way", words.textAutoSize + "," + words._height, "shrink,60");
}

// The window takes at most the height from the rows' top to the bottom bar with the least part of its model, the words
// give what the card needs past that, in the card's units
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   let asked;
   Equipment.menu.itemCard = {_yscale: 100, _parent: {_yscale: 50}};
   Equipment.frame = {top: 40};
   Equipment.rowsTop = () => 90;
   Equipment.underCard = (above) => above ? 30 : 10;
   Equipment.cutWords = (by) => (asked = by, 7);
   Equipment.cutWindowWords(600, undefined, 700);
   said("over its row it cuts what passes the rows' top", asked, (95 + 600 + 20 - 610) / 0.5);
   asked = undefined;
   Equipment.cutWindowWords(400, undefined, 700);
   said("a card that fits keeps its words", asked, undefined);
   Equipment.cutWindowWords(600, {}, 700);
   said("beside a slot it has the whole screen and the model's full part", asked, (130 + 600 - 660) / 0.5);
}

// A chest's card gone up over the game's model sends the model up into the room above it, smaller if it has to be. A
// card at its place has the model where the game puts it, asked for again. A card beside the model, the inventory and
// a follower's trade leave it alone
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   let placed;
   let back = 0;
   let asked = 0;
   let box = {xMin: 760, xMax: 1100, yMin: 300, yMax: 650};
   Equipment.plugin = () => ({PreviewSpot: () => [0.75, 0.33, 0.45], PlacePreview: (...told) => { placed = told; }, PreviewBack: () => back++});
   Equipment.askModelAgain = () => asked++;
   const card = {background: {getBounds: () => box}};
   Equipment.kind = "container";
   Equipment.menu.bNPCMode = false;
   Equipment.cardRaised = true;
   Equipment.placeShopModel(card);
   said("the model goes over the card, in its column", placed && placed[0], 0.75);
   said("in the middle of the room above it", Math.round(placed[1] * 720), 150);
   said("smaller to fit", Math.round(placed[2] * 720), 284);
   said("at most the game's size", placed[5], 1);
   Equipment.cardRaised = false;
   Equipment.placeShopModel(card);
   said("a card at its place gives it back to the game, the models up go along", back + "," + asked, "1,0");
   Equipment.placeShopModel(card);
   said("only once", back, 1);
   box = {xMin: 100, xMax: 500, yMin: 300, yMax: 650};
   said("a card beside the model is under nothing", Equipment.modelOverCard(card), undefined);
   box = {xMin: 760, xMax: 1100, yMin: 300, yMax: 650};
   said("a card under it across", Equipment.modelOverCard(card) != undefined, true);
   Equipment.menu.bNPCMode = true;
   said("a pickpocket, an NPC's trade to the game, keeps the card's model over it", Equipment.modelOverCard(card) != undefined, true);
   Equipment.subject = {player: false};
   said("a follower's trade has its window", Equipment.modelOverCard(card), undefined);
   Equipment.subject = undefined;
   Equipment.kind = "inventory";
   Equipment.menu.bNPCMode = false;
   said("the inventory keeps its room", Equipment.shopCard(), false);
}

// A list with no height of its own (Nordic UI's chest and shop, no background to measure) gives up rows for the strip,
// the height it got before was NaN and no row showed
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   const list = {_y: 180, listHeight: undefined, entryHeight: 24, _maxListIndex: 20, requestUpdate() {}};
   Equipment.menu.inventoryLists.itemList = list;
   Equipment.menu.updateDynamicListHeight = undefined;
   Equipment.holdBackdrops = () => undefined;
   Equipment.roomHigh = 0;
   Equipment.openStrip(true, 1);
   said("the strip takes a row of the list", list._maxListIndex, 19);
   said("its height stays as it was", list.listHeight, undefined);
   Equipment.openStrip(false);
   said("and gives it back", list._maxListIndex, 20);
}

// A part that stands whole kind lines lower than its home after a card change goes home before the line comes in
{
   const Equipment = freshPanel(false);
   const said = (name, got, wanted) => got === wanted ? passed++ : (failed++, console.log(`FAIL ${name}: got "${got}", wanted "${wanted}"`));
   said("two lines down", Equipment.linesDown(52, 26), true);
   said("one line down", Equipment.linesDown(26, 26), true);
   said("at home", Equipment.linesDown(0, 26), false);
   said("moved by the skin elsewhere", Equipment.linesDown(40, 26), false);
   said("up is never ours", Equipment.linesDown(-26, 26), false);
}

if (withCalls) {
   failed += withCalls.report();
}

console.log(`${passed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);

