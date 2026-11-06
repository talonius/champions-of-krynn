{ Advancing time, camp rest and the game clock.

  The game clock has seven components; unitScale = (10, 10, 6, 24, 30, 12, 256) gives the modulus of each. The on-screen
  clock is repainted through Sym8x8.Put8x8Sym when the hour rolls over. CampRestMenu offers Rest, Days, Hours, Mins,
  Add, Subtract and Exit, with the up and down arrows mapped to Add and Subtract and left/right cycling the selected
  field. When CampRest's `interactive` is False the party rests silently (no menu, no keypress poll, no periodic redraw)
  while the clock, healing and spell preparation still advance. }
{$O+,F+}
unit GameTime;

interface

{ Empty routine with no callers. }
procedure NoopGameTime;

{ Advances the game clock one unit at a time, carrying each component into the next, then ages the party's timed effects
  by the same span.
  @param(amount Number of units.)
  @param(tUnit Clock component counted: 1 minutes, 2 tens of minutes, 3 hours, 4 days, 5 months, 6 years.) }
procedure AdvanceTime(amount: Byte; tUnit: ShortInt);

{ Rests the party for the rest time. Interactive, it first runs the rest menu, redraws the rest time now and then and
  asks whether to stop when a key is pressed. Each five-minute step advances the clock, heals the party once a day,
  carries spell memorizing and scribing forward, and, once per rest period of the zone, rolls the zone's interruption
  chance. Silent rest skips the menu, the redraws and the key check.
  @param(interactive True to show the menu and the rest time.)
  @returns(True when a wandering encounter interrupted the rest.) }
function CampRest(interactive: Boolean): Boolean;

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeGameTime;

implementation

uses Types, TextRend, GameIo, Magic, FxEngine, CharHlp, MenuCore, Debug, Sym8x8, Crt, GDConsts, GDVars, C_Keys, C_Ifc;

procedure NoopGameTime;
begin
end;

procedure PrimeGameTime;
begin
  Debug.PrimeDebug;
  Magic.PrimeMagic;
  FxEngine.PrimeFxEngine;
  CharHlp.PrimeCharHlp;
  MenuCore.PrimeMenuCore;
end;

{ Steps the three top-border ornaments: each has a counter, and once it has reached its limit (8, 1 and 6) the counter
  restarts, the ornament's phase steps through 0..3 and its symbol is redrawn in the top border at column 8, 19 or 30;
  below the limit the counter just counts up. }
procedure ClockDisplay;
var
  { Unused in this version; see the other implementations of this routine. }
  ornament: Byte;
  symCol: Byte;
  symByte: Byte;

  { Counts one hour for one ornament and steps and redraws it when its counter reaches limit. }
  procedure AdvanceTopJunction(n: Word; limit: Byte);
  begin
    if GDVars.zone0^.vars[n + $4B00] >= limit then begin
      if GDVars.zone0^.vars[n + $4B00 - 3] >= 3 then
        GDVars.zone0^.vars[n + $4B00 - 3] := 0
      else
        Inc(GDVars.zone0^.vars[n + $4B00 - 3]);
      case n of
        $1FC: begin symByte := GDVars.zone0^.vars[$4CF9] + 10; symCol := 8; end;
        $1FD: begin symByte := GDVars.zone0^.vars[$4CFA] + 6; symCol := 19; end;
        $1FE: begin symByte := GDVars.zone0^.vars[$4CFB] + 14; symCol := 30; end;
      end;
      Sym8x8.Put8x8Sym(symCol, 0, symByte + 276, False, False);
      GDVars.zone0^.vars[n + $4B00] := 0;
    end else
      Inc(GDVars.zone0^.vars[n + $4B00]);
  end;

begin
  AdvanceTopJunction($1FC, 8);
  AdvanceTopJunction($1FD, 1);
  AdvanceTopJunction($1FE, 6);
end;

{ Ages the timed effects of the party by a span of time, in steps of at most ten minutes; an effect whose time runs out
  is removed, and one with no duration never runs out. A flag per member marks the members that still have timed
  effects. Outside camp every member is aged; in camp only flagged members are, and nothing happens when none is
  flagged. Note: when the effect that runs out is second in a list, aging resumes at the first effect, which is aged
  again.
  @param(count Number of units.)
  @param(tUnit Clock component counted.) }
