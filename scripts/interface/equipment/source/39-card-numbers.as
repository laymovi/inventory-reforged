Equipment.CARD_NUMBERS_MARGIN = 8;
Equipment.CHEST_SCROLL_LINES = 3;
Equipment.CHEST_BAR = 3;
// The numbers take their sizes from the card's own letters: names as its labels, numbers a little smaller than its
// big values, the quiet lines a little smaller than its words. A card without one of them gets these, in the panel's
// units
Equipment.CHEST_VALUE_SHARE = 0.7;
Equipment.CHEST_QUIET_SHARE = 0.9;
Equipment.CHEST_TEXT = 20;
Equipment.CHEST_LABEL = 17;
Equipment.CHEST_QUIET = 18;
Equipment.CHEST_LINE = 27;
Equipment.CHEST_RELAYS = 3;
Equipment.CHEST_GAP = 14;
// the most of the line the names may take, the numbers keep the rest
Equipment.CHEST_NAMES_SHARE = 0.55;
Equipment.CHEST_BELOW = 16;
// the frame's bottom edge that moves down under the numbers with its ornaments, and the plain slice that fills between
Equipment.CHEST_KEEP = 30;
Equipment.CHEST_SLICE = 4;
// how many frames after a layout the card's frame is watched for a skin still bringing it in
Equipment.CHEST_SETTLE = 12;
Equipment.LOWEST_DEPTH = -16384;

// In a chest or a shop the numbers of the item window go into SkyUI's own card: right under its words, in its
// letters, and the card's frame grows down to hold them, the way SkyUI grows it for a longer card. The card keeps its
// place and its look, the game's model stays where SkyUI shows it. Down to the bottom bar or the screen's edge the
// frame grows, past that the numbers scroll by the wheel. The numbers live inside the card, so they move, fade and
// take a skin's colours with it. It follows the selected row and is measured a frame later, when the card has its
// new size
Equipment.startCardNumbers = function()
{
   var menu = Equipment.menu;
   var card = menu.itemCard;
   var box;
   if(card == undefined)
   {
      return undefined;
   }
   box = card.createEmptyMovieClip("equipmentCardNumbers", card.getNextHighestDepth());
   box.createEmptyMovieClip("numbers", 1);
   box.createEmptyMovieClip("mask", 2);
   box.createEmptyMovieClip("bar", 3);
   box.createEmptyMovieClip("settle", 4);
   box.numbers.createTextField("names", 1, 0, 0, 10, 10);
   box.numbers.createTextField("quiet", 2, 0, 0, 10, 10);
   box.names = box.numbers.names;
   box.quiet = box.numbers.quiet;
   Equipment.styleText(box.names, Equipment.CHEST_TEXT, "left", Equipment.inkOf("name"));
   Equipment.styleText(box.quiet, Equipment.CHEST_QUIET, "left", Equipment.inkOf("quiet"));
   box.names.multiline = box.quiet.multiline = true;
   box.names.wordWrap = false;
   box.names.html = true;
   box.quiet.wordWrap = true;
   box.quiet.autoSize = "left";
   box.numbers.setMask(box.mask);
   box.hitTestDisable = true;
   box._visible = false;
   box.scrolled = 0;
   Equipment.cardNumbers = box;
   Equipment.chestWheel = {};
   Equipment.chestWheel.onMouseWheel = function(delta)
   {
      Equipment.scrollCardNumbers(delta);
   };
   Mouse.addListener(Equipment.chestWheel);
   menu.inventoryLists.addEventListener("itemHighlightChange", Equipment, "cardNumbersLater");
   menu.inventoryLists.addEventListener("hideItemsList", Equipment, "cardNumbersLater");
   menu.itemCard.addEventListener("subMenuAction", Equipment, "cardAsks");
   // The game fills the card on its own too, after a sale or when a count changes. Another kind of card brings a new
   // frame of SkyUI's that knew nothing of the numbers, and the frame laid out for the last one stayed beside it
   Equipment.numbersFollowCardInfo(menu);
   // a description Description Framework hands the card a frame later grows the card's words down now, the numbers
   // under them were laid out without it and lay over its last lines
   Equipment.watchCardInfo(card, Equipment.cardNumbersLater);
};

Equipment.numbersFollowCardInfo = function(menu)
{
   menu.equipmentCardInfo = menu.UpdateItemCardInfo;
   menu.UpdateItemCardInfo = function(info)
   {
      Equipment.cardInfoUnder(this, "equipmentCardInfo", info);
      Equipment.cardNumbersLater();
   };
   Equipment.cardInfoTop = menu.UpdateItemCardInfo;
};

// While the card asks how many its Yes and No sit lower than the item's own lines, the card stays as SkyUI made it
Equipment.cardAsks = function(event)
{
   Equipment.cardAsking = event.opening == true;
   Equipment.cardStamp = Equipment.number(Equipment.cardStamp) + 1;
   Equipment.holdRows(Equipment.cardAsking);
   if(Equipment.cardAsking)
   {
      Equipment.cardNumbers._visible = false;
      Equipment.showCardNumbers();
   }
   else
   {
      Equipment.cardNumbersLater();
   }
};

// SkyUI keeps the rows still while the card asks how many, the menus of some skins don't. A row the pointer
// crossed on its way to the slider took the card, and the question went to that item. The inspect view and the
// look sheet hold them too, a letting go of one keeps them held while another still lies over them
Equipment.holdRows = function(asked)
{
   var lists = Equipment.menu.inventoryLists;
   var held = asked || Equipment.inspecting == true || Equipment.cardAsking == true || Equipment.look != undefined && Equipment.look._visible == true ||
      Equipment.junkAsk != undefined && Equipment.junkAsk._visible == true || Equipment.contextHoldsRows == true;
   lists.itemList.disableSelection = lists.itemList.disableInput = held;
   lists.categoryList.disableSelection = lists.categoryList.disableInput = held;
};

Equipment.cardNumbersLater = function()
{
   var box = Equipment.cardNumbers;
   if(box == undefined)
   {
      return undefined;
   }
   box.onEnterFrame = function()
   {
      this.onEnterFrame = undefined;
      Equipment.showCardNumbers();
   };
};

// The card's frame as SkyUI drew it: the pieces of a longer frame go and SkyUI's own frame shows again
Equipment.cardFrameAsSkyUI = function(back)
{
   var card = Equipment.menu.itemCard;
   var names = ["equipmentFrameTop", "equipmentFrameFill", "equipmentFrameBottom", "equipmentFrameTopMask", "equipmentFrameFillMask", "equipmentFrameBottomMask"];
   var i = 0;
   if(back != undefined && Equipment.cardBackHidden)
   {
      back._visible = true;
   }
   Equipment.cardBackHidden = false;
   // the size SkyUI gave it lives on the frame itself: a frame SkyUI put up anew for another kind of card has the
   // same name, and a reference kept anywhere else would lead to the new one. A grid of the panel's own goes first,
   // the frame then takes its height back whole
   if(back != undefined && back.equipmentGrid != undefined)
   {
      if(back.equipmentGrid.own == true)
      {
         back.scale9Grid = null;
      }
      back._height = back.equipmentGrid.high;
      back._y = back.equipmentGrid.y;
      back.equipmentGrid = undefined;
   }
   // A picture loaded into the frame (Norden UI's, loadMovie in the frame's own clip) comes a frame or two after the
   // card: the first layout grew the frame's stand-in, and the picture wiped what was written on the frame but kept its
   // scale. It came in stretched whole and never got its size back. The panel keeps the frame's scale too, for the kind
   // it grew, and gives it back by scale
   else if(back != undefined && Equipment.gridFrame != undefined && card._currentframe == Equipment.gridFrame.frame)
   {
      if(Equipment.gridFrame.own == true)
      {
         back.scale9Grid = null;
      }
      back._yscale = Equipment.gridFrame.yscale;
      back._y = Equipment.gridFrame.y;
   }
   Equipment.gridFrame = undefined;
   Equipment.unstretchFrame(back);
   // The skin's picture is kept by a reference, it goes back only while the card shows the kind it was grown on. Its
   // size goes back by scale, a picture loaded into the frame tells a height of its own way
   if(Equipment.skinArt != undefined && card._currentframe == Equipment.skinArtFrame)
   {
      Equipment.skinArt.scale9Grid = null;
      Equipment.skinArt._yscale = Equipment.skinArtScale;
      Equipment.skinArt._y = Equipment.skinArtY;
   }
   Equipment.skinArt = undefined;
   while(i < names.length)
   {
      if(card[names[i]] != undefined)
      {
         // a clip under the card's own parts can't be removed from there
         card[names[i]].swapDepths(card.getNextHighestDepth());
         card[names[i]].removeMovieClip();
      }
      i++;
   }
};

// the lowest depth of the card's own parts, the top piece of a longer frame goes under all of them
Equipment.lowestDepth = function(card)
{
   var lowest;
   for(var name in card)
   {
      if(card[name]._parent == card && card[name].getDepth != undefined)
      {
         lowest = lowest == undefined ? card[name].getDepth() : Math.min(lowest, card[name].getDepth());
      }
   }
   return lowest;
};

// Where the pieces of a longer frame go, in the card's units. The frame is cut under the card's words: above the cut
// it stays as it is, its last keep units (the bottom edge with its ornaments) move down till the frame ends at
// bottom, and the space between is a thin slice of the frame just under the cut stretched to fill it. A skin's bands
// and corners keep their size that way, only a plain strip grows. Nothing moves when the frame already reaches bottom
Equipment.framePieces = function(art, cut, bottom, keep, slice)
{
   var kept = Math.min(keep, Math.max(0, art.yMax - cut));
   var bottomFrom = art.yMax - kept;
   var pieces = {bottomFrom:bottomFrom, shift:Math.max(0, bottom - art.yMax), rise:0};
   // the slice comes from under the cut, or from just above it when the frame keeps nothing between
   pieces.sliceHigh = Math.min(slice, bottomFrom - cut);
   pieces.sliceTop = cut;
   if(pieces.sliceHigh < 1)
   {
      pieces.sliceHigh = slice;
      pieces.sliceTop = cut - slice;
   }
   pieces.fillHigh = bottomFrom + pieces.shift - cut;
   return pieces;
};

