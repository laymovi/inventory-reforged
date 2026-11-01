Equipment.WINDOW_SHARE = 0.48;
// the least the window takes as a share of the screen's height, the most as a share of the list
Equipment.WINDOW_LEAST = 0.4;
Equipment.WINDOW_MOST = 0.8;
// The value on SkyUI's card is 30 high on a frame 428 wide, Norden UI's and Vel'dun UI's 24, Dragonborn UI's 20 on 574:
// fitted into the window its words came out half SkyUI's size. Under SMALL_WORDS of SkyUI's share the window widens
Equipment.CARD_WORDS_SHARE = 30 / 428;
Equipment.SMALL_WORDS = 0.7;
Equipment.WINDOW_INSET = 19;
Equipment.WINDOW_GAP = 4;
Equipment.WINDOW_PAD = 8;
Equipment.PREVIEW_HEIGHT = 130;
// the shorter lists of Nordic UI and Dear Diary, kept clear of their categories, left the model 50 high at 70. Short
// of this a window lies over its own row
Equipment.PREVIEW_LEAST = 95;
Equipment.CARD_PAD = 14;
// in the units of the card, which the window shows at about two thirds
Equipment.KIND_LINE = 26;
Equipment.KIND_TEXT = 19;
Equipment.FIT_SLACK = 0.5;
Equipment.WATCH_FRAMES = 600;
Equipment.POPUP_GAP = 10;
Equipment.STATS_PAD = 12;
Equipment.STATS_TEXT = 13;
Equipment.ACTION_HIGH = 26;
Equipment.ACTION_GAP = 6;
// a slot window's buttons stand clear of the frame's bottom edge and its ornaments
Equipment.ACTION_EDGE = 14;
Equipment.ACTION_ICON = 14;
Equipment.LENS_AIM_MS = 300;
Equipment.LENS_AIM_SLACK = 6;

// SkyUI makes a long text of a card smaller until it fits its place, unless the place may grow first
// (Shared.GlobalFunc.ApplyTextOverflow with maxHeightExpand). A text of several lines grows to its whole length and keeps
// its letters, the window or the card then keeps the lines it has room for and the rest scrolls (36-long-words.as).
// A field of one line, a number or a label, keeps shrinking: grown with the rest a wide number broke onto a second line
// and stood out of line with its label. A card at home (the UI's own card, one left for the skin) keeps SkyUI's way, its
// frame doesn't grow: a long description ran past the frame over the bottom bar
Equipment.growLongText = function()
{
   var helper = _global.Shared.GlobalFunc;
   var original;
   var grows;
   if(helper == undefined || typeof helper.ApplyTextOverflow != "function" || helper.ApplyTextOverflow.equipmentGrows == true)
   {
      return undefined;
   }
   original = helper.ApplyTextOverflow;
   grows = function(field)
   {
      var high;
      if(field != undefined)
      {
         if(field.equipmentOwnKept != true)
         {
            field.equipmentOwnExpand = field.maxHeightExpand;
            field.equipmentOwnKept = true;
         }
         high = field.origHeight != undefined ? field.origHeight : field._height;
         // the card in the character's room grows its frame down with its numbers, it isn't one of those
         field.maxHeightExpand = Equipment.leavesCard() && !Equipment.cardInRoom() ? field.equipmentOwnExpand : (high >= 2 * Equipment.number(field.getTextFormat().size) ? Equipment.WORDS_ALL : 0);
      }
      return arguments.callee.original.apply(this, arguments);
   };
   grows.original = original;
   grows.equipmentGrows = true;
   helper.ApplyTextOverflow = grows;
};

// The words of the window at the sizes the player set on the Item window page, a share of their own size. part is
// "name", "words" (the card's effects, enchantments and descriptions), "numbers" or "quiet"
Equipment.textShare = function(part)
{
   var settings = Equipment.settings;
   var size = settings != undefined ? Equipment.number(settings[part + "Text"]) : 0;
   return size >= 50 && size <= 300 ? size / 100 : 1;
};

// The item window is the SkyUI item card with the model of the item above it and the numbers of the panel under it.
// Opened from a row it pops up over the right half of the list, under the selected row or above it when there's no
// room below, and takes no mouse so the rows under it keep working. Opened from a slot it stands beside the slot,
// holds buttons, and a click anywhere else closes it. A crafting station asks for it at once, its card has no other
// place to go there
Equipment.buildWindow = function(atOnce)
{
   var menu = Equipment.menu;
   var lists = menu.inventoryLists;
   var card = menu.itemCard._parent;
   var sheet = Equipment.under.createEmptyMovieClip("equipmentWindowSheet", Equipment.under.getNextHighestDepth());
   var window;
   Equipment.openedPopUp = atOnce == true ? Equipment.WINDOW_AT_ONCE : Equipment.number(Equipment.settings.windowShow);
   Equipment.ownCard = Equipment.openedPopUp == Equipment.WINDOW_OWN_CARD;
   // the UI's own card says where the card goes first, the card's own switch counts without it. The character
   // switched off is only the model gone, the card goes where these two say
   Equipment.leftCard = atOnce != true && Equipment.settings.leaveCard == true && !Equipment.ownCard;
   Equipment.cardScaleAtOpen = Equipment.cardScaleInMenu();
   Equipment.ownCardOverDoll = Equipment.ownCard && Equipment.cardOverDoll();
   Equipment.leftOverDoll = Equipment.leftCard && Equipment.cardOverDoll();

   // The window's sheet lies under the card, the card over it wears its own frame grown to the window, the
   // window's words lie over that frame, and what the panel opens later lies over all of them
   card.swapDepths(menu.getNextHighestDepth());
   Equipment.windowLayer = menu.createEmptyMovieClip("equipmentWindowLayer", menu.getNextHighestDepth());
   Equipment.windowLayer._xscale = 100 / Equipment.squash;
   Equipment.over.swapDepths(menu.getNextHighestDepth());
   window = Equipment.windowLayer.createEmptyMovieClip("equipmentWindow", 1);
   Equipment.window = window;
   window.sheet = sheet;
   sheet._visible = false;
   sheet.hitTestDisable = true;
   window._visible = false;
   window.hitTestDisable = true;
   window.back = sheet;
   window.createTextField("touch", 1, 0, 0, 10, 10);
   window.touch.selectable = false;
   Equipment.sizeWindow();
   Equipment.buildStats(window);
   Equipment.buildMadeOf(window);
   Equipment.windowWanted = false;
   Equipment.cardKept = false;
   Equipment.watched = 0;
   Equipment.panel.onEnterFrame = Equipment.watchCard;

   Equipment.growLongText();
   Equipment.startLongWords();

   // the game sizes a model when it puts it up, so the size has to be told before the first row is selected
   window._x = window.left;
   window._y = Equipment.frame.top;
   Equipment.aimPreview();

   // The model in the window is too small to be turned by hand, and the rows under it have to stay in
   // reach. It's turned in the inspect view
   menu.mouseRotationRect._xscale = menu.mouseRotationRect._yscale = 0;

   Equipment.reachCard({opening:false});
   menu.itemCard.addEventListener("subMenuAction", Equipment, "reachCard");
   lists.addEventListener("itemHighlightChange", Equipment, "onHighlight");
   lists.addEventListener("showItemsList", Equipment, "onHighlight");
   lists.addEventListener("hideItemsList", Equipment, "onHighlight");
   lists.itemList.addEventListener("selectionChange", Equipment, "rowChosen");
   Equipment.aimForLens();

   // the card is filled after the row is selected, and a list that scrolls moves the selected row. Several effects
   // of an enchantment each get a line of their own
   Equipment.windowFollowsCardInfo(menu);
   Equipment.watchCardInfo(menu.itemCard, Equipment.cardRefilled);
   Equipment.holdModels();
   lists.itemList.equipmentUpdateList = lists.itemList.UpdateList;
   lists.itemList.UpdateList = function()
   {
      // SkyUI selects the row under the pointer here, a row the pointer crosses on its way to the lens waits, and so does
      // any row while the window of Details stands
      var mouseDriven = this.isMouseDrivenNav;
      if(Equipment.lensWait != undefined || Equipment.headsForLens() || Equipment.pinHolds())
      {
         this.isMouseDrivenNav = false;
      }
      this.equipmentUpdateList();
      this.isMouseDrivenNav = mouseDriven;
      Equipment.showRowModels();
      Equipment.keepApart();
      Equipment.listMoving = true;
      Equipment.showWindow();
      Equipment.listMoving = false;
   };
};

// a call that comes back into this one while it runs leaves the card filling until the outer one is done
Equipment.windowFollowsCardInfo = function(menu)
{
   menu.equipmentUpdateItemCardInfo = menu.UpdateItemCardInfo;
   menu.UpdateItemCardInfo = function(info)
   {
      var filling = Equipment.fillingCard == true;
      if(info != undefined && info.effects != undefined && !Equipment.cardFitsByHand() && !Equipment.leavesCard())
      {
         info.effects = Equipment.effectLines(info.effects);
      }
      Equipment.fillingCard = true;
      Equipment.cardInfoUnder(this, "equipmentUpdateItemCardInfo", info);
      Equipment.fillingCard = filling;
      Equipment.cardStamp = Equipment.number(Equipment.cardStamp) + 1;
      Equipment.showWindow();
   };
};

// The game puts up the model of a row the moment the row is selected and draws it a frame before the panel hides it
// again. A window that waits for a pause or never comes flashed the model over the list as the pointer went along
// the rows. Until a window is up for the selected row its model isn't asked for, the window asks when it comes up.
// A slot's window and the question of how many ask for it at once
Equipment.holdModels = function()
{
   var delegate = gfx.io.GameDelegate;
   if(delegate.equipmentCall != undefined)
   {
      return undefined;
   }
   delegate.equipmentCall = delegate.call;
   delegate.call = function(name, args)
   {
      if(name == "UpdateItem3D" && args[0] == true && Equipment.holdsModel())
      {
         Equipment.modelHeld = true;
         Equipment.modelsHeld = Equipment.number(Equipment.modelsHeld) + 1;
         return undefined;
      }
      if(name == "UpdateItem3D")
      {
         Equipment.modelHeld = false;
         Equipment.modelFor = args[0] == true ? Equipment.menu.inventoryLists.itemList.selectedIndex : undefined;
      }
      return gfx.io.GameDelegate.equipmentCall.apply(gfx.io.GameDelegate, arguments);
   };
};

Equipment.holdsModel = function()
{
   var list = Equipment.menu.inventoryLists.itemList;
   var shownFor = Equipment.window._visible && Equipment.modelFor == list.selectedIndex;
   var waits = Equipment.detailsOnly() || !Equipment.ownCardNow() && Equipment.popUpNow() != Equipment.WINDOW_AT_ONCE;
   return waits && Equipment.anchorSlot == undefined && !Equipment.cardAsking && !shownFor;
};

// The UI's own card over the character shows the card where SkyUI puts it, but the game is never asked for the model of
// a row there, the way a window that waits for a pause holds it back. The window of Details asks for it, and lets it go
// again when it goes. Read as the menu opens
Equipment.detailsOnly = function()
{
   return Equipment.ownCardOverDoll == true && Equipment.cardBorrowed != true;
};

// the window came up over a row whose model was held back
Equipment.askModel = function()
{
   var list = Equipment.menu.inventoryLists.itemList;
   if(!Equipment.modelHeld || !Equipment.window._visible || list.selectedIndex < 0)
   {
      return undefined;
   }
   Equipment.modelHeld = false;
   Equipment.modelFor = list.selectedIndex;
   Equipment.modelsAsked = Equipment.number(Equipment.modelsAsked) + 1;
   gfx.io.GameDelegate.equipmentCall("UpdateItem3D", [true]);
};

// for tests, how many models of rows were held back and asked for later
Equipment.modelReport = function(note)
{
   skse.Log("PANELTEST models " + note + ": held " + Equipment.number(Equipment.modelsHeld) + ", asked by the window " + Equipment.number(Equipment.modelsAsked) + ", one held now " + (Equipment.modelHeld == true) + ", window " + Equipment.window._visible + ", selected " + Equipment.menu.inventoryLists.itemList.selectedIndex);
};

// How wide the window is in its own units, the skin's units over a row. It takes its share of the list at the
// list's full width, so a narrowed list keeps a card that reads, and never less than its share of the screen's
// height, so does a narrow list of a skin or a menu drawn small on a big screen. The size the player chose goes on
// top of that, up to the most of the list that leaves the names of the rows in sight
Equipment.windowWideFor = function(listWide, screenHigh, size, squash)
{
   var wide = Math.max(listWide * Equipment.WINDOW_SHARE, screenHigh * Equipment.WINDOW_LEAST) * size / 100;
   return Math.round(Math.min(wide, listWide * Equipment.WINDOW_MOST) / squash);
};

// The UI's own card as the menu opened with it. A switch to it or from it on the look sheet waits for the next opening
// whole: the window going at once while the card still sat in it left no card anywhere and the model in the game's
// spot over the list. Details of a row's menu borrows the card and the model for the window it brings up
Equipment.ownCardNow = function()
{
   return (Equipment.ownCard == true || Equipment.leftCard == true) && Equipment.cardBorrowed != true;
};

// The card with the numbers in it stands in the character's room, raised into it when long, its model above it: the
// card left in the UI's place where the UI puts it over the character (plain SkyUI)
Equipment.cardInRoom = function()
{
   return Equipment.leftOverDoll == true;
};

// Pops up as it works now: on hover and after a pause swap at once, the UI's own card only as a menu opens
Equipment.popUpNow = function()
{
   var show = Equipment.settings != undefined ? Equipment.number(Equipment.settings.windowShow) : Equipment.WINDOW_AT_ONCE;
   return Equipment.ownCard == true || show == Equipment.WINDOW_OWN_CARD ? Equipment.number(Equipment.openedPopUp) : show;
};

// The card left in the UI's place ([Window] bLeaveCard, on the look sheet and in the menu of the mod) stays where and as
// SkyUI or the skin draws it, with the mod's numbers in it and the item's model at home, and no window comes over the
// rows, the window with the model alone looked cut off. The UI's own card leaves the card too. Both are read once when
// the menu opens. The window of Details or of a slot takes the card and the model along for as long as it stands
Equipment.leavesCard = function()
{
   return (Equipment.leftCard == true || Equipment.ownCard == true) && Equipment.cardBorrowed != true;
};