procedure TimeOutEffects(count: Byte; tUnit: ShortInt);
var
  u: ShortInt;
  i: Byte;
  step: Byte;
  total: Word;
  cur: Types.PCharRecord;
  done: Boolean;
  found: Boolean;
  tail: Types.PEffectRec;
  prev: Types.PEffectRec;
  e: Types.PEffectRec;
begin
  if GDVars.interfaceState <> C_Ifc.CAMPING then
    FillChar(GDVars.effFlags, SizeOf(GDVars.effFlags), 1)
  else begin
    found := False;
    i := 1;
    repeat
      if GDVars.effFlags[i] <> 0 then found := True;
      Inc(i);
    until found or (i > GDVars.zone1^.partySize);
    if not found then Exit;
  end;
  total := count;
  u := tUnit;
  while u > 1 do begin
    total := GDConsts.unitScale[Pred(u)] * total;
    u := Pred(u);
  end;
  while total > 0 do begin
    if total > 10 then step := 10 else step := total;
    i := 1;
    cur := GDVars.partyHead;
    while cur <> nil do begin
      if GDVars.effFlags[i] <> 0 then begin
        GDVars.effFlags[i] := 0;
        e := cur^.effects;
        tail := cur^.effects;
        prev := cur^.effects;
        if cur^.effects <> nil then
          while tail^.next <> nil do tail := tail^.next;
        done := False;
        while (e <> nil) and not done do begin
          if e = tail then done := True;
          if e^.duration = 0 then
            e := e^.next
          else if step < e^.duration then begin
            Dec(e^.duration, step);
            GDVars.effFlags[i] := 1;
            e := e^.next;
          end else begin
            FxEngine.RemoveEffect(cur, e^.id, e);
            if prev = cur^.effects then
              e := cur^.effects
            else
              e := prev^.next;
          end;
          prev := cur^.effects;
          while (prev <> nil) and (prev <> e) and (prev^.next <> e) do
            prev := prev^.next;
        end;
        while e <> nil do begin
          if e^.duration > 0 then GDVars.effFlags[i] := 1;
          e := e^.next;
        end;
      end;
      Inc(i);
      cur := cur^.next;
    end;
    if total > 10 then Dec(total, 10) else total := 0;
  end;
end;

{ Normalizes a clock: each component at or over its unitScale carries into the next. An hour carry steps the top-border
  ornaments (ClockDisplay); a carry out of the last component ages each party member by a year.
  @param(clock The clock to normalize.) }
procedure ValidateClock(var clock: Types.TClock);
var
  i: ShortInt;
  cur: Types.PCharRecord;
begin
  for i := 0 to 6 do
    if clock[i] >= GDConsts.unitScale[i] then
      if i <> 6 then begin
        Inc(clock[Succ(i)]);
        clock[i] := clock[i] - GDConsts.unitScale[i];
        if i = 3 then GameTime.ClockDisplay;
      end else begin
        cur := GDVars.partyHead;
        while cur <> nil do begin
          Inc(cur^.age);
          cur := cur^.next;
        end;
      end;
end;

{ Normalizes the rest time, folds its months into days and caps it at 99 days. }
procedure ValidateRestTime;
begin
  GameTime.ValidateClock(GDVars.restTime);
  if GDVars.restTime[5] > 0 then begin
    Inc(GDVars.restTime[4], GDConsts.unitScale[4] * GDVars.restTime[5]);
    GDVars.restTime[5] := 0;
    if GDVars.restTime[4] > 99 then GDVars.restTime[4] := 99;
  end;
end;

procedure AdvanceTime(amount: Byte; tUnit: ShortInt);
var
  clock: Types.TClock;
  i: ShortInt;
  j: Byte;
begin
  for i := 0 to 6 do
    clock[i] := GDVars.zone0^.vars[i + $4BC6];
  for j := 1 to amount do begin
    Inc(clock[tUnit]);
    GameTime.ValidateClock(clock);
  end;
  for i := 0 to 6 do
    GDVars.zone0^.vars[i + $4BC6] := clock[i];
  GameTime.TimeOutEffects(amount, tUnit);
end;