// Lays the longer frame out from three copies of SkyUI's own frame, each under a mask, and hides the frame itself. A
// mask set on the frame of some skins doesn't take and shows as a black box, on a copy it does. A copy is born at
// its own scale, it's laid over the frame by its bounds first. A frame that rises keeps the top edge's size too and
// moves it up by pieces.rise, the slice then reaches up to it. Only the top piece fits under the card's words, a
// slice that runs past the words shows only its sides (that many units of each) so it never lies over them.
// Tells whether the copies took
Equipment.frameCopies = function(card, back, art, cut, pieces, sides)
{
   var top;
   var fill;
   var bottom;
   var stretch = pieces.fillHigh / pieces.sliceHigh;
   var under = Equipment.lowestDepth(card) - 1;
   var from = cut - pieces.rise;
   top = back.duplicateMovieClip("equipmentFrameTop", card.getNextHighestDepth());
   fill = back.duplicateMovieClip("equipmentFrameFill", card.getNextHighestDepth());
   bottom = back.duplicateMovieClip("equipmentFrameBottom", card.getNextHighestDepth());
   // A skin that keeps its picture in clips of its own inside the frame gets copies without them, empty or half
   // drawn, and it draws that frame by its own code. Such a frame stays as the skin made it. AS2 builds >= as
   // "not <", which holds for a missing number, a card with no parts gives one here
   if(top == undefined || fill == undefined || bottom == undefined || !(under > Equipment.LOWEST_DEPTH - 1) || Equipment.partCount(fill) < Equipment.partCount(back))
   {
      Equipment.cardFrameAsSkyUI(back);
      return false;
   }
   // the top piece lies where the frame lay, under the card's words. The other two are drawn only under the words
   top.swapDepths(under);
   Equipment.layOver(top, back, art);
   Equipment.layOver(fill, back, art);
   Equipment.layOver(bottom, back, art);
   // a picture loaded into the frame or drawn there by code doesn't come with a copy, the copy has nothing to show
   if(!Equipment.laidOver(top, art) || !Equipment.laidOver(fill, art) || !Equipment.laidOver(bottom, art))
   {
      Equipment.cardFrameAsSkyUI(back);
      return false;
   }
   top._y -= pieces.rise;
   // the slice's top lands on the cut and the slice reaches the moved bottom edge
   fill._y = from - (pieces.sliceTop - fill._y) * stretch;
   fill._yscale *= stretch;
   bottom._y += pieces.shift;
   top.setMask(Equipment.frameMask(card, "equipmentFrameTopMask", art, art.yMin - pieces.rise - 1, from));
   fill.setMask(Equipment.frameMask(card, "equipmentFrameFillMask", art, from, from + pieces.fillHigh, sides));
   bottom.setMask(Equipment.frameMask(card, "equipmentFrameBottomMask", art, pieces.bottomFrom + pieces.shift, art.yMax + pieces.shift + 1));
   back._visible = false;
   Equipment.cardBackHidden = true;
   return true;
};

// SkyUI draws its card's frame with a nine-slice grid and makes it longer for a longer card by its height alone: the
// edges and corners keep their size and only the plain middle stretches. A frame with a grid of its own grows that way
// too, so its bottom edge goes down whole under the numbers even when the card's words reach into it. Cut copies left
// half of that edge where the words ended and the corners showed twice. A frame that didn't take the new height stays
// as it was, so does one that keeps nothing written on it, its size couldn't be given back.
// A frame that draws its picture itself and has no grid gets one of the panel's at the slice when the card's words
// reach past where the frame can be cut. Copies would lay their slice over the words, the frame itself lies under them
// (Nordic UI's enchanted armor, seven effects at 100% ran past its frame)
Equipment.growByGrid = function(card, back, pieces)
{
   var was = back.getBounds(card);
   var own = back.scale9Grid == undefined;
   var inside;
   var top;
   var low;
   if(!(was.yMax > was.yMin) || own && (pieces.underWords != true || Equipment.partCount(back) > 0 || Equipment.framePicture(back) != undefined || flash.geom.Rectangle == undefined))
   {
      return false;
   }
   back.equipmentGrid = {high:back._height, y:back._y, own:own};
   if(back.equipmentGrid == undefined)
   {
      return false;
   }
   Equipment.gridFrame = {yscale:back._yscale, y:back._y, own:own, frame:card._currentframe};
   if(own)
   {
      inside = back.getBounds(back);
      top = {x:0, y:pieces.sliceTop};
      low = {x:0, y:pieces.sliceTop + pieces.sliceHigh};
      card.localToGlobal(top);
      card.localToGlobal(low);
      back.globalToLocal(top);
      back.globalToLocal(low);
      back.scale9Grid = new flash.geom.Rectangle(inside.xMin + 1, top.y, inside.xMax - inside.xMin - 2, low.y - top.y);
   }
   back._height += pieces.shift;
   back._y += was.yMin - back.getBounds(card).yMin;
   if(!Equipment.sameEdge(back.getBounds(card).yMax, was.yMax + pieces.shift))
   {
      Equipment.cardFrameAsSkyUI(back);
      return false;
   }
   return true;
};

Equipment.growCardFrame = function(card, back, art, cut, pieces)
{
   if(!Equipment.frameCopies(card, back, art, cut, pieces))
   {
      return false;
   }
   Equipment.cardNumbers.swapDepths(card.getNextHighestDepth());
   // a skin whose code shows its frame again keeps its frame as it made it from then on
   card.equipmentFrameTopMask.onEnterFrame = function()
   {
      this.onEnterFrame = undefined;
      // a new row on its way is laid out anew anyway, SkyUI may show the frame for it
      if(back._visible && Equipment.cardBackHidden && Equipment.cardNumbers.onEnterFrame == undefined)
      {
         Equipment.frameOfSkin = true;
         Equipment.showCardNumbers();
      }
   };
   return true;
};

// The frame of a skin that draws it by code keeps its picture in a clip inside, the tallest one when there are a few.
// That clip grows by its own nine-slice grid: everything above the slice under the cut and everything below it keeps
// its size, only the slice stretches. A clip grows from its own origin, the picture is moved back so its top stays.
// It grows by its scale to the height measured, a picture loaded into the frame (Norden UI's) tells a height of its
// own way and kept growing past what the card asked
Equipment.growSkinFrame = function(card, back, pieces)
{
   var art = Equipment.framePicture(back);
   var own;
   var top;
   var low;
   var was;
   var high;
   if(art == undefined || flash.geom.Rectangle == undefined)
   {
      Equipment.skinGrowth = art == undefined ? "no picture clip in the frame" : "no Rectangle";
      return false;
   }
   own = art.getBounds(art);
   top = {x:0, y:pieces.sliceTop};
   low = {x:0, y:pieces.sliceTop + pieces.sliceHigh};
   card.localToGlobal(top);
   card.localToGlobal(low);
   art.globalToLocal(top);
   art.globalToLocal(low);
   if(!(low.y > top.y) || top.y <= own.yMin || low.y >= own.yMax)
   {
      Equipment.skinGrowth = "slice " + Math.round(top.y) + "-" + Math.round(low.y) + " outside the picture " + Math.round(own.yMin) + "-" + Math.round(own.yMax);
      return false;
   }
   Equipment.skinArt = art;
   Equipment.skinArtScale = art._yscale;
   Equipment.skinArtY = art._y;
   Equipment.skinArtFrame = card._currentframe;
   was = art.getBounds(back).yMin;
   high = art.getBounds(card).yMax - art.getBounds(card).yMin;
   art.scale9Grid = new flash.geom.Rectangle(own.xMin + 1, top.y, own.xMax - own.xMin - 2, low.y - top.y);
   art._yscale *= (high + pieces.shift) / high;
   art._y += was - art.getBounds(back).yMin;
   Equipment.skinGrowth = "grown by " + Math.round(pieces.shift) + ", picture " + Math.round(high) + " to " + Math.round(art.getBounds(card).yMax - art.getBounds(card).yMin) + ", grid " + (art.scale9Grid != undefined);
   return true;
};

// The picture a skin keeps in a clip of its own inside the frame, the tallest when there are a few. A picture loaded
// into the frame (Norden UI's) keeps its clip on the loaded movie's timeline under no name of its own, it isn't always
// listed and is found by its depth there. Nothing for a frame that draws its picture itself
Equipment.PICTURE_DEPTHS = 8;
Equipment.framePicture = function(back)
{
   var art;
   var clip;
   var depth = Equipment.LOWEST_DEPTH;
   for(var name in back)
   {
      if(typeof back[name] == "movieclip" && name.indexOf("equipment") != 0 && (art == undefined || back[name]._height > art._height))
      {
         art = back[name];
      }
   }
   while(art == undefined && back.getInstanceAtDepth != undefined && depth < Equipment.LOWEST_DEPTH + Equipment.PICTURE_DEPTHS)
   {
      clip = back.getInstanceAtDepth(depth);
      if((typeof clip == "movieclip" || clip instanceof MovieClip) && clip._parent == back)
      {
         art = clip;
      }
      depth++;
   }
   return art;
};

// A frame that is one plain picture with nothing inside, which neither copies nor a grid can grow (Dragonborn UI's dark
// box, its copies came out empty), is stretched to the new bottom, its rough edges take it. A frame with parts of its
// own keeps them as they are.
// It's stretched by its scale to the height measured, and what it was is kept with the panel: a picture loaded into the
// frame (Norden UI's) may keep nothing written on it, never got its size back and grew again with every layout
Equipment.stretchPlainFrame = function(card, back, pieces)
{
   var was = back.getBounds(card);
   if(Equipment.partCount(back) > 0 || !(was.yMax > was.yMin))
   {
      return false;
   }
   Equipment.plainFrame = {yscale:back._yscale, y:back._y, frame:card._currentframe};
   back._yscale *= (was.yMax - was.yMin + pieces.shift) / (was.yMax - was.yMin);
   back._y += was.yMin - back.getBounds(card).yMin;
   Equipment.plainFrame.grown = back._yscale;
   return true;
};

// the plain frame stretched gets its size back, only the one stretched: the card on another kind has a new frame
Equipment.unstretchFrame = function(back)
{
   var stretched = Equipment.plainFrame;
   Equipment.plainFrame = undefined;
   if(back == undefined || stretched == undefined || Equipment.menu.itemCard._currentframe != stretched.frame || Math.abs(back._yscale - stretched.grown) > stretched.grown / 1000)
   {
      return undefined;
   }
   back._yscale = stretched.yscale;
   back._y = stretched.y;
};

Equipment.partCount = function(clip)
{
   var count = 0;
   for(var name in clip)
   {
      if(typeof clip[name] == "movieclip" || clip[name] instanceof TextField)
      {
         count++;
      }
   }
   return count;
};

// a copy of the frame put exactly where the frame is, by their bounds in the card
Equipment.layOver = function(copy, back, art)
{
   var card = copy._parent;
   var now;
   copy.gotoAndStop(back._currentframe);
   copy._xscale = back._xscale;
   copy._yscale = back._yscale;
   now = copy.getBounds(card);
   if(now.yMax - now.yMin > 0 && now.xMax - now.xMin > 0)
   {
      copy._yscale *= (art.yMax - art.yMin) / (now.yMax - now.yMin);
      copy._xscale *= (art.xMax - art.xMin) / (now.xMax - now.xMin);
   }
   now = copy.getBounds(card);
   copy._x += art.xMin - now.xMin;
   copy._y += art.yMin - now.yMin;
};