// the card fills the width of the window and its words grow with it
Equipment.sizeWindow = function()
{
   var window = Equipment.window;
   var card = Equipment.menu.itemCard._parent;
   var list = Equipment.rowsEdge().wide;
   var size = Equipment.number(Equipment.settings.windowSize);
   var cardWide = Equipment.cardWidth();
   var share = Equipment.wordsShare;
   window.wide = Equipment.windowWideFor(list, Stage.visibleRect.height, size > 0 ? size : 100, Equipment.squash);
   // A card whose words are small for its frame gets a window as much wider, as far as the most of the list a window
   // takes. SkyUI, Edge, Nordic and the like keep theirs
   if(share > 0 && share < Equipment.CARD_WORDS_SHARE * Equipment.SMALL_WORDS)
   {
      window.wide = Math.round(Math.min(window.wide * Equipment.CARD_WORDS_SHARE / share, list * Equipment.WINDOW_MOST / Equipment.squash));
   }
   // a card with no width yet would get an endless scale and stay out of sight for the whole menu
   if(!Equipment.leavesCard() && cardWide > 0)
   {
      card._yscale = window.wide / cardWide * 100;
   }
   Equipment.windowUnits(Equipment.squash);
   Equipment.placeWindowLeft();
   if(window.bodySlots != undefined)
   {
      window.bodySlots._width = window.wide - 2 * Equipment.STATS_PAD - Equipment.LENS_SIZE;
   }
};

Equipment.placeWindowLeft = function()
{
   var window = Equipment.window;
   window.left = Equipment.rowsEdge().right - (Equipment.WINDOW_INSET + window.wide) * Equipment.squash;
};

// Over a row the window and the card in it take the proportions of the list they lie over, the skin's own words
// are drawn so. Beside a slot they're square like the rest of the panel. across is how wide the window's unit is in
// the panel's units, the squash of the menu over a row and 1 beside a slot
Equipment.windowUnits = function(across)
{
   var window = Equipment.window;
   var card = Equipment.menu.itemCard._parent;
   window.across = across;
   window._xscale = across * 100;
   if(!Equipment.leavesCard())
   {
      card._xscale = card._yscale * across / Equipment.squash;
   }
};

// How high the value on the card is for the width of its frame, at the card's own size before the panel grew its
// words. Nothing while no value is on the card
Equipment.cardWordsShare = function()
{
   var card = Equipment.menu.itemCard;
   var field = card.ItemValueText;
   var frame = Equipment.frameBox(card);
   var format;
   if(!(field instanceof TextField) || frame == undefined || !(frame.xMax - frame.xMin > 0) || field.text == "")
   {
      return undefined;
   }
   format = field.getTextFormat(0, 1);
   return Equipment.ownSize(field, format) * field._yscale / 100 / (frame.xMax - frame.xMin);
};

// how wide the window is in the panel's units
Equipment.windowWide = function()
{
   var window = Equipment.window;
   return window.wide * (window.across != undefined ? window.across : 1);
};

// what the window shows: the item of the slot it was opened from, the selected row otherwise
Equipment.windowEntry = function()
{
   return Equipment.anchorSlot != undefined ? Equipment.anchorSlot.entries[0] : Equipment.menu.inventoryLists.itemList.selectedEntry;
};

// Every kind of card is laid out inside the frame of the card, which has the same width for all of them.
// The holder of the card can be wider than that when another mod has put something of its own into the
// card. Menus built on SkyUI may place the card in its holder at a size of their own, Vel'dun UI does at
// 85%
Equipment.cardWidth = function()
{
   var card = Equipment.menu.itemCard;
   var holder = card._parent;
   var frame = Equipment.frameBox(card);
   return frame != undefined ? (frame.xMax - frame.xMin) * card._xscale / 100 : holder._width * 100 / holder._xscale;
};

// The frame of the card as a viewer sees it, the card itself when none is named, nothing while it has no size.
// A frame drawn out past the card's left edge has that much clear margin on every side, a shadow or the see-through
// edge of a picture: Dear Diary loads a paper 468 wide from 20 left and above the card, the paper itself is 428 like
// SkyUI's frame. A frame drawn round its own middle starts left of the card by half its width, that's no margin
Equipment.frameBox = function(card, viewer)
{
   var frame = card.background;
   var box;
   var margin;
   var from;
   var to;
   if(frame == undefined || !(frame._width > 0))
   {
      return undefined;
   }
   box = frame.getBounds(card);
   margin = Math.max(0, -box.xMin);
   if(!(box.xMax - box.xMin - 2 * margin > 1))
   {
      margin = 0;
   }
   from = {x:box.xMin + margin, y:box.yMin + margin};
   to = {x:box.xMax - margin, y:box.yMax - margin};
   if(viewer != undefined && viewer != card)
   {
      card.localToGlobal(from);
      card.localToGlobal(to);
      viewer.globalToLocal(from);
      viewer.globalToLocal(to);
   }
   return {xMin:from.x, yMin:from.y, xMax:to.x, yMax:to.y};
};

// moreHUD Inventory Edition swaps the card of enchanted things, potions, food and books for a wider one.
// It draws that card beside the SkyUI one, at the size and the place the SkyUI card has in a plain menu,
// and stretches the text of the SkyUI card over it. In the item window that card hangs out on both sides.
// The swap is one function of the clip moreHUD loads into the menu, called for every new card. On that
// clip it's replaced by one that tells moreHUD the card was left alone, so moreHUD hides its own card and
// gives the SkyUI one back its look. Its icons on the card are another function and stay. Tells whether
// the clip of moreHUD is in hand
Equipment.keepCard = function()
{
   var other;
   if(Equipment.cardKept)
   {
      return true;
   }
   other = Equipment.otherCard();
   if(other == undefined)
   {
      return false;
   }
   Equipment.cardKept = true;
   if(other._itemCardOverride == true)
   {
      Equipment.remakeCard();
   }
   other.AdjustItemCard = function()
   {
      this._itemCardOverride = false;
   };
   other.AdjustItemCard();
   other._alpha = 0;
   return true;
};

// A card moreHUD has swapped already keeps the stretched text until its kind changes. Going over
// the empty card and back makes the SkyUI card lay the text out anew
Equipment.remakeCard = function()
{
   var card = Equipment.menu.itemCard;
   var info = card.itemInfo;
   card.gotoAndStop("Empty");
   Equipment.fillingCard = true;
   card.itemInfo = info;
   Equipment.fillingCard = false;
};

// Mods fill the card again on their own after the menu did. Description Framework puts its text into the card's info
// a frame later and hands the info to the card once more, past the menu's call. SkyUI lays the card out anew then,
// the kind line, the hidden corner word and the window's size went back to the card without the text, and the text
// lay over the window's numbers. Any new info the card gets lays the window out again, in a chest or a shop the card's
// numbers (refilled)
Equipment.watchCardInfo = function(card, refilled)
{
   var setter = card.__set__itemInfo;
   if(typeof setter != "function" || card.equipmentSetInfo != undefined || card.addProperty == undefined)
   {
      return undefined;
   }
   card.equipmentSetInfo = setter;
   card.equipmentRefilled = refilled;
   card.addProperty("itemInfo", card.__get__itemInfo, function(info)
   {
      this.equipmentSetInfo(info);
      if(!Equipment.fillingCard)
      {
         this.equipmentRefilled();
      }
   });
};

Equipment.cardRefilled = function()
{
   Equipment.cardStamp = Equipment.number(Equipment.cardStamp) + 1;
   Equipment.showWindow();
   Equipment.cardNumbersLater();
};

// moreHUD loads its clip some frames into the menu and swaps the first card it meets after that. So
// the clip is looked for on every frame from the start, for as long as a slow load can take
Equipment.watchCard = function()
{
   Equipment.watched++;
   Equipment.everyFrame();
   if(Equipment.cardKept || Equipment.watched >= Equipment.WATCH_FRAMES)
   {
      return undefined;
   }
   if(Equipment.keepCard())
   {
      Equipment.showWindow();
   }
};

// The card takes the mouse only while it asks how many to drop or whether to go on. When a question
// is called off the card tells of it first and goes back to the item after that, so the window is
// measured once more when the card has settled
Equipment.reachCard = function(event)
{
   Equipment.menu.itemCard._parent.hitTestDisable = !event.opening;
   // the window lies over the card, the card's question takes the mouse through it
   Equipment.window.hitTestDisable = event.opening == true || Equipment.anchorSlot == undefined;
   // only a question of the card itself, the call at the start has none
   if(event.menu != undefined)
   {
      Equipment.cardAsking = event.opening == true;
      Equipment.holdRows(Equipment.cardAsking);
   }
   Equipment.showWindow();
   if(!event.opening && Equipment.settling == undefined)
   {
      Equipment.settling = setInterval(Equipment.cardSettled, 1);
   }
};

Equipment.cardSettled = function()
{
   clearInterval(Equipment.settling);
   delete Equipment.settling;
   Equipment.showWindow();
};

Equipment.onHighlight = function(event)
{
   var selected = Equipment.menu.inventoryLists.itemList.selectedEntry;
   // the window of an outfit's piece has no row, only a row that gets selected takes its card
   var piece = Equipment.shownPiece != undefined && event.index < 0;
   if(Equipment.anchorSlot != undefined && selected != Equipment.anchorSlot.entries[0] && !piece)
   {
      // another row took the card and the model, the window of the slot goes and leaves that row selected
      Equipment.shownApart = undefined;
      Equipment.shownPiece = undefined;
      Equipment.closePopup();
   }
   // the lists' own events come without an index, and in AS2 undefined >= 0 is true. Under the look sheet a step of the
   // list's width sent one, and the window of the last card came up under the sheet with its model through it
   Equipment.wantWindow(event.index > -1 && !(Equipment.look != undefined && Equipment.look._visible == true));
   if(event.type == "itemHighlightChange")
   {
      Equipment.lastHighlight = event;
      Equipment.cardPlaceTold = undefined;
   }
   Equipment.showWindow();
};

// How the window comes up over a row the pointer or the keys reach, iPopUp:Window: at once, once the row has stayed
// selected a moment so skimming the list shows nothing, or with the UI's own card never, the row's card and model stay
// where SkyUI or the skin puts them, as without the panel. A row a slot chose, a card that asks how many and Details of
// a row's menu bring it up anyway. Details does it in any mode, the plugin reads a never of an older file as after a
// pause
Equipment.WINDOW_AT_ONCE = 0;
Equipment.WINDOW_AFTER_REST = 1;
Equipment.WINDOW_OWN_CARD = 2;
Equipment.WINDOW_REST_MS = 400;

// A row whose details the player asked for in its menu keeps its window whatever Pops up says, until another row
// is picked by a click or a key
Equipment.wantWindow = function(row)
{
   var show = Equipment.popUpNow();
   var selected = Equipment.menu.inventoryLists.itemList.selectedEntry;
   var pinned = row && Equipment.pinnedRow != undefined && selected != undefined && Equipment.isRow(selected, Equipment.pinnedRow);
   if(row && !pinned)
   {
      Equipment.pinnedRow = undefined;
   }
   // the card Details or a slot's window took goes home before anything else looks where it is, and comes again with
   // its row: a list laid out anew lets go of the row a moment
   if(Equipment.cardBorrowed && !pinned && Equipment.anchorSlot == undefined)
   {
      Equipment.returnCard();
   }
   else if((pinned || Equipment.anchorSlot != undefined) && !Equipment.cardBorrowed && Equipment.ownCardNow())
   {
      Equipment.borrowCard();
   }
   Equipment.windowWanted = row && (show == Equipment.WINDOW_AT_ONCE && !Equipment.ownCardNow() || pinned);
   Equipment.restSince = row && !pinned && !Equipment.ownCardNow() && show == Equipment.WINDOW_AFTER_REST ? getTimer() : undefined;
};

// With the card at home (in the UI's place, the UI's own card) the window of Details or of a slot takes the card and the model
// for as long as it stands, the way the other modes show a row. Where the card stood and how it looked is kept for its
// way back. The numbers a card at home holds in the character's room step out meanwhile, the window has its own
Equipment.borrowCard = function()
{
   var card = Equipment.menu.itemCard;
   var holder = card._parent;
   if(Equipment.cardBorrowed)
   {
      return undefined;
   }
   Equipment.cardBorrowedFrom = {x:holder._x, y:holder._y, xscale:holder._xscale, yscale:holder._yscale, visible:holder._visible, back:card.background._visible, stolen:card.StolenTextInstance._visible};
   if(Equipment.cardNumbers != undefined)
   {
      Equipment.cardNumbers._visible = false;
      Equipment.cardFrameAsSkyUI(card.background);
   }
   Equipment.cardBorrowed = true;
   holder._visible = true;
   // at home SkyUI made long words smaller to fit its frame, laid out anew they grow down in the window
   Equipment.remakeCard();
   Equipment.sizeWindow();
};

Equipment.returnCard = function()
{
   var card = Equipment.menu.itemCard;
   var holder = card._parent;
   var home = Equipment.cardBorrowedFrom;
   Equipment.unlayKind();
   Equipment.unsizeCardText();
   Equipment.cardBorrowed = false;
   Equipment.cardBorrowedFrom = undefined;
   Equipment.windowLaid = undefined;
   if(home == undefined)
   {
      return undefined;
   }
   if(card.equipmentKind != undefined)
   {
      card.equipmentKind._visible = false;
   }
   // the copies of the frame the window wore live in the card, they stood at home as a second empty frame
   Equipment.cardFrameAsSkyUI(card.background);
   holder._x = home.x;
   holder._y = home.y;
   holder._xscale = home.xscale;
   holder._yscale = home.yscale;
   holder._visible = home.visible;
   card.background._visible = home.back;
   if(card.StolenTextInstance != undefined)
   {
      card.StolenTextInstance._visible = home.stolen;
   }
   // and at home they fit its frame again
   Equipment.remakeCard();
   Equipment.cardNumbersLater();
};

