// Long words of a card never get small letters. SkyUI grows the card's field to the whole text (growLongText), and where
// the window or a card has no more room the field keeps the lines that fit and scrolls: the wheel over it moves it a
// line a notch, and where the pointer can't reach it (a window over the rows, the card in the character's room) the
// lines go up by themselves after a pause and start over at the end
Equipment.WORDS_ALL = 4000;
Equipment.WORDS_LEAST_LINES = 3;
Equipment.WORDS_WAIT = 2500;
Equipment.WORDS_STEP = 1100;
Equipment.WORDS_END_WAIT = 3000;
Equipment.WORDS_BAR = 3;
// the least of the screen's height the game's model of an item keeps above a card gone up over it, a little over half
// its own size. Past that the card stops and its words scroll
Equipment.MODEL_LEAST = 0.25;

Equipment.startLongWords = function()
{
   var lists = Equipment.menu.inventoryLists;
   if(Equipment.wordsWheel != undefined)
   {
      return undefined;
   }
   Equipment.wordsWheel = {};
   Equipment.wordsWheel.onMouseWheel = function(delta)
   {
      Equipment.scrollWords(delta);
   };
   Mouse.addListener(Equipment.wordsWheel);
   // a pinned window lies over the rows, the wheel over its words is theirs and the list stays
   if(lists.itemList != undefined && lists.itemList.equipmentWheel == undefined)
   {
      lists.itemList.equipmentWheel = lists.itemList.onMouseWheel;
      lists.itemList.onMouseWheel = function(delta)
      {
         if(!Equipment.wordsUnderPointer())
         {
            this.equipmentWheel(delta);
         }
      };
   }
};

// the card's field of wrapped words that takes the most lines: an enchantment, a description, the effects
Equipment.longWords = function()
{
   var card = Equipment.menu.itemCard;
   var best;
   var field;
   for(var name in card)
   {
      field = card[name];
      if(field instanceof TextField && field._parent == card && field._name == name && field._visible && field.wordWrap == true && field.text != "" && (best == undefined || field.textHeight > best.textHeight))
      {
         best = field;
      }
   }
   return best;
};

Equipment.cutField = function()
{
   return Equipment.wordsCut != undefined ? Equipment.wordsCut.field : undefined;
};

// The long words give up to "by" of the card's height, in its units: whole lines, never under the least lines (three
// unless told). Words cut already give from the lines they still show. What lies under them moves up by what they
// gave. Tells what they gave
Equipment.cutWords = function(by, least)
{
   var card = Equipment.menu.itemCard;
   var field = Equipment.longWords();
   var cut = Equipment.wordsCut;
   var fewest = least != undefined ? least : Equipment.WORDS_LEAST_LINES;
   var again;
   var step;
   var full;
   var lines;
   var keep;
   var gave;
   var bottom;
   var parts;
   var box;
   var i = 0;
   if(field == undefined || !(by > 0) || field.numLines <= fewest)
   {
      return 0;
   }
   again = cut != undefined && cut.field == field;
   step = field.textHeight / Math.max(1, field.numLines);
   // the box gets this height back, the lines go by what the layouts measure of the words, their text and a margin.
   // SkyUI's box can be taller than its words (16:10), the lines counted from the box gave too little and the card's
   // last row of numbers went to its scroll
   full = again ? cut.full : field._height;
   lines = Math.max(fewest, Math.floor(((again ? cut.keep - 4 : field.textHeight) - by) / step));
   if(lines >= field.numLines)
   {
      return 0;
   }
   keep = lines * step + 4;
   gave = field._height - keep;
   if(!(gave > 0))
   {
      return 0;
   }
   if(cut == undefined || cut.field != field)
   {
      cut = Equipment.wordsCut = {field:field, full:full, moved:[], since:getTimer(), held:false, autoSize:field.textAutoSize};
   }
   bottom = Equipment.wholeBox(field, card).yMax;
   field._height = keep;
   cut.keep = keep;
   cut.step = step;
   parts = Equipment.shownParts();
   while(i < parts.length)
   {
      box = Equipment.wholeBox(parts[i], card);
      if(parts[i] != field && parts[i] != card.background && (box.yMin + box.yMax) / 2 >= bottom)
      {
         parts[i]._y -= gave;
         cut.moved.push({part:parts[i], by:gave, to:parts[i]._y});
      }
      i++;
   }
   Equipment.drawWordsBar();
   Equipment.driftWords();
   return gave;
};