Equipment.laidOver = function(copy, art)
{
   var now = copy.getBounds(copy._parent);
   return Equipment.sameEdge(now.xMin, art.xMin) && Equipment.sameEdge(now.xMax, art.xMax) && Equipment.sameEdge(now.yMin, art.yMin) && Equipment.sameEdge(now.yMax, art.yMax);
};

// two edges a unit apart at most. Never for a missing number: in AS2 a <= b with NaN is true, a < b and == are false
Equipment.sameEdge = function(a, b)
{
   var apart = Math.abs(a - b);
   return apart < 1 || apart == 1;
};

// a mask over the frame from top to low, or over its two sides only, that many units of each
Equipment.frameMask = function(card, name, art, top, low, sides)
{
   var mask = card.createEmptyMovieClip(name, card.getNextHighestDepth());
   if(sides == undefined)
   {
      Equipment.maskBox(mask, art.xMin - 2, top, art.xMax + 2, low);
   }
   else
   {
      Equipment.maskBox(mask, art.xMin - 2, top, art.xMin + sides, low);
      Equipment.maskBox(mask, art.xMax - sides, top, art.xMax + 2, low);
   }
   return mask;
};

Equipment.maskBox = function(mask, left, top, right, low)
{
   mask.beginFill(0, 100);
   mask.moveTo(left, top);
   mask.lineTo(right, top);
   mask.lineTo(right, low);
   mask.lineTo(left, low);
   mask.lineTo(left, top);
   mask.endFill();
};

Equipment.showCardNumbers = function()
{
   var box = Equipment.cardNumbers;
   var menu = Equipment.menu;
   var card = menu.itemCard;
   var back = card != undefined ? card.background : undefined;
   var entry = menu.inventoryLists.itemList.selectedEntry;
   var lines = entry != undefined && Equipment.settings.stats ? Equipment.statsOf(entry) : [];
   var quiet = entry != undefined ? Equipment.quietLines(entry) : [];
   var frame;
   var inPanel;
   var unit;
   var pad;
   var art;
   var cut;
   var keep;
   var pieces;
   var below;
   var limit;
   var shown;
   var numbersHigh;
   var letters;
   var wordsOnly;
   var steal;
   var under;
   if(box == undefined || back == undefined)
   {
      return undefined;
   }
   steal = Equipment.stealLine(card);
   // the window of Details took the card, it lays the card out itself until the card goes home
   if(Equipment.cardBorrowed)
   {
      box._visible = false;
      return undefined;
   }
   Equipment.cardLayouts = Equipment.number(Equipment.cardLayouts) + 1;
   // what the last item grew goes back first, a card that shows no numbers now keeps none of it
   Equipment.unsizeCardText();
   Equipment.keepCard();
   Equipment.cardFrameAsSkyUI(back);
   frame = Equipment.frameBox(card, card);
   inPanel = Equipment.frameBox(card, Equipment.under);
   // a frame with no width yet gives the card's unit no number, everything laid out by it would be
   // lost. A slot's window over the inventory holds the numbers itself
   if(entry == undefined || frame == undefined || inPanel == undefined || !(inPanel.xMax - inPanel.xMin > 0) || !(frame.xMax - frame.xMin > 0) || Equipment.cardAsking || Equipment.cardBox() == undefined || Equipment.anchorSlot != undefined)
   {
      box._visible = false;
      return undefined;
   }
   Equipment.noteFrameDrawn(card, back);
   // the card's name and words at the sizes the player set, the numbers then go under the words as they grew
   Equipment.sizeCardText();
   // the card's units for every length, a skin may scale its card
   unit = (frame.xMax - frame.xMin) / (inPanel.xMax - inPanel.xMin);
   pad = Equipment.STATS_PAD * unit;
   // names like the card's labels, numbers like its values, the quiet lines like its words, all from the left edge
   // of its labels. A name and its number share a line of one field, so the rows keep one height
   letters = Equipment.wearCardLetters(box, frame, unit);
   box.names._x = box.quiet._x = letters.left;
   box.names._width = box.quiet._width = frame.xMax - pad - letters.left;
   box.names._y = 0;
   numbersHigh = Equipment.layCardNumbers(box, letters, lines, quiet, unit, Equipment.textShare("card"));
   // A card with no numbers still grows its frame round words that reach its bottom edge: a description a mod gives the
   // card a frame later and the player's size of the words ran out of the frame. Words that keep the frame's margin leave
   // it as the UI drew it
   wordsOnly = lines.length == 0 && quiet.length == 0;
   if(wordsOnly)
   {
      numbersHigh = 0;
   }

   // the frame as drawn, a skin's picture may reach past the box it counts as the frame
   art = back.getBounds(card);
   // the last line ends this far above the frame's bottom, its ornaments sit in the corners beside it. A skin's
   // picture can have a clear margin round the frame, the line keeps its distance from what shows
   below = Equipment.CHEST_BELOW * unit + Math.max(0, art.yMax - frame.yMax);
   // the line of a pickpocket under the frame keeps its room down to the bottom bar
   under = Equipment.stealRoom(card, steal, art);
   Equipment.numbersUnderWords(box, frame, unit, wordsOnly);
   limit = Equipment.roomUnderWords(box, frame, unit, numbersHigh + below + under, wordsOnly) - under;
   // Numbers that still don't fit with the card gone up as far as it goes and its words down to three lines, or that are
   // too wide for it, come down in size. The words then keep what the smaller numbers leave them
   if(!wordsOnly && (!box.across || Equipment.pastLimit(box.numbersTop + numbersHigh + below, limit)) && Equipment.textShare("card") > 1)
   {
      numbersHigh = Equipment.fitCardNumbers(box, letters, lines, quiet, unit, limit - below - box.numbersTop);
      Equipment.uncutWords();
      Equipment.numbersUnderWords(box, frame, unit, wordsOnly);
      limit = Equipment.roomUnderWords(box, frame, unit, numbersHigh + below + under, wordsOnly) - under;
   }
   // and when even the numbers at their least don't fit, the words give lines down to one so every number stays in sight
   if(!wordsOnly && Equipment.pastLimit(box.numbersTop + numbersHigh + below, limit))
   {
      limit = Equipment.roomUnderWords(box, frame, unit, numbersHigh + below + under, wordsOnly, 1) - under;
   }
   // The frame is cut under the words, never into its bottom edge and the slice above it. Words longer than the frame
   // SkyUI drew left the cut past its bottom: the slice of a longer frame came from outside its picture and the edge
   // never moved down, the numbers stood under the frame (Nordic UI's enchanted armor at 100%)
   cut = Math.max(art.yMin, Math.min(box.wordsEnd + pad / 4, art.yMax - (Equipment.CHEST_KEEP + Equipment.CHEST_SLICE) * unit));
   keep = Math.min(Equipment.CHEST_KEEP * unit, Math.max(0, art.yMax - cut));
   Equipment.placeShopModel(card);
   shown = Equipment.shownLines(box, numbersHigh, limit - below);
   pieces = Equipment.framePieces(art, cut, box.numbersTop + shown + below, keep, Equipment.CHEST_SLICE * unit);
   pieces.underWords = cut < box.wordsEnd;
   Equipment.cardFrameWay = "as drawn";
   if(pieces.shift > 0)
   {
      // copies lie over the card's parts, only the top one finds a depth under them, so a cut above the words' end
      // takes none
      if(Equipment.growByGrid(card, back, pieces))
      {
         Equipment.cardFrameWay = back.equipmentGrid.own == true ? "a grid of the panel's" : "the skin's grid";
      }
      else if(!Equipment.frameOfSkin && !pieces.underWords && Equipment.growCardFrame(card, back, art, cut, pieces))
      {
         Equipment.cardFrameWay = "copies";
      }
      else if(Equipment.growSkinFrame(card, back, pieces))
      {
         Equipment.frameOfSkin = true;
         Equipment.cardFrameWay = "the skin's picture";
      }
      else if(Equipment.stretchPlainFrame(card, back, pieces))
      {
         Equipment.cardFrameWay = "stretched whole";
      }
      else
      {
         // a frame that can't grow holds what fits in it, the rest scrolls
         shown = Equipment.shownLines(box, numbersHigh, art.yMax - below);
         Equipment.cardFrameWay = "can't grow";
         pieces.grew = false;
      }
      Equipment.cardFrameWay += " by " + Math.round(pieces.shift) + " from " + Math.round(art.yMin) + "-" + Math.round(art.yMax) + ", cut " + Math.round(cut) + (pieces.underWords ? " over the words' end " + Math.round(box.wordsEnd) : "");
   }
   if(steal != undefined && under > 0 && pieces.grew != false)
   {
      steal._y = steal.equipmentHomeY + pieces.shift * card._yscale / 100;
   }
   // A skin may still be bringing its card in, its frame changing size: then it's all laid out again. The frame is
   // measured as it came out, a grown picture that missed the bottom it was meant for would lay the card out every frame
   box.settle.frames = Equipment.CHEST_SETTLE;
   box.settle.low = back.getBounds(card).yMax;
   // a picture loaded into the frame comes a moment later and takes the frame's place, the card is laid out again for it
   box.settle.url = back._url;
   // a skin may put the picture into its frame a moment after the card changed
   box.settle.wantsPicture = Equipment.frameOfSkin && pieces.shift > 0 && Equipment.skinArt == undefined && Equipment.partCount(back) == 0;
   box.settle.onEnterFrame = function()
   {
      var back = Equipment.menu.itemCard.background;
      if(--this.frames <= 0 || back == undefined)
      {
         this.onEnterFrame = undefined;
      }
      else if((Math.abs(back.getBounds(back._parent).yMax - this.low) > 1 || this.wantsPicture && Equipment.partCount(back) > 0 || back._url != this.url) && Equipment.cardNumbers.onEnterFrame == undefined && !Equipment.cardBackHidden)
      {
         this.onEnterFrame = undefined;
         // a skin that draws its frame anew every frame would have the card laid out every frame, a few times an item
         if(Equipment.cardNumbers.relaidEntry != Equipment.cardNumbers.entry)
         {
            Equipment.cardNumbers.relaidEntry = Equipment.cardNumbers.entry;
            Equipment.cardNumbers.relaid = 0;
         }
         if(++Equipment.cardNumbers.relaid <= Equipment.CHEST_RELAYS)
         {
            Equipment.showCardNumbers();
         }
      }
   };
   box.shown = shown;
   box.left = frame.xMin;
   box.right = frame.xMax;
   box.unit = unit;
   box.scrollMost = Math.max(0, Math.ceil((numbersHigh - shown) / box.rowHigh) * box.rowHigh);
   if(entry != box.entry)
   {
      box.entry = entry;
      box.scrolled = 0;
   }
   box.mask.clear();
   box.mask.beginFill(0, 100);
   box.mask.moveTo(frame.xMin, box.numbersTop);
   box.mask.lineTo(frame.xMax, box.numbersTop);
   box.mask.lineTo(frame.xMax, box.numbersTop + shown);
   box.mask.lineTo(frame.xMin, box.numbersTop + shown);
   box.mask.lineTo(frame.xMin, box.numbersTop);
   box.mask.endFill();
   Equipment.scrollCardNumbers(0);
   box._visible = !wordsOnly;
   // the card in the character's room may have gone up, its model takes the room left above it
   if(Equipment.plugin() != undefined && !Equipment.inspecting)
   {
      Equipment.placeRoomModel();
   }
};