// The UI's own card where SkyUI puts it over the character (plain SkyUI) lies over the character as without this mod,
// only the model of a row waits for Details. A skin whose card stands apart from the character's room (Norden UI
// under the list) keeps its model at home too
Equipment.cardOverDoll = function()
{
   var holder = Equipment.menu.itemCard._parent;
   var room = Equipment.stage;
   var touch = room != undefined ? room.touch : undefined;
   var from = {x:0, y:0};
   var to;
   var card = {x:0, y:0};
   var box;
   if(touch == undefined || holder == undefined)
   {
      return false;
   }
   to = {x:touch._width, y:touch._height};
   room.localToGlobal(from);
   room.localToGlobal(to);
   box = holder.getBounds(_root);
   if(!(box.xMax > box.xMin))
   {
      holder.localToGlobal(card);
      box = {xMin:card.x, xMax:card.x, yMin:card.y, yMax:card.y};
   }
   return box.xMax >= from.x && box.xMin <= to.x && box.yMax >= from.y && box.yMin <= to.y;
};

Equipment.pinWindow = function(entry)
{
   Equipment.pinnedRow = Equipment.rowKey(entry);
   Equipment.pinnedAt = getTimer();
   if(Equipment.ownCardNow())
   {
      Equipment.borrowCard();
   }
   Equipment.wantWindow(true);
   Equipment.showWindow();
};

// The menu of the row lies over other rows, and the row under its Details line took the selection the moment the menu
// was gone, its window with it. While the window of Details stands the pointer passing over rows picks none, a click
// or a key picks as ever, a click beside it takes it down. A pad moves the selection by itself, it has nothing to hold.
// A list that lost the row (another category) holds nothing either
Equipment.pinHolds = function()
{
   var selected = Equipment.menu.inventoryLists.itemList.selectedEntry;
   return Equipment.pinnedRow != undefined && Equipment.menu._platform == 0 && selected != undefined && Equipment.isRow(selected, Equipment.pinnedRow);
};

Equipment.unpinWindow = function()
{
   Equipment.pinnedRow = undefined;
   Equipment.wantWindow(true);
   Equipment.showWindow();
};

// While the window of Details holds the list, a press on another row picks that row, as a press does where the pointer
// picked the row on its way, and a press beside the rows and the window takes the window down. The press on the Details
// line itself comes here too, after the line had its turn
Equipment.pressBesidePin = function()
{
   var entry;
   if(!Equipment.pinHolds() || getTimer() - Equipment.number(Equipment.pinnedAt) < Equipment.CONTEXT_SETTLE)
   {
      return undefined;
   }
   entry = Equipment.rowUnderMouse();
   if(entry != undefined)
   {
      if(!Equipment.isRow(entry, Equipment.pinnedRow))
      {
         Equipment.menu.inventoryLists.itemList.selectedIndex = entry.itemIndex;
      }
      return undefined;
   }
   if(!Equipment.window.hitTest(_root._xmouse, _root._ymouse, true) && !(Equipment.lens._visible && Equipment.lens.hitTest(_root._xmouse, _root._ymouse, true)))
   {
      Equipment.unpinWindow();
   }
};

Equipment.windowRestFrame = function()
{
   if(Equipment.restSince == undefined || getTimer() - Equipment.restSince < Equipment.WINDOW_REST_MS)
   {
      return undefined;
   }
   Equipment.restSince = undefined;
   Equipment.windowWanted = Equipment.menu.inventoryLists.itemList.selectedIndex >= 0;
   Equipment.showWindow();
};

// SkyUI keeps the last row selected when the pointer leaves the list, so its window stayed up with the row
// the pointer was last on. Off the rows the selection goes the way SkyUI drops it itself, and the card and the
// model go with it. The lens of the window still counts as on the row. Only a row the pointer chose on the rows goes
// so, a row the keys or a slot chose stays while the pointer rests or nudges somewhere else. SkyUI's first key press
// on a list with nothing selected leaves the list as driven by the mouse, so the way of each choice is kept from the
// list's own word on it. Called on every move of the mouse
Equipment.leaveRows = function()
{
   var list = Equipment.menu.inventoryLists.itemList;
   var lens = Equipment.lens;
   if(list.selectedIndex < 0 || Equipment.rowByKeys || !list.isMouseDrivenNav || Equipment.menu._platform != 0 || Equipment.anchorSlot != undefined || Equipment.context._visible || Equipment.dragging || Equipment.inspecting || Equipment.pinHolds() || !Equipment.listsAnswer())
   {
      return undefined;
   }
   if(Equipment.rowUnderMouse() != undefined || lens._visible && lens.hitTest(_root._xmouse, _root._ymouse, true))
   {
      return undefined;
   }
   list.selectedIndex = -1;
};

// The inventory's watch of the mouse comes with its drag (34-drag.as). The magic menu and the stations have no drag,
// their window stayed up after the pointer left the list, they get the watch of the rows alone
Equipment.watchLeaveRows = function()
{
   Equipment.rowsMouse = {};
   Equipment.rowsMouse.onMouseMove = function()
   {
      Equipment.followLensAim();
      Equipment.leaveRows();
   };
   Mouse.addListener(Equipment.rowsMouse);
};

// SkyUI tells with every new selection whether keys made it (SELECT_KEYBOARD) or the pointer
Equipment.SELECT_KEYBOARD = 1;
Equipment.rowChosen = function(event)
{
   Equipment.rowByKeys = event.keyboardOrMouse == Equipment.SELECT_KEYBOARD;
};

// The lens sits under the right end of the selected row, and a pointer going for it from the name crosses the
// next row on the way. That row would take the window and the lens away. While the pointer heads for the lens,
// a row it crosses waits a moment before it's selected, the way menus with side menus wait for the pointer
Equipment.aimForLens = function()
{
   var list = Equipment.menu.inventoryLists.itemList;
   list.equipmentRollOver = list.onItemRollOver;
   list.onItemRollOver = function(index)
   {
      if(Equipment.pinHolds())
      {
         return undefined;
      }
      if(Equipment.headsForLens())
      {
         Equipment.lensWait = {index:index, at:getTimer()};
         return undefined;
      }
      Equipment.lensWait = undefined;
      this.equipmentRollOver(index);
      Equipment.lensFrom = {x:_root._xmouse, y:_root._ymouse};
   };
};

// whether the pointer goes toward the lens from where it last was on the selected row: the line from there through
// the pointer meets the lens at the pointer or further on
Equipment.headsForLens = function()
{
   var from = Equipment.lensFrom;
   var lens = Equipment.lens;
   var slack = Equipment.LENS_AIM_SLACK;
   var box;
   if(from == undefined || !lens._visible || Equipment.menu._platform != 0)
   {
      return false;
   }
   box = lens.getBounds(_root);
   box = {xMin:box.xMin - slack, yMin:box.yMin - slack, xMax:box.xMax + slack, yMax:box.yMax + slack};
   return Equipment.stepsToBox(from.x, from.y, _root._xmouse - from.x, _root._ymouse - from.y, box) >= 1;
};

// how many steps a ray from a point takes to leave a box, -1 when it misses it
Equipment.stepsToBox = function(x, y, dx, dy, box)
{
   var near = 0;
   var far = Number.MAX_VALUE;
   var axes = [[x, dx, box.xMin, box.xMax], [y, dy, box.yMin, box.yMax]];
   var i = 0;
   var a;
   var b;
   while(i < axes.length)
   {
      if(axes[i][1] == 0)
      {
         if(axes[i][0] < axes[i][2] || axes[i][0] > axes[i][3])
         {
            return -1;
         }
      }
      else
      {
         a = (axes[i][2] - axes[i][0]) / axes[i][1];
         b = (axes[i][3] - axes[i][0]) / axes[i][1];
         near = Math.max(near, Math.min(a, b));
         far = Math.min(far, Math.max(a, b));
      }
      i++;
   }
   return near <= far ? far : -1;
};

// On every move of the mouse: where the pointer is on the selected row, and whether a waiting row gets its turn.
// It gets it once the pointer turns away from the lens, and never when the pointer reached the lens
Equipment.followLensAim = function()
{
   var list = Equipment.menu.inventoryLists.itemList;
   var lens = Equipment.lens;
   if(Equipment.lensWait == undefined)
   {
      if(Equipment.rowUnderMouse() == list.selectedEntry && list.selectedEntry != undefined)
      {
         Equipment.lensFrom = {x:_root._xmouse, y:_root._ymouse};
      }
   }
   else if(lens._visible && lens.hitTest(_root._xmouse, _root._ymouse, true))
   {
      Equipment.lensWait = undefined;
   }
   else if(!Equipment.headsForLens())
   {
      Equipment.endLensWait();
   }
   else
   {
      // still on its way, a slow hand gets its moment from the last move
      Equipment.lensWait.at = getTimer();
   }
};

Equipment.lensWaitFrame = function()
{
   if(Equipment.lensWait != undefined && getTimer() - Equipment.lensWait.at >= Equipment.LENS_AIM_MS)
   {
      Equipment.endLensWait();
   }
};

// the waiting row is selected if the pointer is still on it
Equipment.endLensWait = function()
{
   var list = Equipment.menu.inventoryLists.itemList;
   var wait = Equipment.lensWait;
   Equipment.lensWait = undefined;
   if(wait != undefined && list.entryList[wait.index] != undefined && list.entryList[wait.index] == Equipment.rowUnderMouse())
   {
      list.equipmentRollOver(wait.index);
      Equipment.lensFrom = {x:_root._xmouse, y:_root._ymouse};
   }
};

// The window is up as long as the menu keeps the card and the model of an item up. A selected row can
// be out of sight, scrolled away by the bar of the list, or gone for a moment while the list is put
// together again. The window then stays where it was, with the card and the model
Equipment.showWindow = function()
{
   var list = Equipment.menu.inventoryLists.itemList;
   var entry = list.selectedEntry;
   var row = entry == undefined ? undefined : list.getClipByIndex(entry.clipIndex);
   var popup = Equipment.anchorSlot != undefined;
   var wanted = Equipment.windowWanted || Equipment.cardAsking && !Equipment.ownCardNow();
   Equipment.keepCard();
   Equipment.window._visible = wanted || popup;
   Equipment.window.sheet._visible = Equipment.window._visible;
   // SkyUI keeps the card of a selected row up, the window it lies on decides here
   if(!Equipment.leavesCard())
   {
      Equipment.menu.itemCard._parent._visible = Equipment.window._visible;
   }
   if(popup)
   {
      Equipment.placeWindow(undefined);
   }
   else if(wanted && row != undefined)
   {
      Equipment.placeWindow(row);
   }
   Equipment.showLens(Equipment.window._visible && !popup);
   Equipment.askModel();
   // the window of the row whose menu is up may come after the menu. The menu's copy lies over the model, without one
   // the menu steps off its model, or where it can't the model steps out under the menu
   if(Equipment.context._visible && Equipment.contextEntry != undefined && Equipment.window._visible && !Equipment.contextOverlaid)
   {
      Equipment.clearOfModel(Equipment.context, Equipment.context.wide, Equipment.context.high, Equipment.barTop() - Equipment.MARGIN);
      Equipment.coverWindow();
   }
   if(Equipment.contextOverWindow() && !Equipment.contextOverlaid)
   {
      Equipment.contextHidesModel = true;
   }
   if(Equipment.ownCardNow() && !popup)
   {
      Equipment.aimPreview();
   }
   if(Equipment.plugin() != undefined)
   {
      Equipment.plugin().ShowPreview(Equipment.previewShown());
   }
   Equipment.tellOthersOfCard();
};

// Mods put words of their own on the card, Ingredients Have Description lays an ingredient's tale over its effects. They
// read where the card is when a row gets selected, and the window takes the card to its place only after that, once the
// row has rested or the game has sent the card. Their text landed where SkyUI keeps the card, over the doll. So once the
// card stands somewhere new the movies other mods loaded into the menu hear the selection again, and their clips that
// lie on the card go over the window and come and go with the card
Equipment.tellOthersOfCard = function()
{
   var place;
   Equipment.followCard();
   if(Equipment.window == undefined || !Equipment.window._visible || Equipment.lastHighlight == undefined || Equipment.menu.itemCard == undefined)
   {
      return undefined;
   }
   place = Equipment.cardPlace();
   if(place == Equipment.cardPlaceTold)
   {
      return undefined;
   }
   Equipment.cardPlaceTold = place;
   Equipment.retellHighlight(Equipment.lastHighlight);
   Equipment.findCardFollowers();
   Equipment.fitFollowers();
   Equipment.followCard();
};

Equipment.cardPlace = function()
{
   var card = Equipment.menu.itemCard;
   var from = {x:0, y:0};
   var to = {x:100, y:100};
   card.localToGlobal(from);
   card.localToGlobal(to);
   return Math.round(from.x) + "," + Math.round(from.y) + "," + Math.round(to.x - from.x) + "," + Math.round(to.y - from.y);
};

// A clip another mod's movie brought right into the menu. SkyUI's lists and bottom bar are movies of their own too, they
// stand where the menu's file put them, at the bottom depths from -16384 up. A mod's script makes its clip at a depth of
// its own choice, Ingredients Have Description at -6708, and the panel's clips come from the menu's own movie
Equipment.TIMELINE_DEPTHS = -16000;
Equipment.otherMovie = function(clip)
{
   var menu = Equipment.menu;
   var top = clip;
   while(top != undefined && top._parent != menu)
   {
      top = top._parent;
   }
   return clip instanceof MovieClip && top != undefined && top._url != undefined && top._url != menu._url && top.getDepth() > Equipment.TIMELINE_DEPTHS;
};

// The item in the character's room: its card stands at the room's foot, raised when it's long, and the model fills the
// room above the card the way it fills the window, laid along or stood up, never under the card. At the game's own
// place the raised card covered the middle of a sword. False when the room has no place for it
Equipment.placeRoomModel = function()
{
   var room = Equipment.stage;
   var back = Equipment.menu.itemCard != undefined ? Equipment.menu.itemCard.background : undefined;
   var pad = Equipment.WINDOW_PAD;
   var screen = Stage.visibleRect.height;
   var top = {x:0, y:0};
   var low;
   var box;
   var high;
   var wide;
   var middle;
   if(!Equipment.cardInRoom() || Equipment.cardBorrowed || room == undefined || room.touch == undefined || back == undefined)
   {
      return false;
   }
   low = {x:room.touch._width, y:room.touch._height};
   room.localToGlobal(top);
   room.localToGlobal(low);
   box = back.getBounds(_root);
   high = Math.min(low.y, box.yMin) - top.y - 2 * pad;
   wide = low.x - top.x - 2 * pad;
   if(!(high > 4 * pad) || !(wide > 4 * pad))
   {
      return false;
   }
   middle = Equipment.screenShare((top.x + low.x) / 2, top.y + pad + high / 2);
   // The room is half the screen high, a model sized and grown by it stood three times the game's size, a ring over the
   // whole character. In the room a model is as big as the game shows it at most
   Equipment.plugin().PlacePreview(middle.x, middle.y, Math.min(high / screen, Equipment.GAME_MODEL_SHARE), high / screen, wide / screen, 1);
   return true;
};