{ Takes a span off the rest time, borrowing from the larger components as needed; when there is nothing left to borrow,
  the rest time is cleared. Nothing happens when no days, hours or minutes are left.
  @param(count Number of units.)
  @param(tUnit Clock component counted.) }
procedure DecrementRestTime(count: Byte; tUnit: ShortInt);
var
  j: ShortInt;
  k: ShortInt;
begin
  if (GDVars.restTime[4] <> 0) or (GDVars.restTime[3] <> 0) or (GDVars.restTime[2] <> 0) or
      (GDVars.restTime[1] <> 0) then begin
    while count > GDVars.restTime[tUnit] do begin
      j := Succ(tUnit);
      while (GDVars.restTime[j] = 0) and (j < 5) do
        j := Succ(j);
      if j = 5 then begin
        FillChar(GDVars.restTime, SizeOf(GDVars.restTime), 0);
        count := 0;
      end else
        for k := j downto Succ(tUnit) do begin
          Dec(GDVars.restTime[k]);
          Inc(GDVars.restTime[Pred(k)], GDConsts.unitScale[Pred(k)]);
        end;
    end;
    Dec(GDVars.restTime[tUnit], count);
    GameTime.ValidateRestTime;
  end;
end;

{ Formats a number with at least two digits, keeping the first two.
  @param(v The number.)
  @returns(The digits, with a leading zero below 10.) }
function TwoDigitStr(v: Byte): Types.TStr40;
var
  s: Types.TStr40;
begin
  s := CharHlp.Uint8Str(v);
  if v < 10 then s := '0' + s;
  TwoDigitStr := Copy(s, 1, 2);
end;

{ Shows the rest time as days, hours and minutes on the message line, the selected field in white.
  @param(highlightUnit Clock component shown in white: 2 minutes, 3 hours, 4 days; 0 for none.) }
procedure DisplayRestTime(highlightUnit: ShortInt);
var
  i: ShortInt;
  colors: array[0..6] of Word;
  x: Byte;
begin
  for i := 0 to 6 do
    colors[i] := LightGreen;
  colors[highlightUnit] := White;
  TextRend.displayString(1, 17, LightGreen, Black, 'Rest Time:');
  x := 11;
  for i := 4 downto 3 do begin
    TextRend.displayString(x + 1, 17, colors[i], Black, GameTime.TwoDigitStr(GDVars.restTime[i]));
    TextRend.displayString(x + 1 + 2, 17, LightGreen, Black, ':');
    Inc(x, 3);
  end;
  TextRend.displayString(x + 1, 17, colors[2], Black,
                         GameTime.TwoDigitStr(10 * GDVars.restTime[2] + GDVars.restTime[1]));
end;

{ Runs the rest-time menu: Days, Hours and Mins select the field, Add and Subtract (or the up and down arrows) change
  it, minutes by five, and the left and right arrows move between the fields. Rest or Enter starts resting; Exit or
  Escape leaves.
  @returns(True when Rest was chosen.) }
function CampRestMenu: Boolean;
var
  ext: Boolean;
  ch: Char;
  sel: ShortInt;
begin
  CampRestMenu := False;
  sel := 2;
  repeat
    GameTime.DisplayRestTime(sel);
    ch := MenuCore.MenuHorizontal('', 'Rest Days Hours Mins Add Subtract Exit', LightMagenta, LightGreen, White, True,
                                  False, ext);
    if ext then
      case ch of
        { up arrow    -> 'A'dd }
        C_Keys.UP: ch := 'A';
        { down arrow -> 'S'ubtract }
        C_Keys.DOWN: ch := 'S';
        C_Keys.LEFT: begin
                Inc(sel);
                if sel > 4 then sel := 2;
                ch := 'X';
              end;
        C_Keys.RIGHT: begin
                Dec(sel);
                if sel < 2 then sel := 4;
                ch := 'X';
              end;
      else
        ch := 'X';
      end;
    if ch = C_Keys.ENTER then ch := 'R';
    case ch of
      'R': CampRestMenu := True;
      'D': sel := 4;
      'H': sel := 3;
      'M': sel := 2;
      'A': begin
             if sel = 2 then
               Inc(GDVars.restTime[1], 5)
             else
               Inc(GDVars.restTime[sel]);
             GameTime.ValidateRestTime;
           end;
      'S': begin
             if sel = 2 then
               GameTime.DecrementRestTime(5, 1)
             else
               GameTime.DecrementRestTime(1, sel);
             GameTime.ValidateRestTime;
           end;
    end;
  until ch in [C_Keys.NONE, 'E', 'R'];