// The game's line of a pickpocket (29% TO STEAL) stands in the card's holder under SkyUI's frame, at a place of its
// own. The frame grown for the numbers went over it (the line written by Pickpocket Chance Rework). It's put back home
// before each layout and keeps its distance under the grown frame after it. Nothing when it's off
Equipment.stealLine = function(card)
{
   var line = card._parent.StealTextInstance;
   if(line == undefined)
   {
      return undefined;
   }
   if(line.equipmentHomeY == undefined)
   {
      line.equipmentHomeY = line._y;
   }
   line._y = line.equipmentHomeY;
   return line._visible && line._alpha > 0 ? line : undefined;
};

// How far the line of a pickpocket reaches under the frame's bottom edge, in the card's units. A line of a skin that
// stands beside the card or over its frame keeps its place and takes no room
Equipment.stealRoom = function(card, line, art)
{
   var box;
   if(line == undefined || !(card._yscale > 0))
   {
      return 0;
   }
   box = line.getBounds(card);
   if(!(box.yMax > box.yMin) || box.yMin < art.yMax || box.xMax < art.xMin || box.xMin > art.xMax)
   {
      return 0;
   }
   return box.yMax - art.yMax;
};

// Where the numbers start, under the card's words. Under a description the quest line read as its next
// line, a paragraph gets a gap before them. box.wordsEnd keeps where the words end
Equipment.numbersUnderWords = function(box, frame, unit, wordsOnly)
{
   var words = Equipment.cardWordsBottom(frame.yMax, Equipment.menu.itemCard);
   box.wordsEnd = words;
   box.numbersTop = wordsOnly ? words : words + Equipment.STATS_PAD * unit / 2 + (Equipment.cardWordsWrap ? Equipment.CHEST_GAP * unit : 0);
};

// The card goes up for what lies under its words (needs, in its units). When it stops short the words keep the lines
// that fit and scroll, never under least of them (36-long-words.as). Tells how low the card may reach now
Equipment.roomUnderWords = function(box, frame, unit, needs, wordsOnly, least)
{
   var card = Equipment.menu.itemCard;
   var limit = Equipment.raiseRoomCard(card, box.numbersTop + needs, unit);
   if(Equipment.pastLimit(box.numbersTop + needs, limit) && Equipment.cutWords(box.numbersTop + needs - limit, least) > 0)
   {
      Equipment.numbersUnderWords(box, frame, unit, wordsOnly);
      limit = Equipment.raiseRoomCard(card, box.numbersTop + needs, unit);
   }
   return limit;
};

// Whether what the card needs reaches past its limit. A card gone up just as far as it needs came back a hair short of
// it, its place goes by twips and the lengths summed lose a little, and its last row of numbers went to the scroll
Equipment.pastLimit = function(needs, limit)
{
   return needs > limit + Equipment.FIT_SLACK;
};

// The card left in the UI's place over the character has the empty room above it, so a card longer than the room
// below goes up into it, as far as the room's top. A card in a skin's place in a chest or a shop does the same up to
// the screen's top, Dragonborn UI and Edge UI keep it so low over their bottom bar that one line of three showed.
// Each item starts from the skin's own place, SkyUI's card fits there and stays. Tells how low the card may reach
// now, in its units
Equipment.raiseRoomCard = function(card, needs, unit)
{
   var holder = card._parent;
   var inRoom = Equipment.cardInRoom();
   var limit;
   var from;
   var to;
   var room;
   var top;
   var up;
   Equipment.cardRaised = false;
   if(Equipment.cardBorrowed || inRoom && Equipment.stage == undefined)
   {
      return Equipment.cardBottomLimit(card, unit);
   }
   if(Equipment.roomCardY == undefined)
   {
      Equipment.roomCardX = holder._x;
      Equipment.roomCardY = holder._y;
   }
   holder._x = Equipment.roomCardX;
   holder._y = Equipment.roomCardY;
   if(inRoom)
   {
      Equipment.keepCardInRoom(card);
   }
   limit = Equipment.cardBottomLimit(card, unit);
   if(needs <= limit)
   {
      return limit;
   }
   from = {x:0, y:0};
   to = {x:0, y:needs - limit};
   card.localToGlobal(from);
   card.localToGlobal(to);
   room = {x:0, y:Stage.visibleRect.y + Stage.safeRect.y};
   if(inRoom)
   {
      room.y = 0;
      Equipment.stage.localToGlobal(room);
   }
   // the model of the item keeps its least room above a card that goes up over it, past that the words scroll. In
   // the room it always stands above the card, in a chest when the card is under it
   if(inRoom || Equipment.modelOverCard(card) != undefined)
   {
      room.y += Equipment.MODEL_LEAST * Stage.visibleRect.height;
   }
   top = {x:0, y:Equipment.frameBox(card, card).yMin};
   card.localToGlobal(top);
   up = Math.min(to.y - from.y, Math.max(0, top.y - room.y));
   from = {x:0, y:0};
   to = {x:0, y:up};
   holder._parent.globalToLocal(from);
   holder._parent.globalToLocal(to);
   holder._y -= to.y - from.y;
   Equipment.cardRaised = up > 0;
   return Equipment.cardBottomLimit(card, unit);
};

// the card of a chest, a shop or a pickpocket, at the skin's place with the numbers in it. A follower's trade has the
// whole panel. The game marks a pickpocket as a trade with an NPC too, its card went up over the item's model
Equipment.shopCard = function()
{
   return Equipment.kind == "barter" || Equipment.kind == "container" && !Equipment.dressesOther();
};

// Where the game shows the model of an item in a chest or a shop, on the stage, when the card stands under it across:
// {x, y, half} with half of the height the game sizes the model for. Nothing elsewhere
Equipment.modelOverCard = function(card)
{
   var plugin = Equipment.plugin();
   var screen = Stage.visibleRect;
   var spot;
   var box;
   var model;
   if(!Equipment.shopCard() || plugin == undefined || plugin.PreviewSpot == undefined)
   {
      return undefined;
   }
   spot = plugin.PreviewSpot();
   box = card.background.getBounds(_root);
   model = {x:screen.x + spot[0] * screen.width, y:screen.y + spot[1] * screen.height, half:spot[2] * screen.height / 2, share:spot[2]};
   return box.xMax > model.x - model.half && box.xMin < model.x + model.half ? model : undefined;
};

// A card gone up over the game's model in a chest or a shop sent the model behind it, Ghostblade's guard over its name.
// The model goes up into the room left above the card and gets smaller if it has to, at most the game's size. A card at
// its own place leaves it where the game puts it, the models already up go back there too
Equipment.placeShopModel = function(card)
{
   var plugin = Equipment.plugin();
   var screen = Stage.visibleRect;
   var model = Equipment.cardRaised && !Equipment.cardBorrowed && !Equipment.inspecting ? Equipment.modelOverCard(card) : undefined;
   var top = screen.y + Stage.safeRect.y + Equipment.WINDOW_PAD;
   var high;
   var box;
   if(plugin == undefined || !Equipment.shopCard())
   {
      return undefined;
   }
   box = card.background.getBounds(_root);
   high = box.yMin - Equipment.WINDOW_PAD - top;
   if(model != undefined && box.yMin < model.y + model.half && high > 0)
   {
      plugin.PlacePreview((model.x - screen.x) / screen.width, (top + high / 2 - screen.y) / screen.height, Math.min(high / screen.height, model.share), high / screen.height, model.share, 1);
      Equipment.shopModelMoved = true;
      Equipment.shopModelTold = "placed at " + Math.round(top + high / 2) + " in " + Math.round(high) + " of " + Math.round(screen.height);
   }
   else if(Equipment.shopModelMoved)
   {
      plugin.PreviewBack();
      Equipment.shopModelMoved = false;
      Equipment.shopModelTold = "given back";
   }
   else
   {
      Equipment.shopModelTold = "left, raised " + Equipment.cardRaised + (model != undefined ? ", model to " + Math.round(model.y + model.half) + ", card from " + Math.round(box.yMin) : ", not under it");
   }
};

// A skin can keep its card where a column of slots stands (Edge UI at the lower right). In the character's room the card
// stays between the columns, and one wider than the room stands in its middle
Equipment.keepCardInRoom = function(card)
{
   var holder = card._parent;
   var box = Equipment.frameBox(card, card);
   var left;
   var right;
   var roomLeft = {x:0, y:0};
   var roomRight = {x:Equipment.stage.touch._width, y:0};
   var shift = 0;
   var from = {x:0, y:0};
   var to;
   if(box == undefined || Equipment.stage.touch == undefined)
   {
      return undefined;
   }
   left = {x:box.xMin, y:0};
   right = {x:box.xMax, y:0};
   card.localToGlobal(left);
   card.localToGlobal(right);
   Equipment.stage.localToGlobal(roomLeft);
   Equipment.stage.localToGlobal(roomRight);
   // a card moved in keeps a little off the slots, Edge's touched them
   if(right.x - left.x >= roomRight.x - roomLeft.x)
   {
      shift = (roomLeft.x + roomRight.x - left.x - right.x) / 2;
   }
   else if(left.x < roomLeft.x)
   {
      shift = Math.min(roomLeft.x + Equipment.MARGIN / 2, (roomLeft.x + roomRight.x - right.x + left.x) / 2) - left.x;
   }
   else if(right.x > roomRight.x)
   {
      shift = Math.max(roomRight.x - Equipment.MARGIN / 2, (roomLeft.x + roomRight.x + right.x - left.x) / 2) - right.x;
   }
   if(shift == 0)
   {
      return undefined;
   }
   to = {x:shift, y:0};
   holder._parent.globalToLocal(from);
   holder._parent.globalToLocal(to);
   holder._x += to.x - from.x;
};

// How much of the numbers shows when they may end at lowest: whole lines, a line cut in half at the edge reads as a
// mistake, and one line at the least. The small lines under the numbers have their own height, a cut by the numbers'
// rows went through the middle of You have 3 on Dragonborn UI
Equipment.shownLines = function(box, high, lowest)
{
   var room = lowest - box.numbersTop;
   var best = box.rowHigh;
   var names = box.names._visible ? box.names.textHeight : 0;
   var lines;
   var step;
   var y;
   var k = 1;
   if(!Equipment.pastLimit(high, room))
   {
      return high;
   }
   for(y = box.rowHigh; y <= names + 1 && y <= room; y += box.rowHigh)
   {
      best = y;
   }
   if(box.quiet._visible)
   {
      lines = Math.max(1, box.quiet.bottomScroll);
      step = box.quiet.textHeight / lines;
      while(k <= lines && box.quiet._y + k * step <= room)
      {
         best = box.quiet._y + k * step;
         k++;
      }
   }
   return Math.min(high, best);
};