// the share of the screen's height the game sizes the model of an item for
Equipment.GAME_MODEL_SHARE = 0.45;

// the window that held the model of a row went and nothing shows the row now: the game drops the model, the row's
// next window asks for it
Equipment.letModelGo = function()
{
   var delegate = gfx.io.GameDelegate;
   var call = delegate.equipmentCall != undefined ? delegate.equipmentCall : delegate.call;
   call.apply(delegate, ["UpdateItem3D", [false]]);
   Equipment.modelHeld = Equipment.menu.inventoryLists.itemList.selectedIndex >= 0;
   Equipment.modelFor = undefined;
};

Equipment.askModelAgain = function()
{
   var delegate = gfx.io.GameDelegate;
   var call = delegate.equipmentCall != undefined ? delegate.equipmentCall : delegate.call;
   call.apply(delegate, ["UpdateItem3D", [false]]);
   call.apply(delegate, ["UpdateItem3D", [true]]);
};

// Tooltip mods put a box of their own movie right on the root of the menu, at the pointer or at the middle of the row:
// LoreBox, and the mods that write through it (Dynamic Tooltips). The window's model is 3D and drawn over every picture
// of the menu, it stood over the box's words. Another movie's box can't be copied over the 3D like the panel's own
// menus, so while one lies on the model the model steps out, and comes back when the box is gone
Equipment.OVERLAY_SEEN = 10;
Equipment.OVERLAY_MOST = 0.6;
Equipment.watchOverlays = function()
{
   var hides = Equipment.window._visible && Equipment.overlayOnModel();
   if(hides == (Equipment.overlayHidesModel == true))
   {
      return undefined;
   }
   Equipment.overlayHidesModel = hides;
   if(Equipment.plugin() != undefined)
   {
      Equipment.plugin().ShowPreview(Equipment.previewShown());
   }
};

Equipment.previewShown = function()
{
   return (Equipment.window._visible || Equipment.ownCardNow() && !Equipment.detailsOnly()) && !Equipment.browsing && Equipment.contextHidesModel != true && Equipment.overlayHidesModel != true;
};

Equipment.overlayOnModel = function()
{
   var model = Equipment.modelBox();
   var clip;
   var box;
   var from;
   var to;
   for(var name in _root)
   {
      clip = _root[name];
      if(!(clip instanceof MovieClip) || clip._parent != _root || clip == Equipment.menu || clip._url == Equipment.menu._url || String(clip._url).indexOf("InventoryReforged") >= 0)
      {
         continue;
      }
      box = Equipment.shownBox(clip, 0);
      if(box == undefined || (box.xMax - box.xMin) * (box.yMax - box.yMin) > Equipment.OVERLAY_MOST * Stage.visibleRect.width * Stage.visibleRect.height)
      {
         continue;
      }
      from = {x:box.xMin, y:box.yMin};
      to = {x:box.xMax, y:box.yMax};
      Equipment.toPanel(from);
      Equipment.toPanel(to);
      if(Equipment.meetsBox(from.x, from.y, to.x - from.x, to.y - from.y, model))
      {
         return true;
      }
   }
   return false;
};

// The part of a clip that shows on screen, from the clips in it a level or two down that are visible and not faded
// out: LoreBox keeps its box in its holder at full alpha and fades the box itself. Undefined when nothing shows
Equipment.fieldBox = function(field)
{
   var from;
   var to;
   if(!field._visible || field.text == "" || field._alpha < Equipment.OVERLAY_SEEN)
   {
      return undefined;
   }
   from = {x:field._x, y:field._y};
   to = {x:field._x + field._width, y:field._y + field._height};
   field._parent.localToGlobal(from);
   field._parent.localToGlobal(to);
   return {xMin:Math.min(from.x, to.x), yMin:Math.min(from.y, to.y), xMax:Math.max(from.x, to.x), yMax:Math.max(from.y, to.y)};
};

Equipment.shownBox = function(clip, depth)
{
   var box;
   var part;
   var child;
   var nested = false;
   if(!clip._visible || clip._alpha < Equipment.OVERLAY_SEEN)
   {
      return undefined;
   }
   if(depth < 2)
   {
      for(var name in clip)
      {
         child = clip[name];
         part = undefined;
         if(child instanceof TextField && child._parent == clip)
         {
            part = Equipment.fieldBox(child);
         }
         else if(child instanceof MovieClip && child._parent == clip)
         {
            nested = true;
            part = Equipment.shownBox(child, depth + 1);
         }
         if(part != undefined)
         {
            box = box == undefined ? part : {xMin:Math.min(box.xMin, part.xMin), yMin:Math.min(box.yMin, part.yMin), xMax:Math.max(box.xMax, part.xMax), yMax:Math.max(box.yMax, part.yMax)};
         }
      }
      if(nested)
      {
         return box;
      }
   }
   box = clip.getBounds(_root);
   // an empty clip has a box turned inside out
   return box.xMin < box.xMax && box.yMin < box.yMax ? box : undefined;
};

// the listeners of the selection that came with another movie loaded into the menu, the menu's own and the panel's stay out
Equipment.othersListening = function(type)
{
   var listeners = Equipment.menu.inventoryLists._listeners[type];
   var others = [];
   var i = 0;
   while(listeners != undefined && i < listeners.length)
   {
      if(listeners[i].listenerObject != Equipment.menu && Equipment.otherMovie(listeners[i].listenerObject))
      {
         others.push(listeners[i]);
      }
      i++;
   }
   return others;
};

Equipment.retellHighlight = function(event)
{
   var others = Equipment.othersListening(event.type);
   var i = 0;
   var who;
   var call;
   while(i < others.length)
   {
      who = others[i].listenerObject;
      call = others[i].listenerFunction != undefined ? others[i].listenerFunction : event.type;
      if(typeof who[call] == "function")
      {
         who[call](event);
      }
      i++;
   }
};

// Clips of other movies right in the menu that lie on the window. Each goes over the window once, under the panel's
// menus and windows that open later. The card's own box reaches far past the screen with the parts it hides
Equipment.findCardFollowers = function()
{
   var menu = Equipment.menu;
   var holder = menu.itemCard._parent;
   var card = Equipment.window.getBounds(_root);
   var clip;
   var box;
   if(Equipment.cardFollowers == undefined)
   {
      Equipment.cardFollowers = [];
   }
   for(var name in menu)
   {
      clip = menu[name];
      if(clip._parent != menu || clip == holder || clip.equipmentFollows || !Equipment.otherMovie(clip))
      {
         continue;
      }
      box = clip.getBounds(_root);
      if(box.xMax > card.xMin && box.xMin < card.xMax && box.yMax > card.yMin && box.yMin < card.yMax)
      {
         clip.equipmentFollows = true;
         Equipment.cardFollowers.push(clip);
         clip.swapDepths(menu.getNextHighestDepth());
         Equipment.over.swapDepths(menu.getNextHighestDepth());
      }
   }
};

// for tests, the clips right in the menu that came with another movie, where each lies and whether it follows
// the card, and the listeners of the selection from other movies
Equipment.followersReport = function(note)
{
   var menu = Equipment.menu;
   var lines = [];
   var clip;
   var box;
   for(var name in menu)
   {
      clip = menu[name];
      if(clip instanceof MovieClip && clip._parent == menu)
      {
         box = clip.getBounds(_root);
         lines.push(name + (Equipment.otherMovie(clip) ? " OTHER " + clip._url : "") + " depth " + clip.getDepth() + " box " + Math.round(box.xMin) + "," + Math.round(box.yMin) + "-" + Math.round(box.xMax) + "," + Math.round(box.yMax) + (clip.equipmentFollows ? " FOLLOWS" : "") + " shown " + clip._visible);
      }
   }
   skse.Log("PANELTEST followers " + note + ": menu " + menu._url + ", listeners from other movies " + Equipment.othersListening("itemHighlightChange").length + "; " + lines.join(" | "));
};

Equipment.cardScaleInMenu = function()
{
   var card = Equipment.menu.itemCard;
   var from = {x:0, y:0};
   var across = {x:100, y:0};
   var down = {x:0, y:100};
   card.localToGlobal(from);
   card.localToGlobal(across);
   card.localToGlobal(down);
   Equipment.menu.globalToLocal(from);
   Equipment.menu.globalToLocal(across);
   Equipment.menu.globalToLocal(down);
   return {x:(across.x - from.x) / 100, y:(down.y - from.y) / 100};
};

// A follower is laid out for the card where SkyUI keeps it, and the window shows the card smaller or bigger. It takes
// the card's size, its corner stays where its mod put it. The mod can put it anew any time, the tale of an ingredient
// comes once the scripts have found it, so this runs every frame
Equipment.fitFollowers = function()
{
   var followers = Equipment.cardFollowers;
   var home = Equipment.cardScaleAtOpen;
   var now;
   var across;
   var down;
   var follower;
   var box;
   var left;
   var top;
   var i = 0;
   if(followers == undefined || followers.length == 0 || home == undefined || !(home.x > 0) || !(home.y > 0))
   {
      return undefined;
   }
   now = Equipment.cardScaleInMenu();
   across = now.x / home.x;
   down = now.y / home.y;
   while(i < followers.length)
   {
      follower = followers[i];
      // every frame: a clip still where the last fit left it, at the same size, needs nothing
      if(follower._x == follower.fitX && follower._y == follower.fitY && follower._xscale == across * 100 && follower._yscale == down * 100)
      {
         i++;
         continue;
      }
      box = follower.getBounds(Equipment.menu);
      if(box.xMax >= box.xMin && follower._xscale > 0 && follower._yscale > 0)
      {
         // where its mod meant it, with no size of the window's
         left = (box.xMin - follower._x) * 100 / follower._xscale;
         top = (box.yMin - follower._y) * 100 / follower._yscale;
         follower._xscale = across * 100;
         follower._yscale = down * 100;
         follower._x = left * (1 - across);
         follower._y = top * (1 - down);
         follower.fitX = follower._x;
         follower.fitY = follower._y;
      }
      i++;
   }
};

// what lies on the card is seen while the card is, a card the window hides took their words along
Equipment.followCard = function()
{
   var followers = Equipment.cardFollowers;
   var shown;
   var i = 0;
   if(followers == undefined || followers.length == 0 || Equipment.leavesCard())
   {
      return undefined;
   }
   shown = Equipment.menu.itemCard._parent._visible;
   while(i < followers.length)
   {
      followers[i]._visible = shown;
      i++;
   }
};

// The card keeps every part it can ever show and hides the ones the item has no use for. These are
// the parts it shows now
Equipment.shownParts = function()
{
   var card = Equipment.menu.itemCard;
   var parts = [];
   var part;
   for(var name in card)
   {
      part = card[name];
      // the numbers of a chest's card and the pieces of its longer frame live inside it and aren't the card's own
      if(part._parent == card && part._name == name && part._visible && part._alpha > 0 && name.indexOf("equipment") != 0 && !Equipment.emptyPart(part))
      {
         parts.push(part);
      }
   }
   return parts;
};

// A field with no words or a clip with nothing drawn shows nothing. Edge UI keeps the fields of Survival Mode in sight
// with no text when it's off, and the window left a band of their height between the numbers and its own lines
Equipment.emptyPart = function(part)
{
   var box;
   if(part.getBounds == undefined)
   {
      return part.text != undefined && Equipment.blank(String(part.text));
   }
   box = part.getBounds(part);
   return !(box.xMax > box.xMin) || !(box.yMax > box.yMin);
};

Equipment.blank = function(words)
{
   var i = 0;
   var c;
   while(i < words.length)
   {
      c = words.charAt(i);
      if(c != " " && c != "\r" && c != "\n" && c != "\t")
      {
         return false;
      }
      i++;
   }
   return true;
};

// The edges of a clip or a text field as another clip sees them. A text field ends where its text does: SkyUI's
// field of a potion's effects stands several lines high, and a poison of one short line left an empty strip under it
Equipment.partBox = function(part, viewer)
{
   if(part.getBounds != undefined)
   {
      return part.getBounds(viewer);
   }
   var high = part.textHeight > 0 ? Math.min(part._height, (part.textHeight + 4) * part._yscale / 100) : part._height;
   var from = {x:part._x, y:part._y};
   var to = {x:part._x + part._width, y:part._y + high};
   part._parent.localToGlobal(from);
   part._parent.localToGlobal(to);
   viewer.globalToLocal(from);
   viewer.globalToLocal(to);
   return {xMin:from.x, yMin:from.y, xMax:to.x, yMax:to.y};
};

// The edges of a part with the whole height of a field, however few lines its words take
Equipment.wholeBox = function(part, viewer)
{
   var from;
   var to;
   if(part.getBounds != undefined)
   {
      return part.getBounds(viewer);
   }
   from = {x:part._x, y:part._y};
   to = {x:part._x + part._width, y:part._y + part._height};
   part._parent.localToGlobal(from);
   part._parent.localToGlobal(to);
   viewer.globalToLocal(from);
   viewer.globalToLocal(to);
   return {xMin:from.x, yMin:from.y, xMax:to.x, yMax:to.y};
};