end;

{ Counts one five-minute rest step; once a day of steps has passed, restores a hit point to each party member, shows
  "The Whole Party Is Healed" and pauses, redrawing the party when anyone was healed.
  @param(interactive True to redraw the rest time first.) }
procedure CheckRestingHeal(interactive: Boolean);
var
  healed: Boolean;
  cur: Types.PCharRecord;
begin
  Inc(GDVars.healTicks);
  if GDVars.healTicks >= 288 then begin
    healed := False;
    cur := GDVars.partyHead;
    while cur <> nil do begin
      if FxEngine.RestoreHitPoints(cur, 1, False) then healed := True;
      cur := cur^.next;
    end;
    if interactive then GameTime.DisplayRestTime(0);
    TextRend.displayString(1, 19, LightGreen, Black, 'The Whole Party Is Healed');
    if healed then CharHlp.DisplayParty(GDVars.curChar);
    TextRend.pauseOnly;
    CharHlp.ClearMessageWindow;
    GDVars.healTicks := 0;
  end;
end;

{ Scans a character's memorized-spell slots for spells still being memorized. Unless the finished flag is already set,
  the first such spell is finished and announced, and the flag is set; the scan then goes on to the next one.
  @param(cr The character.)
  @param(done The finished flag: True to only look up the next pending spell; set when a spell is finished.)
  @returns(The level of the next spell still pending, or 0 when there is none.) }
function CheckMemorizeDone(cr: Types.PCharRecord; var done: Boolean): Byte;
var
  lvl: Byte;
  i: Byte;
begin
  lvl := 0;
  i := 0;
  while (i <= 57) and (lvl = 0) do begin
    if cr^.memorized[i] > $7F then
      if done then
        lvl := GDConsts.spellTbl[cr^.memorized[i] and $7F].level
      else begin
        Dec(cr^.memorized[i], $80);
        GameTime.DisplayRestTime(0);
        Magic.PrintCastSpellMsg(cr, 'has memorized', cr^.memorized[i]);
        done := True;
      end;
    Inc(i);
  end;
  CheckMemorizeDone := lvl;
end;

{ Does for scribing what CheckMemorizeDone does for memorizing, over the spells queued for scribing on the character's
  readable scrolls. Finishing one marks the spell known, removes it from the scroll and announces it. Note: removing the
  spell may free the scroll while the scan goes on reading it.
  @param(cr The character.)
  @param(done True to only look up the next pending spell; set when a spell is finished.)
  @returns(The level of the next spell still pending, or 0 when there is none.) }
function CheckScribeDone(cr: Types.PCharRecord; var done: Boolean): Byte;
var
  j: Byte;
  sp: Byte;
  lvl: Byte;
  it: Types.PItemRec;
  { Unused in this version; see the other implementations of this routine. }
  found: Boolean;
begin
  lvl := 0;
  found := False;
  it := cr^.itemsAddr;
  while (it <> nil) and (lvl = 0) do begin
    j := 1;
    if Magic.ItemReadable(it) then
      while (j <= 3) and (lvl = 0) do begin
        if it^.spells[j] > $80 then begin
          found := True;
          if done then
            lvl := GDConsts.spellTbl[it^.spells[j] and $7F].level
          else begin
            sp := it^.spells[j] and $7F;
            cr^.spellsKnown[sp] := 1;
            Magic.RemoveSpellFromScroll(cr, it, sp);
            GameTime.DisplayRestTime(0);
            Magic.PrintCastSpellMsg(cr, 'has scribed', sp);
            done := True;
          end;
        end;
        Inc(j);
      end;
    it := it^.next;
  end;
  CheckScribeDone := lvl;
end;

{ Counts down each party member's spell-preparation timer; when it runs out and the member's preparation wait is over,
  the next spell being scribed or else memorized is finished and the timer restarts at three times the following spell's
  level. }
procedure AdvanceSpellPrep;
var
  i: Byte;
  lvl: Byte;
  cur: Types.PCharRecord;
  done: Boolean;