// How low the card's frame may reach, in the card's units: a little above the bottom bar when the bar lies under the
// card, else above the screen's edge. Some skins keep the bar under the list only
Equipment.cardBottomLimit = function(card, unit)
{
   var bar = Equipment.menu.bottomBar;
   var lowest = {x:0, y:Stage.visibleRect.y + Stage.visibleRect.height - Stage.safeRect.y};
   var top;
   var across;
   var under;
   if(bar != undefined)
   {
      top = {x:0, y:bar._y};
      bar._parent.localToGlobal(top);
      across = Equipment.clipCall(bar, "getBounds", [_root]);
      under = card.background.getBounds(_root);
      if(across.xMax > under.xMin && across.xMin < under.xMax && top.y < lowest.y)
      {
         lowest = top;
      }
      Equipment.limitWhy = "bar " + Math.round(across.xMin) + "-" + Math.round(across.xMax) + " top " + Math.round(top.y) + ", card " + Math.round(under.xMin) + "-" + Math.round(under.xMax) + ", screen bottom " + Math.round(Stage.visibleRect.y + Stage.visibleRect.height - Stage.safeRect.y) + ", took " + Math.round(lowest.y);
   }
   card.globalToLocal(lowest);
   return lowest.y - Equipment.CARD_NUMBERS_MARGIN * unit;
};

// Gives the numbers the card's letters and tells where the card's labels start, in the card's units. The labels of
// SkyUI's card (WEIGHT, DAMAGE) are short fields named ...Label, its numbers are bold, its words are the enchantment
// or the description. A skin keeps those names with letters of its own. What the card hasn't got stays as it was.
// Dragonborn UI shows icons for the labels, the names take the card's plain small line then (its skill), a name with
// no face of its own came out as boxes there
Equipment.wearCardLetters = function(box, frame, unit)
{
   var card = Equipment.menu.itemCard;
   var letters;
   var label;
   var plain;
   var value;
   var words;
   var wordsField;
   var leftmost;
   var field;
   var format;
   var lower;
   var edge;
   for(var name in card)
   {
      field = card[name];
      if(!(field instanceof TextField) || field._parent != card || !field._visible)
      {
         continue;
      }
      format = field.text != "" ? field.getTextFormat(0, 1) : field.getNewTextFormat();
      lower = name.toLowerCase();
      if(lower.indexOf("enchant") >= 0 || lower.indexOf("description") >= 0 || lower.indexOf("effects") >= 0)
      {
         words = format;
         wordsField = field;
      }
      else if((lower.indexOf("label") >= 0 || lower.indexOf("lable") >= 0) && field.text.length > 0 && field.text.length < 16)
      {
         label = format;
         // where the letters start, a label's field is often wider than its word and set right or centred
         edge = Equipment.partBox(field, card);
         edge = format.align == "right" ? edge.xMax - (edge.xMax - edge.xMin) * (field.textWidth + 4) / field._width : format.align == "center" ? (edge.xMin + edge.xMax) / 2 - (edge.xMax - edge.xMin) * (field.textWidth + 4) / field._width / 2 : edge.xMin;
         leftmost = leftmost == undefined ? edge : Math.min(leftmost, edge);
      }
      else if(format.bold && value == undefined)
      {
         value = format;
      }
      else if(!format.bold && plain == undefined && field.text.length > 0 && field.text.length < 32)
      {
         plain = format;
      }
   }
   if(label == undefined)
   {
      label = plain != undefined ? plain : new TextFormat("$EverywhereMediumFont", Math.round(Equipment.CHEST_LABEL * unit), Equipment.inkOf("name"));
   }
   letters = {left:leftmost != undefined ? leftmost : frame.xMin + 2 * Equipment.STATS_PAD * unit, label:label, value:value != undefined ? value : label, quiet:words != undefined ? words : label};
   // the card's own sizes, the size the player set for the game's card goes on top of them (cardLettersAt)
   letters.labelBase = label != undefined ? label.size : Equipment.CHEST_LABEL * unit;
   letters.valueBase = value != undefined ? value.size * Equipment.CHEST_VALUE_SHARE : Equipment.CHEST_TEXT * unit;
   letters.quietBase = words != undefined ? Equipment.ownSize(wordsField, words) * Equipment.CHEST_QUIET_SHARE : Equipment.CHEST_QUIET * unit;
   return letters;
};

// the numbers' letters at a share of the card's own sizes
Equipment.cardLettersAt = function(box, letters, share)
{
   letters.labelSize = Math.round(letters.labelBase * share);
   letters.valueSize = Math.round(letters.valueBase * share);
   Equipment.letterLike(box.quiet, letters.quiet, Math.round(letters.quietBase * share));
};

// The numbers and the quiet lines under them at a share of the card's own sizes, from the left edge of the card's
// labels. In columns when they fit across, else a list where a value never gets cut and the names take the room it
// leaves, as in the window's list. box.across tells whether the names kept their share of the line then. Tells how
// high it all came out
Equipment.layCardNumbers = function(box, letters, lines, quiet, unit, share)
{
   var field = box.names;
   var pad = Equipment.STATS_PAD * unit;
   var gap = Equipment.CHEST_GAP * unit;
   var names = [];
   var values = [];
   var changes = [];
   var rows;
   var most;
   var room;
   var column;
   var format;
   var whole;
   var i = 0;
   var measure = function(words)
   {
      field.htmlText = Equipment.cardRows(letters, [words], undefined, undefined);
      return field.textWidth;
   };
   Equipment.cardLettersAt(box, letters, share);
   box.share = share;
   box.across = true;
   box.stops = undefined;
   rows = lines.length > 0 ? Equipment.cardGrid(box, letters, Equipment.statsColumns(lines), unit) : 0;
   box.layout = rows > 0 ? "columns" : "list";
   if(rows == 0)
   {
      rows = lines.length;
      while(i < lines.length)
      {
         values.push(lines[i][1]);
         changes.push(lines[i][2]);
         i++;
      }
      field.htmlText = Equipment.cardValues(letters, values, changes);
      // the field already ends clear of the frame's right edge, 4 is its margins round the letters
      room = field._width - 4 - field.textWidth - gap;
      most = field._width * Equipment.CHEST_NAMES_SHARE - gap;
      i = 0;
      while(i < lines.length)
      {
         whole = String(lines[i][0]);
         names.push(Equipment.cutToFit(whole, Math.min(most, room), measure));
         box.across = box.across && (room >= most || names[i] == whole);
         i++;
      }
      field.htmlText = Equipment.cardRows(letters, names, undefined, undefined);
      column = field.textWidth + gap;
      box.rowsHtml = Equipment.cardRows(letters, names, values, changes);
      field.htmlText = box.rowsHtml;
      format = new TextFormat();
      format.tabStops = [column];
      field.setTextFormat(format);
      box.stops = format.tabStops;
   }
   field._height = field.textHeight + 6 * unit;
   field._visible = lines.length > 0;
   box.rowHigh = rows > 0 ? field.textHeight / rows : Equipment.CHEST_LINE * unit;
   box.quiet.text = quiet.join("\n");
   box.quiet._y = lines.length > 0 ? field.textHeight + pad / 2 : 0;
   box.quiet._visible = quiet.length > 0;
   return quiet.length > 0 ? box.quiet._y + box.quiet._height : field.textHeight;
};

// Numbers too wide for the card at the size the player set, or too tall for the room left once the words gave what
// they could, come down in size as far as they must and never under their size at 100%. The card's own numbers keep
// that size whatever the size of its text. The sizes go a tenth of the card's own size apart and are tried halving
// the range each time, each try lays the numbers out whole. Tells how high they came out, room is in the card's units
Equipment.CHEST_FIT_STEP = 0.1;
Equipment.fitCardNumbers = function(box, letters, lines, quiet, unit, room)
{
   var most = Equipment.textShare("card");
   var least = Math.min(1, most);
   var steps = Math.max(1, Math.ceil((most - least) / Equipment.CHEST_FIT_STEP - 0.001));
   var low = 0;
   var high = steps;
   var tall;
   var laid;
   var mid;
   while(high - low > 1)
   {
      mid = Math.floor((low + high) / 2);
      tall = Equipment.layCardNumbers(box, letters, lines, quiet, unit, least + (most - least) * mid / steps);
      laid = mid;
      if(box.across && !Equipment.pastLimit(tall, room))
      {
         low = mid;
      }
      else
      {
         high = mid;
      }
   }
   if(laid != low)
   {
      tall = Equipment.layCardNumbers(box, letters, lines, quiet, unit, least + (most - least) * low / steps);
   }
   Equipment.cardFits = Equipment.number(Equipment.cardFits) + 1;
   return tall;
};

// The lines of numbers as html: a name in the card's label letters, a tab, the number in its value letters and its
// change against the worn one in brackets after it, in the smaller label size. Without numbers only the names, to
// measure their column
Equipment.cardRows = function(letters, names, values, changes)
{
   var rows = [];
   var i = 0;
   while(i < names.length)
   {
      rows.push(Equipment.lettersTag(letters.label, letters.labelSize, Equipment.htmlSafe(String(names[i]).toUpperCase()), "name") + (values != undefined ? "\t" + Equipment.cardRowValue(letters, values[i], changes != undefined ? changes[i] : undefined) : ""));
      i++;
   }
   return rows.join("<br>");
};

// the values of the list alone, a line each, to measure the widest
Equipment.cardValues = function(letters, values, changes)
{
   var rows = [];
   var i = 0;
   while(i < values.length)
   {
      rows.push(Equipment.cardRowValue(letters, values[i], changes != undefined ? changes[i] : undefined));
      i++;
   }
   return rows.join("<br>");
};

Equipment.cardRowValue = function(letters, value, change)
{
   var html = Equipment.lettersTag(letters.value, letters.valueSize, Equipment.htmlSafe(String(value)), "value", change != undefined && change.text == undefined ? Equipment.inkOf(change.role) : undefined);
   if(change != undefined && change.text != undefined)
   {
      html += " " + Equipment.lettersTag(letters.value, letters.labelSize, Equipment.htmlSafe(Equipment.bracketed(change)), "value", Equipment.inkOf(change.role));
   }
   return html;
};