// The card starts at its own top line, where all its kinds start, and ends under the lowest part it shows now. A part
// above that line moves the start up to it: Edge UI draws the charge bar of a recharge list over the list's title, and
// it stood in the model's room. Both are measured from where the card is placed
Equipment.cardSpan = function()
{
   if(Equipment.leavesCard())
   {
      return {top:0, bottom:0};
   }
   var card = Equipment.menu.itemCard;
   var scale = card._parent._yscale / 100;
   var parts = Equipment.shownParts();
   var top = 0;
   var bottom = 0;
   var box;
   var i = 0;
   while(i < parts.length)
   {
      box = Equipment.partBox(parts[i], card);
      // a part with no measure (NaN) moves neither end
      if(box.yMin < top)
      {
         top = box.yMin;
      }
      if(box.yMax > bottom)
      {
         bottom = box.yMax;
      }
      i++;
   }
   return {top:(card._y + top * card._yscale / 100) * scale, bottom:(card._y + (bottom + Equipment.CARD_PAD) * card._yscale / 100) * scale};
};

Equipment.drawWindow = function(high)
{
   var window = Equipment.window;
   window.high = high;
   window.touch._width = window.wide;
   window.touch._height = high;
};

// The sheet lies under the whole window, the copies of the card's frame over it. A frame the window can't wear leaves
// the sheet as the window's own frame, with an edge of its own
Equipment.drawSheet = function(framed)
{
   var window = Equipment.window;
   var sheet = window.sheet;
   var popup = Equipment.anchorSlot != undefined;
   var hole = framed ? window.inside.left + "," + window.inside.top + "," + window.inside.right + "," + window.inside.bottom + "," + window.see : "";
   sheet._x = window._x;
   sheet._y = window._y;
   sheet._xscale = window._xscale;
   if(window.high == sheet.high && popup == sheet.popup && window.wide == sheet.wide && framed == sheet.framed && hole == sheet.hole)
   {
      return undefined;
   }
   sheet.high = window.high;
   sheet.popup = popup;
   sheet.wide = window.wide;
   sheet.framed = framed;
   sheet.hole = hole;
   sheet.clear();
   if(framed)
   {
      Equipment.seeThroughSheet(sheet, window);
   }
   else
   {
      sheet.lineStyle(1, popup ? Equipment.accentInk() : Equipment.inkOf("edge"), popup ? 55 : 30, true);
      Equipment.fillSheet(sheet, window.wide, window.high, 100);
      Equipment.roundBox(sheet, 0, 0, window.wide, window.high, 4);
   }
   sheet.endFill();
};

// The window hides the rows under it whole, one sheet under all of it. The copies of the frame over it lighten what
// they lie on and never darken it (frameWindow), their dark fill left darker bands along the top and the bottom, and
// a layer in the middle to match them left a thin line at each seam
Equipment.seeThroughSheet = function(sheet, window)
{
   var box = window.inside != undefined ? window.inside : {left:0, top:0, right:window.wide, bottom:window.high};
   Equipment.fillSheet(sheet, window.wide, window.high, 100);
   Equipment.roundBox(sheet, box.left, box.top, box.right - box.left, box.bottom - box.top, 2);
};

// A soft near-black, a shade lighter at the top and deepest at the bottom the way the panel's own boxes go, flat black
// read as a hole in the screen. Paper keeps its own ink
Equipment.SHEET_INKS = [0x1C1B1A, 0x111111, 0x0A0A0A];
Equipment.fillSheet = function(sheet, wide, high, alpha)
{
   var turn;
   if(Equipment.paper)
   {
      sheet.beginFill(Equipment.inkOf("sheet"), alpha);
      return undefined;
   }
   turn = new flash.geom.Matrix();
   turn.createGradientBox(wide, high, Math.PI / 2, 0, 0);
   sheet.beginGradientFill("linear", Equipment.SHEET_INKS, [alpha, alpha, alpha], [0, 120, 255], turn);
};

// the height of everything under the card: the numbers of the panel, the body slots and, in a slot window, its buttons
Equipment.underCard = function(above)
{
   var high = Equipment.statsHeight() + Equipment.stolenHeight() + Equipment.extraHeight();
   var slots = Equipment.bodySlotsHeight();
   if(Equipment.anchorSlot != undefined)
   {
      high += slots + Equipment.ACTION_HIGH + 2 * Equipment.ACTION_GAP + Equipment.ACTION_EDGE;
   }
   else
   {
      // a window above its row has the lens in its lower corner, the numbers stay clear of it and the body slots share
      // that strip with it. Below its row the lens stands at the row's end, a strip kept for it there was an empty
      // band under a short card. Under SkyUI's frame the strip stands over its bottom edge, the quiet lines (a quest,
      // the mod an item is from) lay on the frame's line there
      high += Math.max(above == true ? Equipment.LENS_SIZE : 0, slots) + Equipment.frameEdge();
   }
   return high;
};

// How high the bottom edge of SkyUI's frame is in the window's units, the ornaments and the line, as the window
// wears it. Nothing for a window that keeps its own sheet (a skin's frame drawn as a picture)
Equipment.frameEdge = function()
{
   if(Equipment.leavesCard())
   {
      return 0;
   }
   var window = Equipment.window;
   var card = Equipment.menu.itemCard;
   var art = card != undefined && card.background != undefined ? card.background.getBounds(card) : undefined;
   var top = {x:0, y:0};
   var low;
   if(art == undefined || window.sheet.framed == false || !(art.yMax - art.yMin > 0))
   {
      return 0;
   }
   low = {x:0, y:Math.min(Equipment.WINDOW_FRAME_KEEP, (art.yMax - art.yMin) / 3)};
   card.localToGlobal(top);
   card.localToGlobal(low);
   window.globalToLocal(top);
   window.globalToLocal(low);
   return Math.max(0, low.y - top.y);
};

Equipment.placeWindow = function(row)
{
   var menu = Equipment.menu;
   var window = Equipment.window;
   var card = menu.itemCard._parent;
   var slot = Equipment.anchorSlot;
   var bottom = (slot != undefined ? menu.bottomBar._y : Equipment.barTop()) - Equipment.MARGIN;
   var laid = Equipment.windowLaid;
   // A list that scrolls smoothly lays its rows out every 16 ms while it moves, the window of the same card only
   // goes along with its row then. Anything new on the card lays it all out again
   var along = Equipment.listMoving == true && slot == undefined && laid != undefined && laid.entry == Equipment.windowEntry() && laid.stamp == Equipment.cardStamp && laid.wide == window.wide && laid.squash == Equipment.squash;
   var span;
   var body;
   var bodyAbove;
   var framed;
   var below;
   var at;
   var rowTop;
   var rowBottom;
   var roomAbove;
   var roomBelow;

   // The frame the card draws for itself has a height of its own for each kind of card and knows nothing
   // of a text that has grown. The window is drawn to the measure of the card and is its frame. The card's own
   // stolen note shrinks with the card into its corner, the window has a line of its own for it
   if(along)
   {
      span = laid.span;
      body = laid.body;
   }
   else
   {
      if(!Equipment.leavesCard())
      {
         menu.itemCard.background._visible = false;
         menu.itemCard.StolenTextInstance._visible = false;
         // the card's words to its frame, once a card shows an item's value
         if(Equipment.wordsShare == undefined && (Equipment.wordsShare = Equipment.cardWordsShare()) != undefined)
         {
            Equipment.sizeWindow();
         }
      }
      Equipment.windowUnits(slot != undefined ? 1 : Equipment.squash);
      if(!Equipment.leavesCard())
      {
         // what the last layout moved goes back first, the last move first
         Equipment.unlayKind();
         Equipment.unsizeCardText();
         Equipment.sizeCardText(true);
         Equipment.layKind();
      }
      span = Equipment.cardSpan();
      Equipment.fillStats(window.wide);
      Equipment.fillMadeOf(window);
      body = span.bottom - span.top + Equipment.underCard(false);
      if(!Equipment.leavesCard() && Equipment.cutWindowWords(body, slot, bottom) > 0)
      {
         span = Equipment.cardSpan();
         body = span.bottom - span.top + Equipment.underCard(false);
      }
      window.edge = slot == undefined ? Equipment.frameEdge() : 0;
   }
   // a window over its row keeps a strip for the lens, one under it doesn't
   bodyAbove = body + (along ? 0 : Equipment.underCard(true) - Equipment.underCard(false));

   if(slot != undefined)
   {
      // beside the slot, toward the doll, level with the slot as far as the screen lets it. A long list of what it's made
      // of makes the model's room taller while the screen has room for it
      window.preview = Math.max(Equipment.PREVIEW_HEIGHT, Math.min(Equipment.previewWanted(window), bottom - Equipment.frame.top - body));
      Equipment.drawWindow(window.preview + body);
      if(!Equipment.placeByPieces(slot, window, bottom))
      {
         window._x = Equipment.besideSlot(slot, window.wide);
         window._y = Math.max(Equipment.frame.top, Math.min(slot.box._y, bottom - window.high));
      }
      window.above = false;
      window.clamped = false;
   }
   else
   {
      rowTop = {x:0, y:row._y};
      rowBottom = {x:0, y:row._y + Equipment.menu.inventoryLists.itemList.layout.entryHeight};
      row._parent.localToGlobal(rowTop);
      row._parent.localToGlobal(rowBottom);
      Equipment.toPanel(rowTop);
      Equipment.toPanel(rowBottom);
      below = rowBottom.y + Equipment.WINDOW_GAP;
      roomBelow = bottom - below;
      // above its row the window keeps to the rows, the column names, the subcategories and the categories stay in
      // sight (Dear Diary, Nordic and Vel'dun lay a shorter list, the window went up over all of them)
      roomAbove = rowTop.y - Equipment.WINDOW_GAP - Math.max(Equipment.frame.top, Equipment.rowsTop());
      window.above = Equipment.PREVIEW_HEIGHT + body > roomBelow && (Equipment.PREVIEW_HEIGHT + bodyAbove <= roomAbove || roomAbove > roomBelow);
      body = window.above ? bodyAbove : body;
      // a long card fits on neither side of its row, the model gives up part of its place first. A long list of what it's
      // made of makes the room taller where that side has room, the side itself is chosen as for any item
      window.preview = Math.max(Equipment.PREVIEW_LEAST, Math.min(Equipment.previewWanted(window), (window.above ? roomAbove : roomBelow) - body));
      Equipment.drawWindow(window.preview + body);
      // and when even that is not enough the window lies over its row, the lens then sits at the end of the row
      window.clamped = window.high > (window.above ? roomAbove : roomBelow);
      window.rowEdge = window.above ? rowTop.y : rowBottom.y;
      window.rowMiddle = (rowTop.y + rowBottom.y) / 2;
      // the edge of the rows is measured anew, while the panel is built the list hasn't its full width yet
      Equipment.placeWindowLeft();
      window._x = window.left;
      window._y = window.above ? Math.max(Math.max(Equipment.frame.top, Equipment.rowsTop()), rowTop.y - Equipment.WINDOW_GAP - window.high) : Math.min(below, bottom - window.high);
   }
   at = Equipment.toStage({x:window._x, y:window._y + window.preview - span.top});
   menu.globalToLocal(at);
   if(!Equipment.leavesCard())
   {
      card._x = at.x;
      card._y = at.y;
   }
   if(along && window.high == laid.high && window.preview == laid.preview)
   {
      Equipment.drawSheet(laid.framed);
   }
   else
   {
      framed = Equipment.frameWindow();
      Equipment.drawSheet(framed);
      Equipment.placeStats(window, window.preview + span.bottom - span.top);
      Equipment.placeActions();
      Equipment.placeMadeOf(window);
      Equipment.windowLaid = slot == undefined ? {entry:Equipment.windowEntry(), stamp:Equipment.cardStamp, wide:window.wide, squash:Equipment.squash, span:span, body:body, high:window.high, preview:window.preview, framed:framed} : undefined;
   }
   // A card whose frame the window wears stays with it, the frame and the dark sheet under it are one box
   if(!Equipment.leavesCard() && window.sheet.framed != true)
   {
      Equipment.keepCardInWindow(card, window);
   }
   Equipment.aimPreview();
   Equipment.coverWindow();
   if(Equipment.textWatched != undefined && Equipment.textWatched.length > 0)
   {
      // a window that only went along with its row laid nothing out, words that came since still count as new
      if(!along)
      {
         Equipment.wordsLaid();
      }
      Equipment.keepUnshrunk();
   }
};

// A skin's card can keep its words far off its own left edge (Edge UI's forge card writes in the right part of a wide
// frame), they ran past the window's right side. Words that leave the window come back to its middle, SkyUI's card
// fits as it is and stays put
Equipment.keepCardInWindow = function(card, window)
{
   var parts = Equipment.shownParts();
   var from = Equipment.toStage({x:window._x + Equipment.STATS_PAD, y:0});
   var to = Equipment.toStage({x:window._x + window.wide - Equipment.STATS_PAD, y:0});
   var left;
   var right;
   var box;
   var shift;
   var i = 0;
   while(i < parts.length)
   {
      box = Equipment.wordsBox(parts[i]);
      if(parts[i] != card.background && box.xMax > box.xMin)
      {
         left = left == undefined ? box.xMin : Math.min(left, box.xMin);
         right = right == undefined ? box.xMax : Math.max(right, box.xMax);
      }
      i++;
   }
   Equipment.cardWindowShift = 0;
   if(left == undefined || left >= from.x && right <= to.x)
   {
      return undefined;
   }
   from = {x:(from.x + to.x - left - right) / 2, y:0};
   to = {x:0, y:0};
   card._parent.globalToLocal(from);
   card._parent.globalToLocal(to);
   shift = from.x - to.x;
   card._x += shift;
   Equipment.cardWindowShift = shift;
};

// What of a part shows across the stage, or across the viewer when one is named: a clip's picture, a field's words by
// its alignment
Equipment.wordsBox = function(part, viewer)
{
   var seen = viewer != undefined ? viewer : _root;
   var box;
   var wide;
   var align;
   if(part.getBounds != undefined)
   {
      return part.getBounds(seen);
   }
   box = Equipment.partBox(part, seen);
   wide = Math.min(box.xMax - box.xMin, (box.xMax - box.xMin) * (part.textWidth + 4) / part._width);
   align = part.text != "" ? part.getTextFormat(0, 1).align : "left";
   if(align == "right")
   {
      box.xMin = box.xMax - wide;
   }
   else if(align == "center")
   {
      box.xMin = (box.xMin + box.xMax - wide) / 2;
      box.xMax = box.xMin + wide;
   }
   else
   {
      box.xMax = box.xMin + wide;
   }
   return box;
};