// In the window the enchantment of a weapon came back to small letters after the layout: SkyUI sets shrink on it a
// frame after the card is filled, the window lays the card out in that same frame (a chest a frame later had none of
// it). While the window holds the words they keep the size they were laid out for, and get shrink back with the card
Equipment.keepUnshrunk = function()
{
   var clip = Equipment.shrinkKeeper;
   if(clip == undefined)
   {
      clip = Equipment.shrinkKeeper = Equipment.menu.itemCard._parent.createEmptyMovieClip("equipmentShrinkKeeper", Equipment.menu.itemCard._parent.getNextHighestDepth());
   }
   clip.onEnterFrame = function()
   {
      var watched = Equipment.textWatched;
      var i = 0;
      if(watched == undefined || watched.length == 0)
      {
         this.onEnterFrame = undefined;
         return undefined;
      }
      while(i < watched.length)
      {
         if(watched[i].textAutoSize == "shrink")
         {
            Equipment.textUnshrunk.push({field:watched[i], text:watched[i].text});
            Equipment.unshrinkNow(watched[i]);
            Equipment.shrinkKept = Equipment.number(Equipment.shrinkKept) + 1;
         }
         // The words take another height than the layout measured: a mod put more in past the card's info
         // (Description Framework on Vel'dun UI, Edge UI, Untarnished UI, Norden UI), the card measured them shrunk, or
         // the skin laid its box out again. They lay hidden past four lines with nothing to scroll, the window is laid
         // out again, a few times a card at most
         if(watched[i].equipmentLaidHigh != undefined && (Math.abs(watched[i]._height - watched[i].equipmentLaidHigh) > 1 || Math.abs(watched[i].textHeight - Equipment.number(watched[i].equipmentLaidWords)) > 1) && Equipment.number(Equipment.wordsRelaid) < Equipment.WORDS_RELAYS)
         {
            Equipment.wordsRelaid = Equipment.number(Equipment.wordsRelaid) + 1;
            // a new stamp: a window going along with its row lays the card out again too
            Equipment.cardStamp = Equipment.number(Equipment.cardStamp) + 1;
            Equipment.wordsRelaidFor = Equipment.cardStamp;
            Equipment.wordsRelaidWhy = watched[i]._name + " box " + Math.round(watched[i].equipmentLaidHigh) + " to " + Math.round(watched[i]._height) + ", words " + Math.round(watched[i].equipmentLaidWords) + " to " + Math.round(watched[i].textHeight);
            Equipment.showWindow();
            return undefined;
         }
         i++;
      }
   };
};

// the window's words as the layout left them, the keeper above lays the window out again when the card changes them
Equipment.WORDS_RELAYS = 3;
Equipment.wordsLaid = function()
{
   var watched = Equipment.textWatched;
   var i = 0;
   if(Equipment.wordsRelaidFor != Equipment.cardStamp || Equipment.wordsRelaid == undefined)
   {
      Equipment.wordsRelaidFor = Equipment.cardStamp;
      Equipment.wordsRelaid = 0;
   }
   while(watched != undefined && i < watched.length)
   {
      watched[i].equipmentLaidHigh = watched[i]._height;
      i++;
   }
};

// The window takes at most the height from the rows' top (the screen's top beside a slot) down to the bottom bar, with
// the least part for its model and the lens's strip of a window above its row. Words longer than that keep the lines
// that fit. body is the window's card and numbers, in the panel's units
Equipment.cutWindowWords = function(body, slot, bottom)
{
   var card = Equipment.menu.itemCard;
   var top = slot != undefined ? Equipment.frame.top : Math.max(Equipment.frame.top, Equipment.rowsTop());
   var model = slot != undefined ? Equipment.PREVIEW_HEIGHT : Equipment.PREVIEW_LEAST;
   var lens = slot != undefined ? 0 : Math.max(0, Equipment.underCard(true) - Equipment.underCard(false));
   var over = model + body + lens - (bottom - top);
   var scale = card._yscale / 100 * card._parent._yscale / 100;
   return over > 0 && scale > 0 ? Equipment.cutWords(over / scale) : 0;
};

// the field gets its whole height back and what moved up for it goes back down, a part the card has moved since stays
Equipment.uncutWords = function()
{
   var cut = Equipment.wordsCut;
   var i;
   if(cut == undefined)
   {
      return undefined;
   }
   i = cut.moved.length - 1;
   while(i >= 0)
   {
      if(cut.moved[i].part._y == cut.moved[i].to)
      {
         cut.moved[i].part._y += cut.moved[i].by;
      }
      i--;
   }
   cut.field._height = cut.full;
   cut.field.scroll = 1;
   Equipment.wordsCut = undefined;
   Equipment.drawWordsBar();
};

// a thin bar beside the words, as long as the share of them in sight
Equipment.drawWordsBar = function()
{
   var card = Equipment.menu.itemCard;
   var cut = Equipment.wordsCut;
   var bar = card.equipmentWordsBar;
   var field;
   var shown;
   var length;
   if(bar == undefined)
   {
      if(cut == undefined)
      {
         return undefined;
      }
      bar = card.createEmptyMovieClip("equipmentWordsBar", card.getNextHighestDepth());
      bar.hitTestDisable = true;
   }
   bar.clear();
   if(cut == undefined || cut.field.maxscroll <= 1)
   {
      return undefined;
   }
   field = cut.field;
   shown = field.bottomScroll - field.scroll + 1;
   length = Math.max(cut.step, cut.keep * shown / field.numLines);
   bar.beginFill(Equipment.inkOf("edge"), 60);
   Equipment.roundBox(bar, field._x + field._width + Equipment.WORDS_BAR, field._y + (cut.keep - length) * (field.scroll - 1) / (field.maxscroll - 1), Equipment.WORDS_BAR, length, 1);
   bar.endFill();
};