// The numbers of a card in a chest, a shop or the character's room in the same columns as the window's, in the card's
// letters: each column as wide as its widest name and value, every value of a column at one place. Tells how many rows
// came, 0 when the columns don't fit the card even with values the size of the labels and the list stays
Equipment.cardGrid = function(box, letters, columns, unit)
{
   var steps = [letters.valueSize, Math.round((letters.valueSize + letters.labelSize) / 2), letters.labelSize];
   var gaps = [1, 0.5];
   var rows = 0;
   var g = 0;
   var i;
   // a cell measures the same at every gap, it's measured once (the card's numbers can be laid at a few sizes in a row)
   Equipment.cardMeasured = {};
   // the values come down to the labels' size first, then the columns close up
   while(rows == 0 && g < gaps.length)
   {
      i = 0;
      while(rows == 0 && i < steps.length)
      {
         Equipment.cardValueSize = steps[i];
         Equipment.cardGapShare = gaps[g];
         rows = Equipment.cardGridAt(box, letters, columns, unit);
         i++;
      }
      g++;
   }
   Equipment.cardValueSize = undefined;
   Equipment.cardGapShare = undefined;
   Equipment.cardMeasured = undefined;
   return rows;
};

Equipment.cardGridAt = function(box, letters, columns, unit)
{
   var field = box.names;
   // clear of the frame's right edge, a bracket at the end of the last column lay on it in a chest
   var room = field._width - Equipment.STATS_PAD * unit;
   var gap = Equipment.CHEST_GAP * unit * (Equipment.cardGapShare != undefined ? Equipment.cardGapShare : 1);
   var inner = gap / 2;
   var names = [];
   var values = [];
   var starts = [];
   var stops = [];
   var lines = [];
   var cells;
   var rows = 0;
   var total = 0;
   var format;
   var c = 0;
   var r;
   var measure = function(html)
   {
      var known = Equipment.cardMeasured;
      if(known != undefined && known[html] != undefined)
      {
         return known[html];
      }
      field.htmlText = html;
      if(known != undefined)
      {
         known[html] = field.textWidth;
      }
      return field.textWidth;
   };
   if(columns.length < 2)
   {
      return 0;
   }
   while(c < columns.length)
   {
      names[c] = 0;
      values[c] = 0;
      r = 0;
      while(r < columns[c].length)
      {
         names[c] = Math.max(names[c], measure(Equipment.cardName(letters, columns[c][r])));
         values[c] = Math.max(values[c], measure(Equipment.cardValue(letters, columns[c][r])));
         r++;
      }
      rows = Math.max(rows, columns[c].length);
      total += names[c] + inner + values[c] + (c > 0 ? gap : 0);
      c++;
   }
   if(total > room - 4 * unit)
   {
      return 0;
   }
   c = 0;
   while(c < columns.length)
   {
      // spread over the card, a column at the start of its share as the card's own DAMAGE, WEIGHT and VALUE stand
      starts[c] = Math.round(c > 0 ? Math.max(starts[c - 1] + names[c - 1] + inner + values[c - 1] + gap, c * room / columns.length) : 0);
      if(c > 0)
      {
         stops.push(starts[c]);
      }
      stops.push(Math.round(starts[c] + names[c] + inner));
      c++;
   }
   if(starts[columns.length - 1] + names[columns.length - 1] + inner + values[columns.length - 1] > room)
   {
      starts.length = 0;
      stops.length = 0;
      c = 0;
      while(c < columns.length)
      {
         starts[c] = Math.round(c > 0 ? starts[c - 1] + names[c - 1] + inner + values[c - 1] + gap : 0);
         if(c > 0)
         {
            stops.push(starts[c]);
         }
         stops.push(Math.round(starts[c] + names[c] + inner));
         c++;
      }
   }
   r = 0;
   while(r < rows)
   {
      cells = [];
      c = 0;
      while(c < columns.length)
      {
         cells.push(columns[c][r] != undefined ? Equipment.cardName(letters, columns[c][r]) : "");
         cells.push(columns[c][r] != undefined ? Equipment.cardValue(letters, columns[c][r]) : "");
         c++;
      }
      lines.push(cells.join("\t"));
      r++;
   }
   box.rowsHtml = lines.join("<br>");
   box.stops = stops;
   field.htmlText = box.rowsHtml;
   format = new TextFormat();
   format.tabStops = stops;
   field.setTextFormat(format);
   return rows;
};

Equipment.cardName = function(letters, line)
{
   return Equipment.lettersTag(letters.label, letters.labelSize, Equipment.htmlSafe(String(line[0]).toUpperCase()), "name");
};

Equipment.cardValue = function(letters, line)
{
   var change = line[2];
   var size = Equipment.cardValueSize != undefined ? Equipment.cardValueSize : letters.valueSize;
   var value = Equipment.lettersTag(letters.value, size, Equipment.htmlSafe(String(line[1])), "value", change != undefined && change.text == undefined ? Equipment.inkOf(change.role) : undefined);
   if(change != undefined && change.text != undefined)
   {
      value += " " + Equipment.lettersTag(letters.value, Math.round(letters.labelSize * Equipment.STATS_CHANGE), Equipment.htmlSafe(Equipment.bracketed(change)), "value", Equipment.inkOf(change.role));
   }
   return value;
};

// A skin on paper writes its card in black whatever colour its fields keep (Dear Diary's say white), the panel's
// ink for the role stands in for the colour there. An ink given colours the words on any skin
Equipment.lettersTag = function(like, size, words, role, ink)
{
   var colour = ink != undefined ? ink : (like == undefined || Equipment.paper ? Equipment.inkOf(role) : like.color);
   if(like == undefined)
   {
      return "<font size='" + size + "'" + (ink != undefined ? " color='" + Equipment.hex(Number(ink)) + "'" : "") + ">" + words + "</font>";
   }
   return "<font face='" + like.font + "' size='" + size + "' color='" + Equipment.hex(Number(colour)) + "'>" + (like.bold ? "<b>" + words + "</b>" : words) + "</font>";
};

Equipment.htmlSafe = function(words)
{
   return words.split("&").join("&amp;").split("<").join("&lt;").split(">").join("&gt;");
};

Equipment.letterLike = function(field, like, size)
{
   var format;
   if(like == undefined)
   {
      return undefined;
   }
   format = new TextFormat(like.font, size, Equipment.paper ? Equipment.inkOf("quiet") : like.color, like.bold);
   format.align = "left";
   field.setNewTextFormat(format);
};

// The size a field of the card has as the card gives it, before the panel grew its words to the player's size
Equipment.ownSize = function(field, format)
{
   return field != undefined && field.equipmentSizedTo != undefined && field.equipmentSizedTo == format.size && field.equipmentBaseSize != undefined ? field.equipmentBaseSize : format.size;
};

// the wheel over the card moves its numbers when they don't all fit, a few lines a notch
Equipment.scrollCardNumbers = function(delta)
{
   var box = Equipment.cardNumbers;
   var length;
   var bar;
   if(box == undefined || box.numbersTop == undefined)
   {
      return undefined;
   }
   if(delta != 0 && (!box._visible || box.scrollMost <= 0 || !Equipment.menu.itemCard.hitTest(_root._xmouse, _root._ymouse, false)))
   {
      return undefined;
   }
   box.scrolled = Math.max(0, Math.min(box.scrollMost, box.scrolled - delta * Equipment.CHEST_SCROLL_LINES * box.rowHigh));
   box.numbers._y = box.numbersTop - box.scrolled;
   box.bar.clear();
   if(box.scrollMost <= 0)
   {
      return undefined;
   }
   bar = Equipment.CHEST_BAR * box.unit;
   length = Math.max(box.rowHigh, box.shown * box.shown / (box.shown + box.scrollMost));
   box.bar.beginFill(Equipment.inkOf("edge"), 60);
   Equipment.roundBox(box.bar, box.right - bar - 2 * box.unit, box.numbersTop + (box.shown - length) * box.scrolled / box.scrollMost, bar, length, 1);
   box.bar.endFill();
};

// Where the card's words end, no lower than the parts that aren't words, in the viewer's units. A text field keeps
// its full height when its text is short or gone, and the numbers stood far under the last line of the card
Equipment.cardWordsBottom = function(otherwise, viewer)
{
   var card = Equipment.menu.itemCard;
   var shown = Equipment.shownParts();
   var bottom;
   var point;
   var i = 0;
   // whether the lowest words are a paragraph that wraps, a description or the effects
   Equipment.cardWordsWrap = false;
   while(i < shown.length)
   {
      if(shown[i] != card.background)
      {
         if(shown[i].textHeight != undefined)
         {
            if(shown[i].text != "")
            {
               // words cut to the lines that fit end where their field ends, the rest scrolls inside it
               point = {x:shown[i]._x, y:shown[i]._y + (shown[i] == Equipment.cutField() ? shown[i]._height : shown[i].textHeight + 4)};
               card.localToGlobal(point);
               viewer.globalToLocal(point);
               if(bottom == undefined || point.y > bottom)
               {
                  Equipment.cardWordsWrap = shown[i].wordWrap == true;
               }
               bottom = bottom == undefined ? point.y : Math.max(bottom, point.y);
            }
         }
         else
         {
            point = Equipment.partBox(shown[i], viewer);
            if(bottom == undefined || point.yMax > bottom)
            {
               Equipment.cardWordsWrap = false;
            }
            bottom = bottom == undefined ? point.yMax : Math.max(bottom, point.yMax);
         }
      }
      i++;
   }
   return bottom == undefined ? otherwise : bottom;
};

// the card's parts in sight in the panel's units, nothing while the card is faded out
Equipment.cardBox = function()
{
   var card = Equipment.menu.itemCard;
   var parts = Equipment.shownParts();
   var box;
   var one;
   var holder = card._parent;
   var i = 0;
   if(card == undefined || !card._visible || holder._visible == false || holder._alpha <= 0)
   {
      return undefined;
   }
   while(i < parts.length)
   {
      // the frame counts without the clear margin a skin's picture can have around it
      one = parts[i] == card.background ? Equipment.frameBox(card, Equipment.over) : Equipment.partBox(parts[i], Equipment.over);
      if(one == undefined)
      {
         i++;
         continue;
      }
      if(box == undefined)
      {
         box = {xMin:one.xMin, xMax:one.xMax, yMin:one.yMin, yMax:one.yMax};
      }
      else
      {
         box.xMin = Math.min(box.xMin, one.xMin);
         box.xMax = Math.max(box.xMax, one.xMax);
         box.yMin = Math.min(box.yMin, one.yMin);
         box.yMax = Math.max(box.yMax, one.yMax);
      }
      i++;
   }
   return box;
};