// for tests, the window, its dark sheet and the copies of the card's frame it wears, on the stage, so a frame
// off its sheet shows by how much
Equipment.windowSheetReport = function()
{
   var window = Equipment.window;
   var card = Equipment.menu.itemCard;
   var lines = [];
   var names = ["background", "equipmentFrameTop", "equipmentFrameTopMask", "equipmentFrameFill", "equipmentFrameFillMask", "equipmentFrameBottom", "equipmentFrameBottomMask"];
   var box;
   var i = 0;
   var stage = function(clip)
   {
      var bounds = clip.getBounds(_root);
      return Math.round(bounds.xMin) + "," + Math.round(bounds.yMin) + " to " + Math.round(bounds.xMax) + "," + Math.round(bounds.yMax);
   };
   lines.push("window " + stage(window) + " wide " + Math.round(window.wide) + " high " + Math.round(window.high) + " preview " + Math.round(window.preview));
   lines.push("sheet " + stage(window.sheet) + " framed " + window.sheet.framed + " see " + window.see);
   if(window.hole != undefined)
   {
      box = {xMin:window.hole.left, yMin:window.hole.top, xMax:window.hole.right, yMax:window.hole.bottom};
      lines.push("hole in the window's units " + Math.round(box.xMin) + "," + Math.round(box.yMin) + " to " + Math.round(box.xMax) + "," + Math.round(box.yMax));
   }
   if(window.inside != undefined)
   {
      lines.push("dark inside the frame's line " + Math.round(window.inside.left) + "," + Math.round(window.inside.top) + " to " + Math.round(window.inside.right) + "," + Math.round(window.inside.bottom) + " of " + Math.round(window.wide) + "x" + Math.round(window.high) + ", frame copies " + Equipment.menu.itemCard.equipmentFrameTop.blendMode);
   }
   while(i < names.length)
   {
      if(card[names[i]] != undefined)
      {
         lines.push(names[i] + (card[names[i]]._visible ? "" : " hidden") + " " + stage(card[names[i]]));
      }
      i++;
   }
   skse.Log("PANELTEST window sheet: " + lines.join("; "));
};

// Where the first row of the list starts, in the panel's units, the frame's top for a list with no rows on screen
Equipment.rowsTop = function()
{
   var first = Equipment.menu.inventoryLists.itemList.getClipByIndex(0);
   var top;
   if(first == undefined || !first._visible)
   {
      return Equipment.frame.top;
   }
   top = {x:0, y:first.getBounds(_root).yMin};
   Equipment.toPanel(top);
   return top.y;
};

// The window wears the card's own frame, SkyUI's or a skin's drawn like it: the top edge with its ornaments goes up
// over the model, the bottom edge down under the numbers, and a plain slice of the frame stretches between. A frame
// whose copies come out empty (a skin's picture in clips of its own) stays hidden and the window keeps its own sheet.
// Tells whether the window wears the card's frame
Equipment.WINDOW_FRAME_KEEP = 30;
Equipment.WINDOW_FRAME_SLICE = 4;
Equipment.WINDOW_FRAME_SIDES = 12;
Equipment.frameWindow = function()
{
   var window = Equipment.window;
   var card = Equipment.menu.itemCard;
   var back = card.background;
   var top = {x:0, y:0};
   var low = {x:0, y:window.high};
   var art;
   var pieces;
   if(back == undefined || Equipment.leavesCard())
   {
      return false;
   }
   Equipment.cardFrameAsSkyUI(back);
   back._visible = true;
   art = back.getBounds(card);
   window.localToGlobal(top);
   window.localToGlobal(low);
   card.globalToLocal(top);
   card.globalToLocal(low);
   pieces = Equipment.windowPieces(art, top.y, low.y, Equipment.WINDOW_FRAME_KEEP, Equipment.WINDOW_FRAME_SLICE);
   if(!(art.yMax - art.yMin > 0) || pieces.sliceHigh < 1 || pieces.fillHigh < 1 || !Equipment.frameCopies(card, back, art, pieces.cut, pieces, Equipment.WINDOW_FRAME_SIDES))
   {
      Equipment.cardFrameAsSkyUI(back);
      back._visible = false;
      return false;
   }
   window.hole = Equipment.frameHole(window, card, art, pieces);
   window.inside = Equipment.frameInside(window, card, art, pieces);
   window.see = back._alpha;
   // the lines and knots of the frame show, its dark fill adds nothing to the window's own dark. Paper keeps the frame
   // as it's drawn, its ink is darker than the paper
   card.equipmentFrameTop.blendMode = card.equipmentFrameFill.blendMode = card.equipmentFrameBottom.blendMode = Equipment.paper ? "normal" : "lighten";
   return true;
};

// The copies of the frame bring the card's own dark fill along its top and bottom edges and down its sides. The
// sheet fills only what lies between, in the window's units, so the whole window is as see-through as SkyUI's card
Equipment.frameHole = function(window, card, art, pieces)
{
   var from = {x:art.xMin + Equipment.WINDOW_FRAME_SIDES, y:pieces.cut - pieces.rise};
   var to = {x:art.xMax - Equipment.WINDOW_FRAME_SIDES, y:pieces.cut - pieces.rise + pieces.fillHigh};
   card.localToGlobal(from);
   card.localToGlobal(to);
   window.globalToLocal(from);
   window.globalToLocal(to);
   return {left:from.x, top:from.y, right:to.x, bottom:to.y};
};

// Where SkyUI's frame draws its line, in the window's units. The line stands this far inside the art of the card's
// frame on every side, the top and bottom edges keep their size, so the window's dark ends on the line as SkyUI's card
// does, it reached a little past the frame before
Equipment.WINDOW_SHEET_INSET = 6;
Equipment.frameInside = function(window, card, art, pieces)
{
   var inset = Equipment.WINDOW_SHEET_INSET;
   var from = {x:art.xMin + inset, y:art.yMin - pieces.rise + inset};
   var to = {x:art.xMax - inset, y:art.yMax + pieces.shift - inset};
   card.localToGlobal(from);
   card.localToGlobal(to);
   window.globalToLocal(from);
   window.globalToLocal(to);
   return {left:from.x, top:from.y, right:to.x, bottom:to.y};
};

// The pieces of the card's frame for the window, in the card's units: the top edge keeps its size and goes up to
// top, the bottom edge keeps its size and goes to bottom, a slice just under the top edge stretches between them.
// The frame may come out shorter than SkyUI drew it, the frame of a kind of card knows nothing of a text that grew
Equipment.windowPieces = function(art, top, bottom, keep, slice)
{
   var kept = Math.min(keep, (art.yMax - art.yMin) / 3);
   var cut = art.yMin + kept;
   return {cut:cut, rise:art.yMin - top, bottomFrom:art.yMax - kept, shift:bottom - art.yMax, sliceTop:cut, sliceHigh:Math.min(slice, art.yMax - art.yMin - 2 * kept), fillHigh:bottom - top - 2 * kept};
};

// A window or a menu of a slot opens beside it toward the doll, the doll is drawn under them. The names under
// the slots reach past them toward the doll, so it keeps clear of the widest name of the column
Equipment.besideSlot = function(slot, wide)
{
   var size = Equipment.SLOT_SIZE;
   var reach = size;
   var other;
   var i = 0;
   while(i < Equipment.SLOTS.length)
   {
      other = Equipment.SLOTS[i];
      if(other.column == slot.column && other.box.label != undefined && Equipment.slotShown(other))
      {
         reach = Math.max(reach, Math.min(Equipment.LABEL_WIDTH, other.box.label.textWidth + 4));
      }
      i++;
   }
   return slot.column == 0 ? slot.box._x + reach + Equipment.POPUP_GAP : slot.box._x + size - reach - Equipment.POPUP_GAP - wide;
};

// The game shows the model of the selected item where the top part of the window is. SkyUI's frame takes the top of
// that part with its edge, a long sword reached over it: the model's room starts under the edge and goes across the
// whole window, the plugin fits what is seen of the model into it both ways and lays a long one along it. The list
// of what the item is made of in the room's top left corner goes along, the model keeps clear of it
Equipment.aimPreview = function()
{
   var window = Equipment.window;
   var high = window.preview != undefined ? window.preview : Equipment.PREVIEW_HEIGHT;
   var wide = Equipment.windowWide();
   var top = Equipment.previewTop(window, high);
   var screen = Stage.visibleRect.height;
   var pad = Equipment.WINDOW_PAD;
   window.previewTop = top;
   var middle = Equipment.share(window._x + wide / 2, window._y + (top + high) / 2);
   var corner = Equipment.madeOfCorner(window, window._x + wide / 2, window._y + (top + high) / 2, screen);
   window.modelRoom = {xMin:window._x + pad, yMin:window._y + top + pad, xMax:window._x + wide - pad, yMax:window._y + high - pad};
   // with the UI's own card the model of a row stays where the game puts it, only a slot's window takes it in. A model
   // that window took kept its place and size there, the selected row's model is asked for anew at home
   if(Equipment.ownCardNow() && Equipment.anchorSlot == undefined)
   {
      if(Equipment.plugin() != undefined && !Equipment.inspecting)
      {
         if(!Equipment.placeRoomModel())
         {
            Equipment.plugin().PreviewHome();
         }
         if(Equipment.previewAway && Equipment.detailsOnly())
         {
            Equipment.letModelGo();
         }
         else if(Equipment.previewAway && Equipment.menu.inventoryLists.itemList.selectedIndex >= 0)
         {
            Equipment.askModelAgain();
         }
         Equipment.previewAway = false;
      }
      return undefined;
   }
   // as the menu opened: the window of Details borrows the card and the model, its model goes home the same way after
   Equipment.previewAway = Equipment.ownCard == true || Equipment.leftCard == true;
   if(Equipment.plugin() != undefined && !Equipment.inspecting && corner != undefined)
   {
      Equipment.plugin().PlacePreview(middle.x, middle.y, (high - 2 * pad) / screen, (high - top - 2 * pad) / screen, (wide - 2 * pad) / screen, 0, corner.right, corner.down);
   }
   else if(Equipment.plugin() != undefined && !Equipment.inspecting)
   {
      Equipment.plugin().PlacePreview(middle.x, middle.y, (high - 2 * pad) / screen, (high - top - 2 * pad) / screen, (wide - 2 * pad) / screen);
   }
};

// where the model's room starts in the window, under the edge of SkyUI's frame the window wears
Equipment.previewTop = function(window, high)
{
   return window.sheet.framed == true && window.hole != undefined ? Math.max(0, Math.min(window.hole.top, high / 2)) : 0;
};

// A window or a menu can lie over slot models. Those are 3D drawn over the menu, so what the open one
// overlaps steps out while it's open. The doll is drawn under the menu and stays, a menu with its copy drawn over
// the 3D needs nothing to step out
Equipment.coverWindow = function()
{
   var window = Equipment.window;
   var context = Equipment.context;
   var over;
   var from;
   var to;
   if(Equipment.plugin() == undefined)
   {
      return undefined;
   }
   // the sheet of the look lies over the list, a row selected under it would bring its model over the sheet
   if(Equipment.look != undefined && Equipment.look._visible)
   {
      Equipment.coverLook();
      return undefined;
   }
   if(context._visible && !Equipment.contextOverlaid)
   {
      over = {x:context._x, y:context._y, wide:context.wide, high:context.high};
   }
   else if(Equipment.anchorSlot != undefined && window._visible)
   {
      over = {x:window._x, y:window._y, wide:Equipment.windowWide(), high:window.high};
   }
   if(over == undefined)
   {
      Equipment.plugin().Cover();
      return undefined;
   }
   from = Equipment.share(over.x, over.y);
   to = Equipment.share(over.x + over.wide, over.y + over.high);
   Equipment.plugin().Cover(from.x, from.y, to.x, to.y);
};

// The kind of the item stands under its name: its class and its kind as the chips and the column of kinds name them,
// Heavy Armor, Head or One-Handed, Sword. The name keeps its place on every kind of
// card, the parts under it move down a line. They are moved back before every new layout, a part the card placed
// anew meanwhile isn't touched. The card of a piece has the skill in small letters in its corner too, it steps out
// while the line says it
Equipment.layKind = function()
{
   var card = Equipment.menu.itemCard;
   var entry = Equipment.windowEntry();
   var skill = card.itemInfo != undefined ? card.itemInfo.skillText : undefined;
   var words = entry != undefined && Equipment.settings.quietTags && !Equipment.chargeListUp() ? Equipment.kindLine(entry, skill) : "";
   var corner = card.SkillTextInstance;
   var field = card.ItemText.ItemTextField;
   var format;
   var name = card.ItemText;
   var kind = card.equipmentKind;
   var share = Equipment.textShare("quiet");
   var line = Math.round(Equipment.KIND_LINE * share);
   var parts;
   var top;
   var box;
   var i = 0;
   Equipment.unlayKind();
   if(kind == undefined)
   {
      kind = card.createTextField("equipmentKind", 900, 0, 0, 10, 10);
   }
   Equipment.styleText(kind, Math.round(Equipment.KIND_TEXT * share), "center", Equipment.inkOf("kind"));
   kind._visible = false;
   if(corner != undefined && corner.equipmentHid == true)
   {
      corner._visible = true;
      corner.equipmentHid = false;
   }
   if(words == "" || name == undefined || !name._visible)
   {
      return undefined;
   }
   if(corner != undefined && corner._visible && entry.formType == Equipment.ARMOR && Equipment.lineShown("kind"))
   {
      corner._visible = false;
      corner.equipmentHid = true;
   }
   top = Equipment.nameBox(card);
   parts = Equipment.shownParts();
   i = 0;
   while(i < parts.length)
   {
      box = Equipment.wholeBox(parts[i], card);
      // by its middle: a skin's fields can be taller than their words and reach up past the bottom of the name. The
      // whole field counts, a card that shrinks a wide number in its field would raise the middle of its words and
      // leave the number up while its label moved down
      if(parts[i] != name && parts[i] != kind && parts[i] != card.background && (box.yMin + box.yMax) / 2 >= top.yMax)
      {
         // A part still standing lines under where it stood before the first line came in missed its way back.
         // It goes home first
         if(parts[i].kindHome != undefined && Equipment.linesDown(parts[i]._y - parts[i].kindHome, line))
         {
            parts[i]._y = parts[i].kindHome;
         }
         parts[i].kindHome = parts[i]._y;
         parts[i]._y += line;
         parts[i].kindTo = parts[i]._y;
         parts[i].kindBy = line;
         Equipment.kindMoved.push(parts[i]);
      }
      i++;
   }
   // the line keeps to the name's side: Edge UI writes the name from the left, SkyUI in the middle
   format = kind.getNewTextFormat();
   format.align = field != undefined && field.getTextFormat().align != undefined ? field.getTextFormat().align : "center";
   kind.setNewTextFormat(format);
   kind.textColor = Equipment.inkOf("kind");
   kind.text = words.toUpperCase();
   kind._x = top.xMin;
   kind._width = top.xMax - top.xMin;
   kind._height = line + 4;
   kind._y = top.yMax;
   kind._visible = true;
};