// the words under the pointer, those a notch of the wheel moves
Equipment.wordsUnderPointer = function()
{
   var cut = Equipment.wordsCut;
   var field;
   var from;
   var to;
   if(cut == undefined || cut.field.maxscroll <= 1 || !cut.field._visible || Equipment.menu.itemCard._parent._visible == false)
   {
      return false;
   }
   field = cut.field;
   from = {x:field._x, y:field._y};
   to = {x:field._x + field._width + 3 * Equipment.WORDS_BAR, y:field._y + field._height};
   field._parent.localToGlobal(from);
   field._parent.localToGlobal(to);
   return _root._xmouse >= from.x && _root._xmouse <= to.x && _root._ymouse >= from.y && _root._ymouse <= to.y;
};

// a notch of the wheel over the words moves them a line, and they stop moving by themselves for this item
Equipment.scrollWords = function(delta)
{
   var cut = Equipment.wordsCut;
   if(delta == 0 || !Equipment.wordsUnderPointer())
   {
      return false;
   }
   cut.field.scroll = Math.max(1, Math.min(cut.field.maxscroll, cut.field.scroll - (delta > 0 ? 1 : -1)));
   cut.held = true;
   Equipment.drawWordsBar();
   return true;
};

// Lines that went out of sight come up one by one after a pause, at the end they wait and start over from the top
Equipment.driftWords = function()
{
   var clip = Equipment.wordsDrift;
   if(clip == undefined)
   {
      clip = Equipment.wordsDrift = Equipment.menu.itemCard._parent.createEmptyMovieClip("equipmentWordsDrift", Equipment.menu.itemCard._parent.getNextHighestDepth());
   }
   clip.onEnterFrame = function()
   {
      var cut = Equipment.wordsCut;
      var field;
      var now = getTimer();
      if(cut == undefined)
      {
         this.onEnterFrame = undefined;
         return undefined;
      }
      field = cut.field;
      if(cut.held || Equipment.wordsUnderPointer())
      {
         cut.since = now;
         return undefined;
      }
      if(field.scroll >= field.maxscroll)
      {
         if(now - cut.since >= Equipment.WORDS_END_WAIT)
         {
            field.scroll = 1;
            cut.since = now;
            Equipment.drawWordsBar();
         }
      }
      else if(now - cut.since >= (field.scroll == 1 ? Equipment.WORDS_WAIT : Equipment.WORDS_STEP))
      {
         field.scroll++;
         cut.since = now;
         Equipment.drawWordsBar();
      }
   };
};

// for tests, a report kept in Equipment.told as well, for a setup with no skse64.log, Papyrus gets it from there
Equipment.reportTo = function(name, note)
{
   var log = skse.Log;
   var told = [];
   skse.Log = function(text)
   {
      told.push(text);
      log.call(skse, text);
   };
   Equipment[name](note);
   skse.Log = log;
   Equipment.told = told.join(" || ");
};

// for tests, the middle of the words cut to fit as aimedX, aimedY, for the wheel over them
Equipment.aimWords = function()
{
   var cut = Equipment.wordsCut;
   var point;
   var share;
   Equipment.aimedX = Equipment.aimedY = -1;
   if(cut == undefined)
   {
      return undefined;
   }
   point = {x:cut.field._x + cut.field._width / 2, y:cut.field._y + cut.field._height / 2};
   cut.field._parent.localToGlobal(point);
   share = Equipment.screenShare(point.x, point.y);
   Equipment.aimedX = share.x;
   Equipment.aimedY = share.y;
};

// for tests, the long words of the card, how many lines show of how many and where they stand
Equipment.wordsReport = function(note)
{
   var cut = Equipment.wordsCut;
   var field = cut != undefined ? cut.field : Equipment.longWords();
   var format = field != undefined ? field.getTextFormat(0, 1) : undefined;
   skse.Log("PANELTEST words " + note + ": " + (field == undefined ? "none" : field._name + " size " + format.size + ", lines " + field.numLines + (cut != undefined ? ", cut to " + (field.bottomScroll - field.scroll + 1) + " from line " + field.scroll + " of " + field.maxscroll + (cut.held ? ", held" : "") : ", whole") + ", high " + Math.round(field._height) + " text " + Math.round(field.textHeight) + ", autosize " + field.textAutoSize + (cut != undefined ? " (" + cut.autoSize + " when cut)" : "") + ", shrink set again " + Equipment.number(Equipment.shrinkKept) + " times, laid again " + Equipment.number(Equipment.wordsRelaid) + ", keeper " + (Equipment.shrinkKeeper.onEnterFrame != undefined) + ", watched " + (Equipment.textWatched != undefined ? Equipment.textWatched.length : "none") + ", laid words " + (field != undefined && field.equipmentLaidText != undefined ? field.equipmentLaidText.length + " of " + field.text.length : "none") + (Equipment.wordsRelaidWhy != undefined ? " (" + Equipment.wordsRelaidWhy + ")" : "")));
};