// for tests, the numbers in the card of a chest or a shop, where they are and what they say
Equipment.cardNumbersReport = function(note)
{
   var box = Equipment.cardNumbers;
   var card = Equipment.cardBox();
   var back = Equipment.menu.itemCard.background;
   skse.Log("PANELTEST card numbers " + note + ": " + (box._visible ? "numbers from " + Math.round(box.numbersTop) + " shown " + Math.round(box.shown) + " of " + Math.round(box.shown + box.scrollMost) + " scrolled " + Math.round(box.scrolled) + ", " + box.names.text.split("\r").join("/").split("\n").join("/") + " | " + box.quiet.text.split("\n").join("/") : "hidden") + ", frame " + Math.round(back._height) + (Equipment.menu.itemCard.equipmentFrameBottom != undefined ? " grown by " + Math.round(Equipment.menu.itemCard.equipmentFrameBottom._y - back._y) : back.equipmentGrid != undefined ? " grown by its grid from " + Math.round(back.equipmentGrid.high) : " as SkyUI's") + ", skin's frame " + Equipment.frameOfSkin + " " + Equipment.skinGrowth + ", grown " + Equipment.cardFrameWay + ", limit " + Equipment.limitWhy + (card != undefined ? ", card " + Math.round(card.xMin) + "-" + Math.round(card.xMax) + " x " + Math.round(card.yMin) + "-" + Math.round(card.yMax) : ", no card") + ", laid out " + Equipment.number(Equipment.cardLayouts) + " times" + (Equipment.shopModelTold != undefined ? ", model " + Equipment.shopModelTold : ""));
};

// for tests, SkyUI's frame and the pieces of a longer frame as they stand now
Equipment.cardFrameReport = function(note)
{
   var card = Equipment.menu.itemCard;
   var lines = [];
   var names = ["background", "equipmentFrameTop", "equipmentFrameFill", "equipmentFrameBottom"];
   var piece;
   var box;
   var i = 0;
   while(i < names.length)
   {
      piece = card[names[i]];
      if(piece == undefined)
      {
         lines.push(names[i] + " none");
      }
      else
      {
         box = piece.getBounds(card);
         lines.push(names[i] + " visible " + piece._visible + " alpha " + piece._alpha + " y " + Math.round(piece._y) + " yscale " + Math.round(piece._yscale) + " depth " + piece.getDepth() + " frame " + piece._currentframe + " of " + piece._totalframes + " bounds " + Math.round(box.yMin) + "-" + Math.round(box.yMax) + " own frame code " + (piece.onEnterFrame != undefined) + " grid " + (piece.scale9Grid != undefined ? Math.round(piece.scale9Grid.y) + "+" + Math.round(piece.scale9Grid.height) : "none") + " masked " + (piece._parent[names[i] + "Mask"] != undefined) + " parts" + Equipment.partsOf(piece));
      }
      i++;
   }
   piece = Equipment.cardNumbers;
   skse.Log("PANELTEST card frame " + note + ": " + lines.join("; ") + "; hidden by us " + Equipment.cardBackHidden + "; window wears it " + Equipment.window.sheet.framed + " seeing through " + Equipment.window.see + "; numbers shown " + Math.round(piece.shown) + " scroll " + Math.round(piece.scrollMost) + " top " + Math.round(piece.numbersTop) + " names from " + Math.round(piece.names._x) + " wide " + Math.round(piece.names._width) + " words " + Math.round(piece.names.textWidth) + " align " + piece.names.getTextFormat(0, 1).align + " in the frame " + Math.round(piece.left) + "-" + Math.round(piece.right) + " art " + Math.round(card.background.getBounds(card).xMin) + "-" + Math.round(card.background.getBounds(card).xMax) + ", skin frame " + Equipment.frameOfSkin + " " + Equipment.skinGrowth + ", limit " + Equipment.limitWhy + ", moved into the window by " + Math.round(Equipment.cardWindowShift));
};

Equipment.partsOf = function(clip)
{
   var told = "";
   for(var name in clip)
   {
      if(typeof clip[name] == "movieclip" || clip[name] instanceof TextField)
      {
         told += " " + name + "(" + typeof clip[name] + (clip[name]._visible ? "" : " hidden") + ")";
      }
   }
   return told == "" ? " none" : told;
};

// for tests, every text field of the card with its font, size and colour, to match the numbers to the skin
Equipment.cardFieldsReport = function(note)
{
   var card = Equipment.menu.itemCard;
   var lines = [];
   var field;
   var format;
   for(var name in card)
   {
      field = card[name];
      if(field instanceof TextField && field._parent == card)
      {
         format = field.text != "" ? field.getTextFormat(0, 1) : field.getNewTextFormat();
         lines.push(name + (field._visible ? "" : "(hidden)") + " \"" + field.text.substr(0, 24) + "\" " + format.font + " " + format.size + " #" + Number(format.color).toString(16) + (format.bold ? " bold" : "") + " text #" + Number(field.textColor).toString(16) + " alpha " + field._alpha + " filters " + (field.filters != undefined ? field.filters.length : "none") + " blend " + field.blendMode);
      }
   }
   for(var inner in card)
   {
      if(card[inner] instanceof MovieClip && card[inner]._parent == card)
      {
         lines.push("clip " + inner + (card[inner]._visible ? "" : "(hidden)") + " colours " + Equipment.colourOf(card[inner]) + " blend " + card[inner].blendMode + Equipment.innerFields(card[inner]));
      }
   }
   field = Equipment.cardNumbers.names;
   if(field != undefined && field.text != "")
   {
      format = field.getTextFormat(0, 1);
      lines.push("our names \"" + field.text.substr(0, 16) + "\" " + format.font + " " + format.size);
   }
   skse.Log("PANELTEST card fields " + note + ": " + lines.join("; ") + "; card colours " + Equipment.colourOf(card) + ", holder " + Equipment.colourOf(card._parent) + ", card filters " + (card.filters != undefined ? card.filters.length : "none"));
};

// for tests, where each part of the card stands and how high it is, a field with its lines and whether SkyUI
// fitted its words into it. Each part is told in the card's units against the card's frame as it stands now, grown
// with the numbers. A field by its letters, a clip by its picture, and what of it passes the frame. Then the numbers
// in a chest's card or the card left in the UI's place, line by line with its right edge and its bottom against the
// frame and the part of them in sight
Equipment.cardPartsReport = function(note)
{
   var card = Equipment.menu.itemCard;
   var parts = Equipment.shownParts();
   var span = Equipment.cardSpan();
   var frame = Equipment.cardFrameNow(card);
   var name = card.ItemText != undefined ? card.ItemText.ItemTextField : undefined;
   var lines = [];
   var part;
   var box;
   var i = 0;
   while(i < parts.length)
   {
      part = parts[i];
      box = Equipment.partBox(part, card);
      lines.push(part._name + " y " + Math.round(box.yMin) + "-" + Math.round(box.yMax) + (part != card.background ? Equipment.pastFrame(Equipment.wordsBox(part, card), frame) : " x " + Math.round(box.xMin) + "-" + Math.round(box.xMax)) + (part.kindTo != undefined ? " kind to " + Math.round(part.kindTo) : "") + (part.textTo != undefined ? " text to " + Math.round(part.textTo) : "") + (part instanceof TextField ? " field " + Math.round(part._y) + "+" + Math.round(part._height) + " text " + Math.round(part.textHeight) + " lines " + part.numLines + " size " + part.getTextFormat(0, 1).size + " fit " + part.enableShrinkToFit + " from " + Math.round(part.origHeight) + " grows " + part.maxHeightExpand + " wide " + Math.round(part._width) + " letters " + Math.round(part.textWidth) + " scale " + Math.round(part._xscale) + "/" + Math.round(part._yscale) + " mid size " + part.getTextFormat(Math.floor(part.length / 2), Math.floor(part.length / 2) + 1).size + " over " + part.equipmentOverHigh + " \"" + part.text.substr(0, 16) + "\"" : ""));
      i++;
   }
   // the name's letters inside its clip, a name grown past its line would run out of the card
   if(name instanceof TextField && card.ItemText._visible)
   {
      lines.push("name letters" + Equipment.pastFrame(Equipment.wordsBox(name, card), frame) + " size " + name.getTextFormat(0, 1).size + " letters " + Math.round(name.textWidth) + " of field " + Math.round(name._width) + " autosize " + name.textAutoSize);
   }
   skse.Log("PANELTEST card parts " + note + ": frame " + card._currentframe + " " + card._currentlabel + ", span " + Math.round(span.top) + "-" + Math.round(span.bottom) + ", window " + Math.round(Equipment.window.preview) + "+" + Math.round(Equipment.window.high) + ", card frame drawn" + (frame != undefined ? " x " + Math.round(frame.xMin) + "-" + Math.round(frame.xMax) + " y " + Math.round(frame.yMin) + "-" + Math.round(frame.yMax) + (frame.copies != undefined ? " by copies " + frame.copies : "") : " none") + ", grown " + Equipment.cardFrameWay + Equipment.boxTopTold(card) + ", text share " + Equipment.textShare("card") + "; " + lines.join("; ") + "; " + Equipment.cardNumbersLines(frame));
};

// The card's frame in its units as it's drawn now. SkyUI's frame grown by a grid or a skin's picture counts as it is.
// A longer frame made of copies counts each copy where its picture meets its mask, down from the top while they join.
// Counted by where the bottom copy stood, Nordic UI's frame told 0-341 while its picture ended at 209: the slice and
// the edge came from past the picture's bottom and drew nothing. frame.copies tells each copy's part
Equipment.cardFrameNow = function(card)
{
   var frame = Equipment.frameBox(card, card);
   var names = ["equipmentFrameTop", "equipmentFrameFill", "equipmentFrameBottom"];
   var told = [];
   var shown;
   var low;
   var joined = true;
   var margin;
   var i = 0;
   if(frame == undefined || card.equipmentFrameTop == undefined)
   {
      return frame;
   }
   margin = frame.yMin - card.background.getBounds(card).yMin;
   while(i < names.length)
   {
      shown = Equipment.copyShown(card, names[i]);
      told.push(names[i].substr(14).toLowerCase() + " " + (shown != undefined ? Math.round(shown.yMin) + "-" + Math.round(shown.yMax) : "none"));
      joined = joined && shown != undefined && (low == undefined || shown.yMin <= low + 1);
      if(joined)
      {
         low = low == undefined ? shown.yMax : Math.max(low, shown.yMax);
      }
      i++;
   }
   frame.yMax = (low != undefined ? low : frame.yMin + margin) - margin;
   frame.copies = told.join(" ");
   return frame;
};

// for tests, the card's frame and everything in it a few levels down, then the card's own parts, to see where a
// skin keeps its picture. A line each: its path and depth, its kind, the movie it came from where that isn't its
// parent's, its place and scale, its box in the card's units, a grid, whether it shows and its frames. Parts are found
// by their names and by the depths of a timeline, a clip of a loaded movie has no name the frame lists
Equipment.TREE_LEVELS = 4;
Equipment.TREE_MOST = 80;
Equipment.TREE_DEPTHS = 40;
Equipment.cardFrameTree = function(note)
{
   var card = Equipment.menu.itemCard;
   var told = [];
   var kids;
   var i = 0;
   Equipment.treeOf(card.background, card, "background", "", 0, told);
   kids = Equipment.treeKids(card);
   while(i < kids.length)
   {
      if(kids[i].clip != card.background)
      {
         told.push("card part " + Equipment.treeNode(kids[i].clip, card, kids[i].name + kids[i].found, card._url));
      }
      i++;
   }
   i = 0;
   while(i < told.length)
   {
      skse.Log("PANELTEST card frame tree " + note + ": " + told[i]);
      i++;
   }
};