// the parts the kind line moved down go back up, a part the card has moved itself since stays where it is
Equipment.unlayKind = function()
{
   var moved = Equipment.kindMoved;
   var i = 0;
   // the words were cut after the kind line came in, they go back first
   Equipment.uncutWords();
   while(moved != undefined && i < moved.length)
   {
      if(moved[i]._y == moved[i].kindTo)
      {
         moved[i]._y -= moved[i].kindBy != undefined ? moved[i].kindBy : Equipment.KIND_LINE;
      }
      moved[i].kindTo = undefined;
      i++;
   }
   Equipment.kindMoved = [];
};

// The card's words at the sizes the player set: the name, then the fields that wrap their lines (the effects of a
// potion, an enchantment, a description). A field grows from the size the card gave it and every part under it moves
// down by what it grew, so the numbers and lines under the card make room. A name too long for its line at that
// size comes out as big as still fits. Each layout starts again from the card as the menu left it. In the window the
// words also make room past their box (fitOverflow), a chest's card is left to moreHUD's layout of it. The game's own
// card out of the window (a chest, a shop, the card left home) has one size of its own for all its words
Equipment.sizeCardText = function(inWindow)
{
   var nameShare = Equipment.textShare(inWindow ? "name" : "card");
   var wordsShare = Equipment.textShare(inWindow ? "words" : "card");
   var card = Equipment.menu.itemCard;
   var grown = [];
   var parts;
   var box;
   var field;
   var i;
   var g;
   Equipment.textMoved = [];
   Equipment.textGrown = [];
   Equipment.textOverflowed = [];
   Equipment.textUnshrunk = [];
   Equipment.textWatched = [];
   if(card.ItemText.ItemTextField != undefined && card.ItemText._visible)
   {
      Equipment.growField(card.ItemText.ItemTextField, card.ItemText, nameShare, false, grown);
   }
   for(var name in card)
   {
      field = card[name];
      if(field instanceof TextField && field._parent == card && field._name == name && field._visible && field.wordWrap == true && field.text != "")
      {
         Equipment.unshrinkWords(field, inWindow);
         // the words as they are laid out: Description Framework writes its text into the card while the window is still
         // being laid out (the game fills the card as the window asks for the model), counted at the end they hid the new
         // words
         field.equipmentLaidText = field.text;
         field.equipmentLaidWords = field.textHeight;
         if(inWindow)
         {
            Equipment.fitOverflow(field, grown);
         }
         Equipment.growField(field, field, wordsShare, true, grown);
      }
   }
   if(grown.length == 0)
   {
      return undefined;
   }
   parts = Equipment.shownParts();
   i = 0;
   while(i < parts.length)
   {
      box = Equipment.wholeBox(parts[i], card);
      g = 0;
      while(g < grown.length)
      {
         // by its middle, under the bottom the grown part had before
         if(parts[i] != grown[g].part && parts[i] != card.background && (box.yMin + box.yMax) / 2 >= grown[g].bottom)
         {
            parts[i]._y += grown[g].by;
            parts[i].textBy = (parts[i].textTo == parts[i]._y - grown[g].by ? parts[i].textBy : 0) + grown[g].by;
            parts[i].textTo = parts[i]._y;
            if(parts[i].textListed != true)
            {
               parts[i].textListed = true;
               Equipment.textMoved.push(parts[i]);
            }
         }
         g++;
      }
      i++;
   }
};

// SkyUI fits some words by drawing them smaller, the enchantment of a weapon has textAutoSize "shrink" and never goes
// through ApplyTextOverflow. The words keep their size, the window makes room past their box (fitOverflow), a card of
// a chest or of the room grows the box. A card at home keeps SkyUI's way
Equipment.unshrinkWords = function(field, inWindow)
{
   if(Equipment.leavesCard() && !Equipment.cardInRoom())
   {
      return undefined;
   }
   Equipment.textWatched.push(field);
   if(field.textAutoSize != "shrink")
   {
      return undefined;
   }
   Equipment.textUnshrunk.push({field:field, high:field._height, text:field.text});
   Equipment.unshrinkNow(field);
   if(!inWindow && field.textHeight + 4 > field._height)
   {
      field._height = field.textHeight + 4;
   }
};

// Shrink off alone kept the small letters it had drawn until the text came anew (Ghostblade in the window, Nordic UI's
// card in the character's room), the same words go in again. The html set back gains an empty paragraph at its end,
// four units that cut a description that had fitted (Torch in a chest), it goes
Equipment.unshrinkNow = function(field)
{
   var words;
   field.textAutoSize = "none";
   field.htmlText = field.htmlText;
   words = field.text;
   if(words.length > 0 && (words.charAt(words.length - 1) == "\r" || words.charAt(words.length - 1) == "\n"))
   {
      field.replaceText(words.length - 1, words.length, "");
   }
};

// One field at a share of the size the card gave it. part is what the card holds, the field or the clip round it.
// Tells grown how far down the part moved what lies under it, in the card's units
Equipment.growField = function(field, part, share, wraps, grown)
{
   var card = Equipment.menu.itemCard;
   var size = Equipment.number((field.text != "" ? field.getTextFormat(0, 1) : field.getNewTextFormat()).size);
   // only the size changes, the colours and letters of the card's html stay
   var format = new TextFormat();
   var before;
   var target;
   var box;
   var by;
   if(size <= 0)
   {
      return undefined;
   }
   // the size the card gives it: what it has now, unless that's the size the panel set the last time
   if(field.equipmentSizedTo == undefined || size != field.equipmentSizedTo || field.equipmentBaseSize == undefined)
   {
      field.equipmentBaseSize = size;
      field.equipmentBaseHigh = field._height;
   }
   // at its own size a field the panel never grew is the card's as it is, html sizes and all
   if(share == 1 && (field.equipmentSizedTo == undefined || field.equipmentSizedTo == field.equipmentBaseSize))
   {
      field.equipmentSizedTo = undefined;
      return undefined;
   }
   target = Math.round(field.equipmentBaseSize * share);
   format.size = field.equipmentBaseSize;
   field.setTextFormat(format);
   field._height = field.equipmentBaseHigh;
   // SkyUI shrinks the name to fit its box, its height too, and a bigger size came out smaller than the card's own
   // (Norden UI's name at 150% drew at a third of it, over the top of its box). While the panel sizes it the name has
   // no shrink, the loop below keeps it to its line and it gets shrink back with the card's size. A name too long for
   // its line at the card's own size keeps SkyUI's way
   if(!wraps && field.textAutoSize == "shrink" && target != field.equipmentBaseSize)
   {
      Equipment.unshrinkNow(field);
      if(Equipment.lineFits(field))
      {
         Equipment.textUnshrunk.push({field:field, high:field.equipmentBaseHigh, text:field.text});
      }
      else
      {
         field.textAutoSize = "shrink";
         target = field.equipmentBaseSize;
      }
   }
   // the bottom of its letters: the clip round the name is taller than them, and the card's rule under the name lay
   // inside that clip and stayed up while the name grew over it
   box = part != field && part == card.ItemText ? Equipment.nameBox(card) : Equipment.partBox(part, card);
   before = field.textHeight;
   format.size = target;
   field.setTextFormat(format);
   // a line that doesn't wrap keeps to its width
   while(!wraps && target > field.equipmentBaseSize && !Equipment.lineFits(field))
   {
      target--;
      format.size = target;
      field.setTextFormat(format);
   }
   field.equipmentSizedTo = target;
   if(target == field.equipmentBaseSize)
   {
      return undefined;
   }
   Equipment.textGrown.push(field);
   by = (field.textHeight - before) * field._yscale / 100 * (part != field ? part._yscale / 100 : 1);
   // the box takes the letters whole, in the units it's measured in (Norden UI draws the name's field at 85%)
   field._height = Math.max(field.equipmentBaseHigh, (field.textHeight + 4) * field._yscale / 100);
   if(by > 0)
   {
      grown.push({part:part, bottom:box.yMax, by:by});
   }
};

// whether a line of words is no wider than its field, the field's width counts in its parent's units
Equipment.lineFits = function(field)
{
   return (field.textWidth + 4) * field._xscale / 100 <= field._width;
};

// Words longer than their box. SkyUI fits a spell's description into its box by letting the box grow a few lines down
// (origHeight is the box it had), the level and cost under it stay where they stood, and a long description ran on
// over them. Here what lies under the box moves down by what the words took past it. The window is narrower than
// SkyUI's card, a line there is two here and the level stood right under the words, so words SkyUI fits keep a line
// of air under them, the air SkyUI's own card leaves under one line
Equipment.fitOverflow = function(field, grown)
{
   var card = Equipment.menu.itemCard;
   var box = field.origHeight > 0 ? field.origHeight : field._height;
   var high = Math.max(field._height, field.textHeight + 4);
   var air = field.origHeight > 0 ? field.textHeight / Math.max(1, field.numLines) : 0;
   var over = (Math.max(high, field.textHeight + 4 + air) - box) * field._yscale / 100;
   var top;
   if(!(over > 1))
   {
      return undefined;
   }
   top = Equipment.wholeBox(field, card).yMin;
   field.equipmentOverHigh = field._height;
   field.equipmentOverText = field.text;
   field._height = high;
   Equipment.textOverflowed.push(field);
   grown.push({part:field, bottom:top + box * field._yscale / 100, by:over});
};

// whether a part stands a whole number of the kind's lines lower than it should, a few at most
Equipment.linesDown = function(by, line)
{
   var lines = by / line;
   return line > 0 && lines > 0.5 && lines < 5.5 && Math.abs(lines - Math.round(lines)) < 0.05;
};

// the parts the words moved down go back up, a part the card has moved itself since stays where it is, and the
// fields that grew get the card's size again
Equipment.unsizeCardText = function()
{
   var moved = Equipment.textMoved;
   var grown = Equipment.textGrown;
   var over = Equipment.textOverflowed;
   var format;
   var i = 0;
   Equipment.uncutWords();
   while(grown != undefined && i < grown.length)
   {
      if(grown[i].equipmentBaseSize != undefined && grown[i].equipmentSizedTo != undefined && grown[i].text != undefined)
      {
         format = new TextFormat();
         format.size = grown[i].equipmentBaseSize;
         grown[i].setTextFormat(format);
         grown[i]._height = grown[i].equipmentBaseHigh;
      }
      grown[i].equipmentSizedTo = undefined;
      i++;
   }
   Equipment.textGrown = [];
   // A box grown to its words gets its own height back after the size, it grew first. Only for the words it was
   // measured with: Description Framework adds its description a frame after the card was filled, SkyUI grew the box
   // for both, and the height of the enchantment alone put back squeezed six lines into three
   i = 0;
   while(over != undefined && i < over.length)
   {
      if(over[i].equipmentOverHigh != undefined && over[i].text == over[i].equipmentOverText)
      {
         over[i]._height = over[i].equipmentOverHigh;
      }
      over[i].equipmentOverHigh = undefined;
      over[i].equipmentOverText = undefined;
      i++;
   }
   Equipment.textOverflowed = [];
   // words SkyUI drew smaller get that way back, and their box when they're the words it was made for
   i = Equipment.textUnshrunk != undefined ? Equipment.textUnshrunk.length - 1 : -1;
   while(i >= 0)
   {
      if(Equipment.textUnshrunk[i].high != undefined && Equipment.textUnshrunk[i].field.text == Equipment.textUnshrunk[i].text)
      {
         Equipment.textUnshrunk[i].field._height = Equipment.textUnshrunk[i].high;
      }
      Equipment.textUnshrunk[i].field.textAutoSize = "shrink";
      i--;
   }
   Equipment.textUnshrunk = [];
   Equipment.textWatched = [];
   i = 0;
   while(moved != undefined && i < moved.length)
   {
      if(moved[i]._y == moved[i].textTo)
      {
         moved[i]._y -= moved[i].textBy;
      }
      moved[i].textTo = undefined;
      moved[i].textBy = undefined;
      moved[i].textListed = undefined;
      i++;
   }
   Equipment.textMoved = [];
};

// The name as the card shows it, in the card's units: its field is taller than its letters, the bottom is where
// the letters end
Equipment.nameBox = function(card)
{
   var field = card.ItemText.ItemTextField;
   var box = Equipment.partBox(card.ItemText, card);
   var bottom;
   if(field == undefined)
   {
      return box;
   }
   bottom = {x:0, y:field._y + field.textHeight + 4};
   card.ItemText.localToGlobal(bottom);
   card.globalToLocal(bottom);
   return {xMin:box.xMin, xMax:box.xMax, yMin:box.yMin, yMax:Math.min(box.yMax, bottom.y)};
};

// the word of a chip in the language of the game
Equipment.chipWord = function(family, key)
{
   var rows = Equipment.CHIP_ROWS[family];
   var g = 0;
   var c;
   while(rows != undefined && g < rows.length)
   {
      c = 0;
      while(c < rows[g].length)
      {
         if(rows[g][c].key == key)
         {
            return Equipment.translated(rows[g][c]);
         }
         c++;
      }
      g++;
   }
   return "";
};

// The words under the name, the kind with a switch of its own. What it's made of stands in the corner of the model's
// room (36-made-of.as)
Equipment.kindLine = function(entry, skill)
{
   return Equipment.lineShown("kind") ? Equipment.kindParts(entry, skill).join(", ") : "";
};