begin
  i := 1;
  cur := GDVars.partyHead;
  while cur <> nil do begin
    if GDVars.prepTimers[i] > 0 then Dec(GDVars.prepTimers[i]);
    if (GDVars.prepTimers[i] = 0) and (cur^.spellPrep = 0) then begin
      done := False;
      lvl := GameTime.CheckScribeDone(cur, done);
      if lvl = 0 then lvl := GameTime.CheckMemorizeDone(cur, done);
      GDVars.prepTimers[i] := lvl * 3;
    end;
    cur := cur^.next;
    Inc(i);
  end;
end;

{ Counts rest steps; every twelfth step, each party member's preparation wait drops by one, and when it reaches zero the
  member's spell-preparation timer starts at three times the level of the next spell to scribe or memorize.
  @param(tick The step counter, kept by the caller.) }
procedure AdvanceSpellPrepBase(var tick: Byte);
var
  i: Byte;
  lvl: Byte;
  cur: Types.PCharRecord;
  done: Boolean;
begin
  Inc(tick);
  if tick >= 12 then begin
    tick := 0;
    i := 1;
    cur := GDVars.partyHead;
    while cur <> nil do begin
      if cur^.spellPrep > 0 then begin
        Dec(cur^.spellPrep);
        if cur^.spellPrep = 0 then begin
          done := True;
          lvl := GameTime.CheckScribeDone(cur, done);
          if lvl = 0 then lvl := GameTime.CheckMemorizeDone(cur, done);
          GDVars.prepTimers[i] := lvl * 3;
        end;
      end;
      cur := cur^.next;
      Inc(i);
    end;
  end;
end;

function CampRest(interactive: Boolean): Boolean;
var
  cur: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  member: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  memberCount: Byte;
  i: Byte;
  tick: Byte;
  cnt: Byte;
  stop: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  interrupted: Boolean;
begin
  CampRest := False;
  interrupted := False;
  i := 1;
  cur := GDVars.partyHead;
  while cur <> nil do begin
    GDVars.prepTimers[i] := 0;
    Inc(i);
    cur := cur^.next;
  end;
  FillChar(GDVars.effFlags, SizeOf(GDVars.effFlags), 1);
  tick := 0;
  cnt := 0;
  if interactive then begin
    TextRend.ClearRect(1, 17, 38, 22);
    GameTime.DisplayRestTime(0);
  end;
  GDVars.noBorder := 1;
  if interactive then
    stop := not GameTime.CampRestMenu
  else
    stop := False;
  while (not stop) and ((GDVars.restTime[4] > 0) or (GDVars.restTime[3] > 0) or (GDVars.restTime[2] > 0) or
                        (GDVars.restTime[1] > 0)) do begin
    if interactive and GameIo.InputPending then begin
      GameTime.DisplayRestTime(0);
      if MenuCore.YesNoMenu('Stop Resting? ', LightMagenta, LightGreen, White) = 'Y' then
        stop := True
      else
        MenuCore.ClearBottomLine;
    end;
    if not stop then begin
      GameTime.DecrementRestTime(5, 1);
      Inc(cnt);
      if interactive and (cnt >= 5) then begin
        GameTime.DisplayRestTime(0);
        cnt := 0;
      end;
      GameTime.AdvanceTime(5, 1);
      GameTime.CheckRestingHeal(interactive);
      GameTime.AdvanceSpellPrep;
      GameTime.AdvanceSpellPrepBase(tick);
      if GDVars.zone1^.restPeriod > 0 then begin
        Inc(GDVars.restTicks);
        if GDVars.restTicks >= GDVars.zone1^.restPeriod then begin
          GDVars.restTicks := 0;
          if FxEngine.RollDice(1, 100) <= GDVars.zone1^.interruptPct then begin
            CharHlp.ClearMessageWindow;
            GameTime.DisplayRestTime(0);
            TextRend.displayString(1, 19, White, Black, 'Your repose is suddenly interrupted!');
            stop := True;
            CampRest := True;
            TextRend.pauseOnly;
          end;
        end;
      end;
    end;
  end;
  TextRend.ClearRect(1, 17, 38, 22);
  GDVars.noBorder := 0;
end;

begin
end.