Equipment.treeOf = function(clip, card, path, found, level, told)
{
   var kids;
   var i = 0;
   if(clip == undefined || told.length >= Equipment.TREE_MOST)
   {
      return undefined;
   }
   told.push(Equipment.treeNode(clip, card, path + found, clip._parent._url));
   if(level >= Equipment.TREE_LEVELS || clip instanceof TextField)
   {
      return undefined;
   }
   kids = Equipment.treeKids(clip);
   while(i < kids.length)
   {
      Equipment.treeOf(kids[i].clip, card, path + "." + kids[i].name, kids[i].found, level + 1, told);
      i++;
   }
};

// the clips and fields right in a clip, by name and then by the depths of its timeline those names missed
Equipment.treeKids = function(clip)
{
   var kids = [];
   var seen;
   var one;
   var depth = Equipment.LOWEST_DEPTH;
   var k;
   for(var name in clip)
   {
      one = clip[name];
      if((typeof one == "movieclip" || one instanceof MovieClip || one instanceof TextField) && one._parent == clip)
      {
         kids.push({clip:one, name:name, found:""});
      }
   }
   while(clip.getInstanceAtDepth != undefined && depth < Equipment.LOWEST_DEPTH + Equipment.TREE_DEPTHS)
   {
      one = clip.getInstanceAtDepth(depth);
      seen = one == undefined;
      k = 0;
      while(!seen && k < kids.length)
      {
         seen = kids[k].clip == one;
         k++;
      }
      if(!seen)
      {
         kids.push({clip:one, name:String(one._name), found:" (by depth)"});
      }
      depth++;
   }
   return kids;
};

Equipment.treeNode = function(clip, card, path, parentUrl)
{
   var box = clip.getBounds != undefined ? clip.getBounds(card) : Equipment.partBox(clip, card);
   var grid = clip.scale9Grid;
   var kind = clip instanceof TextField ? "field \"" + String(clip.text).substr(0, 12) + "\"" : typeof clip == "movieclip" || clip instanceof MovieClip ? "clip" : typeof clip;
   return path + " depth " + (clip.getDepth != undefined ? clip.getDepth() : "?") + " " + kind + (clip._url != undefined && clip._url != parentUrl ? " from " + clip._url : "") + " at " + Math.round(clip._x * 10) / 10 + "," + Math.round(clip._y * 10) / 10 + " scale " + Math.round(clip._xscale * 10) / 10 + "/" + Math.round(clip._yscale * 10) / 10 + " box " + Math.round(box.xMin) + "," + Math.round(box.yMin) + " to " + Math.round(box.xMax) + "," + Math.round(box.yMax) + (grid != undefined ? " grid " + Math.round(grid.x) + "," + Math.round(grid.y) + " " + Math.round(grid.width) + "x" + Math.round(grid.height) : "") + " shown " + clip._visible + " alpha " + Math.round(clip._alpha) + (clip._totalframes != undefined ? " frames " + clip._currentframe + " of " + clip._totalframes : "");
};

// for tests, the card's frame and name as the card drew them for its kind, the first time this menu shows it,
// and again once a picture loaded into the frame takes the place of the frame's stand-in
Equipment.noteFrameDrawn = function(card, back)
{
   var art = Equipment.framePicture(back);
   var drawn;
   if(Equipment.framesDrawn == undefined)
   {
      Equipment.framesDrawn = {};
   }
   drawn = Equipment.framesDrawn[card._currentframe];
   if(drawn == undefined || drawn.url != back._url)
   {
      drawn = Equipment.framesDrawn[card._currentframe] = {top:back.getBounds(card).yMin, yscale:back._yscale, url:back._url, name:card.ItemText != undefined ? Equipment.nameBox(card).yMin : undefined};
   }
   if(drawn.art == undefined && art != undefined)
   {
      drawn.art = art._yscale;
   }
};

// for tests, the top of the frame's box against the name. A picture with a clear band over its box, Norden UI's,
// shows its top line that band lower, and a stretched picture stretches the band: its top part counts by how much it's
// stretched there, nothing under a grid. The name's top over the box's against how the card drew them
Equipment.boxTopTold = function(card)
{
   var back = card.background;
   var drawn = Equipment.framesDrawn != undefined ? Equipment.framesDrawn[card._currentframe] : undefined;
   var art = Equipment.framePicture(back);
   var top = back.getBounds(card).yMin;
   var stretch = 1;
   var name;
   if(drawn == undefined || card.ItemText == undefined)
   {
      return "";
   }
   name = Equipment.nameBox(card).yMin;
   if(back.scale9Grid == undefined)
   {
      stretch *= back._yscale / drawn.yscale;
   }
   if(art != undefined && drawn.art != undefined && art.scale9Grid == undefined)
   {
      stretch *= art._yscale / drawn.art;
   }
   return ", box top " + Math.round(top) + " drawn at " + Math.round(drawn.top) + ", its top part stretched x" + Math.round(stretch * 100) / 100 + ", name top " + Math.round(name) + " under the box top by " + Math.round(name - top) + " (drawn by " + Math.round(drawn.name - drawn.top) + ")" + (card.SkillTextInstance != undefined && card.SkillTextInstance._visible ? ", kind top " + Math.round(Equipment.partBox(card.SkillTextInstance, card).yMin) : "");
};

// what's wrong with a line of the numbers: past the frame's side, under what the frame draws, under the part in sight
Equipment.lineFlags = function(right, low, seen, frame)
{
   return (right > frame.xMax + 0.5 ? " PAST THE FRAME" : "") + (low > frame.yMax + 0.5 ? " PAST THE FRAME'S BOTTOM" : "") + (low > seen + 0.5 ? " OUT OF SIGHT" : "");
};

// what of a copy of the frame shows, where its picture and its mask meet, nothing when they don't
Equipment.copyShown = function(card, name)
{
   var copy = card[name];
   var mask = card[name + "Mask"];
   var box;
   var hole;
   if(copy == undefined || mask == undefined || copy._visible == false)
   {
      return undefined;
   }
   box = copy.getBounds(card);
   hole = mask.getBounds(card);
   if(!(Math.min(box.yMax, hole.yMax) - Math.max(box.yMin, hole.yMin) > 0.5))
   {
      return undefined;
   }
   return {yMin:Math.max(box.yMin, hole.yMin), yMax:Math.min(box.yMax, hole.yMax)};
};

// what of a box passes the frame, by how many of the card's units on each side
Equipment.pastFrame = function(box, frame)
{
   var past = [];
   if(box == undefined || frame == undefined)
   {
      return "";
   }
   if(box.xMin < frame.xMin - 0.5)
   {
      past.push("left by " + Math.round(frame.xMin - box.xMin));
   }
   if(box.xMax > frame.xMax + 0.5)
   {
      past.push("right by " + Math.round(box.xMax - frame.xMax));
   }
   if(box.yMax > frame.yMax + 0.5)
   {
      past.push("bottom by " + Math.round(box.yMax - frame.yMax));
   }
   return " x " + Math.round(box.xMin) + "-" + Math.round(box.xMax) + (past.length > 0 ? " PAST THE FRAME " + past.join(", ") : " inside");
};

// The numbers' lines one by one, each laid alone in a field of its own with the same tab stops. Its right edge and its
// bottom in the card's units, against the frame and against the part of the numbers in sight (the mask)
Equipment.cardNumbersLines = function(frame)
{
   var box = Equipment.cardNumbers;
   var told = [];
   var rows;
   var field;
   var format;
   var right;
   var low;
   var top;
   var seen;
   var cut = Equipment.wordsCut;
   var k = 0;
   if(box == undefined || frame == undefined)
   {
      return "no numbers";
   }
   if(!box._visible)
   {
      return "numbers hidden";
   }
   top = box.numbersTop - box.scrolled;
   seen = box.numbersTop + box.shown;
   field = box.createTextField("equipmentMeasure", 9, 0, 0, 10, 10);
   field._visible = false;
   field.html = true;
   field.multiline = false;
   field.wordWrap = false;
   field.setNewTextFormat(box.names.getNewTextFormat());
   rows = box.names._visible && box.rowsHtml != undefined ? box.rowsHtml.split("<br>") : [];
   while(k < rows.length)
   {
      field.htmlText = rows[k];
      if(box.stops != undefined)
      {
         format = new TextFormat();
         format.tabStops = box.stops;
         field.setTextFormat(format);
      }
      right = box.names._x + 2 + field.textWidth;
      low = top + (k + 1) * box.rowHigh;
      told.push("line " + (k + 1) + " \"" + field.text.split("\t").join(" | ") + "\" right " + Math.round(right) + " bottom " + Math.round(low) + Equipment.lineFlags(right, low, seen, frame));
      k++;
   }
   if(box.quiet._visible)
   {
      right = box.quiet._x + 2 + box.quiet.textWidth;
      low = top + box.quiet._y + box.quiet.textHeight + 4;
      told.push("quiet " + box.quiet.numLines + " lines right " + Math.round(right) + " bottom " + Math.round(low) + Equipment.lineFlags(right, low, seen, frame));
   }
   field.removeTextField();
   return "numbers at " + Math.round(box.share * 100) + "% in " + box.layout + (box.across ? "" : ", names cut for the values") + ", fitted " + Equipment.number(Equipment.cardFits) + " times, from " + Math.round(box.numbersTop) + " shown " + Math.round(box.shown) + " to " + Math.round(seen) + " scroll " + Math.round(box.scrollMost) + ", rows " + Math.round(box.rowHigh) + " high, words " + (cut != undefined ? cut.field._name + " cut to " + (cut.field.bottomScroll - cut.field.scroll + 1) + " of " + cut.field.numLines + " lines" : "whole") + " end " + Math.round(box.wordsEnd) + "; " + told.join("; ");
};

Equipment.innerFields = function(clip)
{
   var told = "";
   for(var name in clip)
   {
      if(clip[name] instanceof TextField && clip[name]._parent == clip)
      {
         told += " [" + name + " \"" + clip[name].text.substr(0, 12) + "\" #" + Number(clip[name].textColor).toString(16) + "]";
      }
   }
   return told;
};

Equipment.colourOf = function(clip)
{
   var colour = clip.transform != undefined ? clip.transform.colorTransform : undefined;
   return colour == undefined ? "none" : colour.redMultiplier + "/" + colour.greenMultiplier + "/" + colour.blueMultiplier + "/" + colour.alphaMultiplier + " +" + colour.redOffset + "/" + colour.greenOffset + "/" + colour.blueOffset;
};