// The kind: the class of a piece and its kind, the hand of a weapon and its kind, the kind of a potion, or the kind
// SkyUI gives everything else. A light or heavy piece is named by the skill the game gives its card, Light Armor or
// Heavy Armor in the game's language, the chip's word alone said only Light
Equipment.kindParts = function(entry, skill)
{
   var type = entry.subTypeDisplay != undefined && entry.subTypeDisplay != "-" ? String(entry.subTypeDisplay) : "";
   var parts = [];
   var keys;
   var i = 0;
   if(entry.formType == Equipment.ARMOR)
   {
      keys = Equipment.isShield(entry) ? (entry.weightClass == 1 ? ["heavy"] : (entry.weightClass == 0 ? ["light"] : [])) : ["light", "heavy", "clothing", "jewelry"];
      while(i < keys.length)
      {
         if(Equipment.isShield(entry) || Equipment.chipHolds(keys[i], entry))
         {
            parts.push((keys[i] == "light" || keys[i] == "heavy") && skill != undefined && String(skill) != "" ? String(skill) : Equipment.chipWord("armor", keys[i]));
            break;
         }
         i++;
      }
   }
   else if(entry.formType == Equipment.WEAPON && !Equipment.ranged(entry) && entry.subType != Equipment.STAFF)
   {
      parts.push(Equipment.chipWord("weapons", Equipment.twoHanded(entry) ? "twoHanded" : "oneHanded"));
   }
   else if(entry.formType == Equipment.POTION && !Equipment.kindHolds("poison", entry) && !Equipment.kindHolds("meal", entry) && !Equipment.kindHolds("drink", entry))
   {
      parts.push(Equipment.translated({words:"$Potion", fallback:"Potion"}));
   }
   if(type != "" && (parts.length == 0 || parts[0] != type))
   {
      parts.push(type);
   }
   return parts;
};

// The material as the item's own keyword names it, Steel Plate, Dragonscale, Draugr Honed or one of a mod. SkyUI 5.2
// names only a family, Steel for all three of steel plate and the Draugr weapons, Dragon for plate, scale and bone.
// SkyUI's word is left for what has no material keyword, the game's own bows and arrows it knows by their forms
Equipment.material = function(entry)
{
   var named = Equipment.keywordMaterial(entry);
   var shown = entry.materialDisplay != undefined ? String(entry.materialDisplay) : "";
   if(named != "" || entry.material == undefined || shown == "")
   {
      return named;
   }
   return shown.charAt(0) == "$" ? Equipment.translated({words:shown, fallback:shown.substr(1)}) : shown;
};

// A material keyword of the game or a mod, ArmorMaterialSteel, DLC2ArmorMaterialStalhrimHeavy,
// ccBGSSSE055_ArmorMaterialOrcishLight. Of a few the one the game has a word for goes first, as SkyUI's own
// translations have Draugr Honed or Morag Tong, the rest by name so the line stays the same on every card
Equipment.keywordMaterial = function(entry)
{
   var names = [];
   var first = "";
   var words;
   var said;
   var i = 0;
   for(var name in entry.keywords)
   {
      names.push(name);
   }
   names.sort();
   while(i < names.length)
   {
      words = Equipment.materialWords(names[i]);
      said = words != "" ? skyui.util.Translator.translate("$" + words) : "";
      if(said != undefined && said != "" && said.charAt(0) != "$")
      {
         return said;
      }
      if(first == "")
      {
         first = words;
      }
      i++;
   }
   return first;
};

// What follows Material in the name of a keyword, word by word: WeapMaterialDraugrHoned is Draugr Honed. Heavy or
// Light and what follows them is the class of the piece, DLC1ArmorMaterielFalmerHeavyOriginal is Falmer (Dawnguard
// spells two of its keywords Materiel). A word with a number is a quest's tag, ArmorMaterialMS02Forsworn is Forsworn.
// The keywords of WACCF for its perks name no material: WAF_ArmorMaterialAdvanced, WAF_MaterialFaction,
// WAF_IgnoreVanillaMaterialKeywordPerks
Equipment.MATERIAL_TAILS = ["Heavy", "Light"];
Equipment.NO_MATERIAL = ["Advanced", "Faction", "Keyword"];
Equipment.materialWords = function(name)
{
   var at = name.indexOf("Material");
   var rest;
   var parts;
   var words = [];
   var i = 0;
   if(at < 0)
   {
      at = name.indexOf("Materiel");
   }
   rest = at >= 0 ? name.substr(at + 8) : "";
   parts = Equipment.capital(rest.charAt(0)) ? Equipment.splitWords(rest) : [];
   while(i < parts.length && !(i > 0 && Equipment.has(Equipment.MATERIAL_TAILS, parts[i])))
   {
      if(!Equipment.hasDigit(parts[i]))
      {
         words.push(parts[i]);
      }
      i++;
   }
   return words.length > 0 && !Equipment.has(Equipment.NO_MATERIAL, words[0]) ? words.join(" ") : "";
};

// The words of a name written in one, SteelPlate is Steel and Plate, TGLinwe is TG and Linwe
Equipment.splitWords = function(text)
{
   var words = [];
   var from = 0;
   var i = 1;
   while(i <= text.length)
   {
      if(i == text.length || Equipment.capital(text.charAt(i)) && (!Equipment.capital(text.charAt(i - 1)) || Equipment.small(text.charAt(i + 1))))
      {
         words.push(text.substring(from, i));
         from = i;
      }
      i++;
   }
   return words;
};

// a letter of any alphabet, a digit is neither capital nor small
Equipment.capital = function(c)
{
   return c != "" && c.toUpperCase() == c && c.toLowerCase() != c;
};

Equipment.small = function(c)
{
   return c != "" && c.toLowerCase() == c && c.toUpperCase() != c;
};

Equipment.hasDigit = function(word)
{
   var i = 0;
   while(i < word.length && (word.charAt(i) < "0" || word.charAt(i) > "9"))
   {
      i++;
   }
   return i < word.length;
};

// The cards of Dear Diary Dark Mode and the menus made on it (Norden UI, Untarnished UI) fit their effects by hand,
// a step of the font smaller at a time until the text is short enough, with no floor. A line for every effect left
// them a text in tiny letters, so such a card gets the effects as the game gives them
Equipment.cardFitsByHand = function()
{
   return typeof Equipment.menu.itemCard.changeTextSize == "function";
};

// One line for every sentence of an enchantment's text when it has more than one, the card then shows each effect
// apart. A sentence ends at a stop followed by a space and a capital or a number, tags of the text left whole
Equipment.effectLines = function(text)
{
   var source = String(text);
   var out = "";
   var tag = false;
   var i = 0;
   var c;
   while(i < source.length)
   {
      c = source.charAt(i);
      tag = c == "<" ? true : (c == ">" ? false : tag);
      out += c;
      if(!tag && (c == "." || c == "!") && source.charAt(i + 1) == " " && Equipment.sentenceStarts(source, i + 2))
      {
         out += "<br>";
         i += 2;
         continue;
      }
      i++;
   }
   return out;
};

Equipment.sentenceStarts = function(source, at)
{
   var c;
   while(source.charAt(at) == "<" && source.indexOf(">", at) > 0)
   {
      at = source.indexOf(">", at) + 1;
   }
   c = source.charAt(at);
   return c != "" && (c >= "0" && c <= "9" || c.toUpperCase() == c && c.toLowerCase() != c);
};

// for tests, the kind line of the selected row, its column of kinds, SkyUI's material, and the text of
// effects the card shows
Equipment.kindReport = function(note)
{
   var card = Equipment.menu.itemCard;
   var entry = Equipment.menu.inventoryLists.itemList.selectedEntry;
   var effects = [];
   var parts = Equipment.shownParts();
   var i = 0;
   while(i < parts.length)
   {
      if(parts[i].text != undefined && parts[i]._name.indexOf("Label") >= 0 && parts[i].text != "")
      {
         effects.push(parts[i]._name + " " + Math.round(parts[i]._height) + " high: " + parts[i].text.split("\r").join(" / "));
      }
      i++;
   }
   var name = Equipment.nameBox(card);
   var field = card.ItemText.ItemTextField;
   skse.Log("PANELTEST kind " + note + ": " + (entry != undefined ? entry.text + " = \"" + Equipment.kindLine(entry) + "\", type " + entry.subTypeDisplay + ", SkyUI's material " + entry.material + " " + entry.materialDisplay + ", shown " + card.equipmentKind._visible + " \"" + card.equipmentKind.text + "\" at " + Math.round(card.equipmentKind._y) : "nothing selected") + "; corner skill \"" + card.SkillTextInstance.text + "\" shown " + card.SkillTextInstance._visible + "; name to " + Math.round(name.yMax) + " (field y " + Math.round(field._y) + " high " + Math.round(field._height) + " text " + Math.round(field.textHeight) + "); effects " + effects.join(" | "));
};

// the card moreHUD Inventory Edition draws beside the SkyUI one, when that mod is there
Equipment.otherCard = function()
{
   var root = Equipment.menu._parent;
   for(var name in root)
   {
      if(root[name].AHZmoreHUDInventory_mc != undefined)
      {
         return root[name].AHZmoreHUDInventory_mc;
      }
   }
   return undefined;
};

// for tests, how the window got its width and how large the card is in it
Equipment.windowSizeReport = function()
{
   var window = Equipment.window;
   var list = Equipment.rowsEdge().wide;
   var card = Equipment.menu.itemCard._parent;
   skse.Log("PANELTEST window size " + Equipment.settings.windowSize + "%: list " + Math.round(list) + ", screen high " + Math.round(Stage.visibleRect.height) + ", window " + Math.round(Equipment.windowWide()) + " wide " + Math.round(window.high) + " high at " + Math.round(window._x) + "," + Math.round(window._y) + ", card " + Math.round(card._yscale) + "%; " + Equipment.edgeReport());
};

// A check by numbers that the card shown now sits inside the window. The first line is the window,
// then one line for every part the card shows, each as left, top, right and bottom in the panel's
// units, with OUT on a part that leaves the window. The card of moreHUD has a line when that mod is
// there, with its edges when it's drawn. The lines are returned, kept in Equipment.cardReported and
// written to the log of SKSE, Equipment.cardOutside is the number of lines with OUT
Equipment.cardReport = function()
{
   var menu = Equipment.menu;
   var window = Equipment.window;
   var card = menu.itemCard;
   var frame = {xMin:window._x, yMin:window._y, xMax:window._x + Equipment.windowWide(), yMax:window._y + window.high};
   var parts = Equipment.shownParts();
   var other = Equipment.otherCard();
   var lines = [];
   var i = 0;

   Equipment.cardOutside = 0;
   lines.push("window " + Equipment.boxLine(frame, frame) + " shown " + window._visible + " frame " + card._currentframe + " type " + card.itemInfo.type);
   lines.push("item " + card.itemInfo.name + " armor " + card.itemInfo.armor + ", numbers " + (window.statLines != undefined ? window.statLines.length : 0) + ", quiet lines \"" + String(window.bodySlots.text).split("\r").join(" / ") + "\"");
   lines.push("card width " + Math.round(Equipment.cardWidth()) + ", frame " + (card.background != undefined ? Equipment.boxLine(card.background.getBounds(card), frame) + " shown " + card.background._visible : "none") + ", card " + Math.round(card._xscale) + "/" + Math.round(card._yscale) + "%, holder " + Math.round(card._parent._xscale) + "/" + Math.round(card._parent._yscale) + "%");
   lines.push("model part " + Math.round(window.preview) + " high, room from " + Math.round(window.previewTop) + ", hole " + (window.hole != undefined ? Math.round(window.hole.left) + "," + Math.round(window.hole.top) + " to " + Math.round(window.hole.right) + "," + Math.round(window.hole.bottom) : "none") + ", see " + window.see);
   lines.push("sheet shown " + window.sheet._visible + " framed " + window.sheet.framed + " at " + Math.round(window.sheet._x) + "," + Math.round(window.sheet._y) + " " + Equipment.boxLine(window.sheet.getBounds(Equipment.under), frame) + " depth " + window.sheet.getDepth() + " of under " + Equipment.under.getDepth() + ", lists " + menu.inventoryLists.getDepth() + ", card " + card._parent.getDepth() + ", words " + Equipment.windowLayer.getDepth() + "; card frame copies " + (card.equipmentFrameFill != undefined) + " own frame shown " + card.background._visible);
   while(i < parts.length)
   {
      lines.push(parts[i]._name + " " + Equipment.boxLine(Equipment.partBox(parts[i], Equipment.under), frame));
      i++;
   }
   if(other != undefined)
   {
      lines.push("moreHUD card kept " + Equipment.cardKept + " swapped " + other._itemCardOverride + " alpha " + other._alpha + (other._alpha > 0 ? " " + Equipment.boxLine(other.getBounds(Equipment.under), frame) : ""));
   }
   lines.push("outside " + Equipment.cardOutside);

   i = 0;
   while(i < lines.length)
   {
      skse.Log("EquipmentPanel card: " + lines[i]);
      i++;
   }
   Equipment.cardReported = lines.join("\n");
   return Equipment.cardReported;
};

Equipment.boxLine = function(box, frame)
{
   var slack = Equipment.FIT_SLACK;
   var fits = box.xMin >= frame.xMin - slack && box.yMin >= frame.yMin - slack && box.xMax <= frame.xMax + slack && box.yMax <= frame.yMax + slack;
   if(!fits)
   {
      Equipment.cardOutside++;
   }
   return Equipment.tenth(box.xMin) + " " + Equipment.tenth(box.yMin) + " " + Equipment.tenth(box.xMax) + " " + Equipment.tenth(box.yMax) + (fits ? "" : " OUT");
};

Equipment.tenth = function(value)
{
   return Math.round(value * 10) / 10;
};

Equipment.everyFrame = function()
{
   Equipment.fitFollowers();
   Equipment.dragFrame();
   Equipment.lensWaitFrame();
   Equipment.windowRestFrame();
   Equipment.watchPieces();
   Equipment.sendEyes();
   Equipment.keepFrameHidden();
   Equipment.watchOverlays();
};

// The window is the frame of the card. A reskin can fill the card by a way of its own and put the card's frame
// back up with it, Vel'dun UI does for the first card of a menu, so the frame is kept down while the window is up
Equipment.keepFrameHidden = function()
{
   if(Equipment.window._visible && !Equipment.leavesCard())
   {
      Equipment.menu.itemCard.background._visible = false;
   }
};
