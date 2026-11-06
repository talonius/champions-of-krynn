{ The horizontal and vertical menus and the string-list helpers they use. }
{$O+,F+}
unit MenuCore;

interface

uses Types, Crt, TextRend, GameIo, Mouse, Joystick, Border, Portrait, CbtMap, Debug, GDConsts, GDVars, C_Keys, C_Screen,
  C_Ifc;

{ Finds a member of a string list by position.
  @param(n The member's position, counting from 0.)
  @param(list The list's first member.)
  @returns(The member, or nil when the list is shorter.) }
function FindListMember(n: Integer; list: Types.PItemRec): Types.PItemRec;

{ Shows query and a one-line menu on the bottom row and waits for a choice. Each option starts at a digit or capital
  letter, its hotkey, drawn in hlCol; the highlighted option (horizontalChoice, kept between calls) is drawn inverse.
  With several options the left and right arrows, or 4 and 6, move the highlight, wrapping; any other extended key is
  returned as its scan code. A hotkey picks its option; Space returns ' ' and Escape #0. Enter takes the highlighted
  option, unless it came from a mouse click: a click on the party list makes that member current (altChar while
  useAlternateSelection is set) and returns the up arrow, a click on the combat or exploration map returns the arrow
  toward it, a click on the bottom row picks the option under it, and a click while modifying a character returns Home
  with the row in modifyMouseRow. While it waits the portrait animation plays when animate asks for it and frames are
  loaded; once autoTimeout ticks pass with no new frame, timerCh is returned. Afterwards pending keys are drained and it
  waits for the mouse or joystick buttons to be released; extendedKeyFlag mirrors ext.
  @param(query Text shown first, in qCol; empty for none.)
  @param(menu The options.)
  @param(qCol Color of the query.)
  @param(mCol Color of the option text.)
  @param(hlCol Color of the hotkeys and the highlight; 0 for no highlight.)
  @param(reinterpret True to return the digits 1 to 9 as keypad scan codes, and the backslash as 7.)
  @param(animate True to play the portrait animation.)
  @param(ext Set when the result is a scan code.)
  @returns(The chosen option's hotkey, a space, #0 for Escape, timerCh or a scan code.) }
function MenuHorizontal(query, menu: Types.TStr40; qCol, mCol, hlCol: Byte; reinterpret, animate: Boolean;
                        var ext: Boolean): Char;

{ Blanks the bottom text row. }
procedure ClearBottomLine;

{ Runs a menu over a string list in a window. Members with inUse set are labels, drawn in qCol and skipped by the
  highlight; the others are choices, drawn in mCol. A horizontal menu on the bottom row (MenuHorizontal) takes the
  command: menu's options, then Next when a later page exists, Prev when the page top is past the leading labels, and
  Exit with addExit. The up and down arrows move the highlight, wrapping within the page and the list; Page Up and Page
  Down turn pages when Prev and Next are offered, P and N whether or not they are; a mouse click on a row moves the
  highlight there. The page top (firstVisibleIndex) is kept between calls; it is pulled back to idx when it lies past
  it, and to 0 when it lies past the end of the list. horizontalChoice starts at 1.
  @param(query Text shown before the command menu.)
  @param(menu The command menu's own options.)
  @param(qCol Color of the query and the labels.)
  @param(mCol Color of the choices and the command menu.)
  @param(hlCol Color of the highlight and the hotkeys.)
  @param(ulCol Left column of the window.)
  @param(ulRow Top row of the window.)
  @param(lrCol Right column of the window.)
  @param(lrRow Bottom row of the window.)
  @param(list The list's first member; nil returns at once.)
  @param(addExit True to offer Exit.)
  @param(redraw True to redraw the window first, which a page top pulled back also forces; cleared unless list is nil.)
  @param(idx The highlighted member, counting from 0, kept between calls; set to 0 for an empty list.)
  @param(sel Receives the highlighted member when a command is chosen, or nil.)
  @returns(The command key, or #0 for Escape, Exit or an empty list.) }
function MenuVertical(query, menu: Types.TStr40; qCol, mCol, hlCol: Byte; ulCol, ulRow, lrCol, lrRow: ShortInt;
                      list: Types.PItemRec; addExit: Boolean; var redraw: Boolean; var idx: Integer; var sel:
                          Types.PItemRec): Char;

{ Asks query with a Yes/No menu, No highlighted first, until Y or N is chosen; Escape does not leave it.
  @param(query The question.)
  @param(qCol Color of the question.)
  @param(mCol Color of the options.)
  @param(hlCol Color of the hotkeys and the highlight.)
  @returns('Y' or 'N'.) }
function YesNoMenu(query: Types.TStr40; qCol, mCol, hlCol: Byte): Char;

{ Allocates a list of empty members, as many as asked; the first is allocated before the count is read, so a count below
  1 gives one member.
  @param(n Members wanted.)
  @param(list Receives the first member.) }
procedure AllocStringList(n: Integer; var list: Types.PItemRec);

{ Frees each member of a string list; the caller's pointer is not set to nil.
  @param(list The list's first member, or nil.) }
procedure FreeStringList(var list: Types.PItemRec);

{ Calls the priming entries of Portrait and the trace overlay, so the overlay manager loads them; the other overlays
  this unit uses are not primed here. }
procedure PrimeMenuCore;

implementation

type
  TOptionRange = record firstChar: Byte; lastChar: Byte end;

procedure PrimeMenuCore;
begin
  Portrait.PrimePortrait;
  Debug.PrimeDebug;
end;

function FindListMember(n: Integer; list: Types.PItemRec): Types.PItemRec;
var
  p: Types.PItemRec;
  i: Integer;
begin
  i := 0;
  p := list;
  while (p <> nil) and (i <> n) do begin
    p := p^.next;
    Inc(i);
  end;
  if i = n then
    FindListMember := p
  else
    FindListMember := nil;
end;

{ Counts the members of a string list.
  @param(list The list's first member, or nil.)
  @returns(The number of members.) }
function ListCount(list: Types.PItemRec): Integer;
var
  p: Types.PItemRec;
  n: Integer;
begin
  n := 0;
  p := list;
  while p <> nil do begin
    Inc(n);
    p := p^.next;
  end;
  ListCount := n;
end;

function MenuHorizontal(query, menu: Types.TStr40; qCol, mCol, hlCol: Byte; reinterpret, animate: Boolean;
                        var ext: Boolean): Char;
var
  frameTick: LongInt;
  tick30: LongInt;
  { Unused in this version; see the other implementations of this routine. }
  tick80: LongInt;
  ch: Char;
  mouseCellY: Integer;
  mouseCellX: Integer;
  byteIndex: Byte;
  columnIndex: Byte;
  done: Boolean;
  menuLength: Byte;
  queryLength: Byte;
  options: array[1..20] of TOptionRange;
  optionCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  acceptEnter: Boolean;
  mapCell: Types.PCharRecord;
  inputValue: Integer;
  inputX: Integer;
  inputY: Integer;

  { Splits the menu text into options, each starting at a digit or capital letter, its hotkey. }
  procedure ParseMenu(m: Types.TStr40);
  var
    idx: Byte;
    i: Byte;
    len: Byte;
    { Unused in this version; see the other implementations of this routine. }
    hotkey: Byte;
  begin
    FillChar(options, SizeOf(options), 0);
    idx := 1;
    len := Length(m);
    for i := 1 to len do
      if m[i] in ['0'..'9', 'A'..'Z'] then
        if options[idx].firstChar = 0 then
          options[idx].firstChar := i
        else begin
          options[idx].lastChar := i - 2;
          Inc(idx);
          options[idx].firstChar := i;
        end;
    options[idx].lastChar := len;
    optionCount := idx;
  end;

  { Redraws the menu after the query with option cur highlighted and the hotkeys in hlCol, and blanks the rest. }
  procedure DisplayOption(cur: Byte);
  var
    i: Byte;
  begin
    Mouse.HideMouse;
    if menuLength > 0 then begin
      for i := 1 to menuLength do
        if (options[cur].firstChar <= i) and (options[cur].lastChar >= i) and (hlCol <> 0) then
          TextRend.renderChar(queryLength + i - 1, C_Screen.PROMPT_ROW, Black, hlCol, 1, Ord(menu[i]), 1)
        else if menu[i] in ['0'..'9', 'A'..'Z'] then
          TextRend.renderChar(queryLength + i - 1, C_Screen.PROMPT_ROW, hlCol, Black, 1, Ord(menu[i]), 1)
        else
          TextRend.renderChar(queryLength + i - 1, C_Screen.PROMPT_ROW, mCol, Black, 1, Ord(menu[i]), 1);
      if queryLength + menuLength < 39 then
        TextRend.renderChar(queryLength + menuLength, C_Screen.PROMPT_ROW, Black, Black,
                            39 - menuLength - queryLength + 1, 32, 1);
    end;
    Mouse.ShowMouse;
  end;

begin
  GDVars.extendedKeyFlag := False;
  acceptEnter := (mCol <> 0) or (hlCol <> 0);
  queryLength := Length(query) + 0;
  ParseMenu(menu);
  if GDVars.horizontalChoice > optionCount then
    GDVars.horizontalChoice := 1;
  menuLength := Length(menu);
  ch := #0;
  ext := False;
  done := False;
  frameTick := TextRend.getTicks;
  tick30 := TextRend.getTicks + 30;
  tick80 := tick30 + 50;
  if Length(query) <> 0 then
    TextRend.displayString(0, C_Screen.PROMPT_ROW, qCol, Black, query);
  DisplayOption(GDVars.horizontalChoice);
  { pre-loop animation prime (not inside the repeat) }
  if animate and (GDVars.bigAnim.currentFrame > 0) then begin
    Portrait.DisplayImageBuf(3, 3, animate, GDVars.bigAnim.frames[GDVars.bigAnim.currentFrame].image);
    if GDVars.bigAnim.frameCount < 2 then
      animate := False;
  end;
  repeat
    { animation advance. }
    if animate and (GDVars.bigAnim.currentFrame > 0) then
      if TextRend.getTicks - frameTick >=
          GDVars.bigAnim.frames[GDVars.bigAnim.currentFrame].duration * 10 then begin
        Inc(GDVars.bigAnim.currentFrame);
        if GDVars.bigAnim.currentFrame > GDVars.bigAnim.frameCount then
          GDVars.bigAnim.currentFrame := 1;
        Portrait.DisplayImageBuf(3, 3, animate, GDVars.bigAnim.frames[GDVars.bigAnim.currentFrame].image);
        frameTick := TextRend.getTicks;
      end;
    { auto-answer timer. }
    if GDVars.autoTimeout > 0 then
      if TextRend.getTicks - frameTick >= GDVars.autoTimeout then begin
        ch := GDVars.timerCh;
        done := True;
      end;
    { key dispatch. }
    if GameIo.InputPending then begin
      ch := GameIo.ReadGameKey;
      if ch = #0 then begin
        { extended (arrow) key. }
        ch := GameIo.ReadGameKey;
        ext := True;
        if optionCount > 1 then
          case ch of
            C_Keys.LEFT:
            begin
              if GDVars.horizontalChoice = 1 then GDVars.horizontalChoice := optionCount
              else Dec(GDVars.horizontalChoice);
              DisplayOption(GDVars.horizontalChoice);
            end;
            C_Keys.RIGHT:
            begin
              if GDVars.horizontalChoice = optionCount then GDVars.horizontalChoice := 1
              else Inc(GDVars.horizontalChoice);
              DisplayOption(GDVars.horizontalChoice);
            end;
          else done := True;
          end else done := True;
      end else begin
        { normal key. }
        ext := False;
        case ch of
          { ESC }
          C_Keys.ESCAPE:
          begin
            done := True;
            ch := #0;
          end;
          { ENTER -> mouse hit-test }
          C_Keys.ENTER:
            if GDVars.mouseButtonSeen <> 0 then begin
              mouseCellX := GDVars.mouseY div 8;
              mouseCellY := GDVars.mouseX div 8;
              if (GDVars.partyPickEnabled <> 0) and
                  ((GDVars.interfaceState <> C_Ifc.OVERLAND) or (GDVars.zone0^.areaView <> 0)) and
                  (GDVars.extendedMode = 0) and (GDVars.interfaceState <> C_Ifc.IN_COMBAT) and
                  (GDVars.screenColumnLo <= mouseCellY) and (GDVars.screenColumnHi >= mouseCellY) and
                  (GDVars.screenRowLo <= mouseCellX) and (GDVars.screenRowHi >= mouseCellX) then begin
                byteIndex := mouseCellX - GDVars.screenRowLo;
                mapCell := GDVars.partyHead;
                for columnIndex := 1 to byteIndex do
                  if mapCell <> nil then
                    mapCell := mapCell^.next;
                if mapCell <> nil then begin
                  if GDVars.useAlternateSelection <> 0 then GDVars.altChar := mapCell
                  else GDVars.curChar := mapCell;
                  ch := C_Keys.UP;
                  ext := True;
                  done := True;
                end;
              end else if ((GDVars.creatureCursorActive <> 0) or (GDVars.mapCursorActive <> 0)) and
                          (GDVars.interfaceState = C_Ifc.IN_COMBAT) and (mouseCellY >= 1) and (mouseCellY <= 21) and
                          (mouseCellX >= 1) and (mouseCellX <= 21) then begin
                { mouse-on-map A (view pane). }
                ext := True;
                if GDVars.mapCursorActive <> 0 then begin
                  inputX := GDVars.cursorX - GDVars.arena^.originX + 1;
                  inputY := GDVars.cursorY - GDVars.arena^.originY + 1;
                end else begin
                  byteIndex := CbtMap.CombatSlot(Types.PCharRecord(GDVars.curChar));
                  inputX := GDVars.arenaLoc[byteIndex].x - GDVars.arena^.originX + 1;
                  inputY := GDVars.arenaLoc[byteIndex].y - GDVars.arena^.originY + 1;
                end;
                ch := Char(Mouse.MouseDirection(inputX, inputY, mouseCellY div 3 + 1, mouseCellX div 3 + 1));
                done := True;
              end else if (GDVars.extendedMode <> 0) and
                (((mouseCellY >= 3) and (mouseCellY <= 13) and (mouseCellX >= 3) and (mouseCellX <= 13)) or
                 ((GDVars.zone0^.view3dFlag = 0) and (GDVars.interfaceState = C_Ifc.OVERLAND) and (mouseCellY >= 1) and
                  (mouseCellY <= 38) and (mouseCellX >= 1) and (mouseCellX <= 15))) then begin
                { mouse-on-map B (combat / arena). }
                ext := True;
                if GDVars.zone0^.view3dFlag = 0 then
                  ch := Char(Mouse.MouseDirection(GDVars.zone0^.partyX + 1, GDVars.zone0^.partyY + 1, mouseCellY,
                                                  mouseCellX))
                else
                  ch := Char(GDConsts.combatMap[mouseCellX, mouseCellY]);
                done := True;
              end else if (mouseCellX = 24) and not done then begin
                { hotspot / option-column scan }
                Inc(mouseCellY);
                if queryLength < mouseCellY then begin
                  mouseCellY := mouseCellY - queryLength;
                  for byteIndex := 1 to optionCount do
                    if (options[byteIndex].firstChar <= mouseCellY) and
                       (options[byteIndex].lastChar >= mouseCellY) then begin
                      ch := menu[options[byteIndex].firstChar];
                      GDVars.horizontalChoice := byteIndex;
                      DisplayOption(GDVars.horizontalChoice);
                      done := True;
                    end;
                end;
              end else if (GDVars.modifyActive <> 0) and not done then begin
                { joystick direction. }
                done := True;
                case mouseCellX of
                  1: if (mouseCellY >= 1) and (mouseCellY <= 16) then GDVars.modifyMouseRow := 6;
                  3: if (mouseCellY >= 31) and (mouseCellY <= 33) then GDVars.modifyMouseRow := 7;
                  9..14: if (mouseCellY >= 5) and (mouseCellY <= 9) then GDVars.modifyMouseRow := mouseCellX - 9;
                else
                  done := False;
                end;
                ext := True;
                ch := C_Keys.HOME;
              end else if (not done) and (GDVars.keyRowLo <= mouseCellY) and
                          (GDVars.keyRowHi >= mouseCellY) then begin
                { key/hotspot-key match fallback. }
                byteIndex := 1;
                while (byteIndex <= 25) and (GDVars.hotspotRows[byteIndex] <> 255) and not done do begin
                  if GDVars.hotspotRows[byteIndex] <= mouseCellX then done := True;
                  Inc(byteIndex);
                end;
              end;
            end else begin
              { default select (no mouse). }
              ch := menu[options[GDVars.horizontalChoice].firstChar];
              if ch = C_Keys.NONE then ch := C_Keys.ENTER;
              done := True;
            end;
          { reinterpret scancode '4' }
          '4':
          begin
            if optionCount > 1 then begin
              if GDVars.horizontalChoice = 1 then GDVars.horizontalChoice := optionCount
              else Dec(GDVars.horizontalChoice);
              DisplayOption(GDVars.horizontalChoice);
            end else begin
              if reinterpret then begin
                ch := Char(GDConsts.digitScanCodes[Ord(ch) - Ord('1')]);
                ext := True;
              end;
              done := True;
            end;
          end;
          { reinterpret scancode '6' }
          '6':
          begin
            if optionCount > 1 then begin
              if GDVars.horizontalChoice = optionCount then GDVars.horizontalChoice := 1
              else Inc(GDVars.horizontalChoice);
              DisplayOption(GDVars.horizontalChoice);
            end else begin
              done := True;
              if reinterpret then begin
                ch := Char(GDConsts.digitScanCodes[Ord(ch) - Ord('1')]);
                ext := True;
              end;
            end;
          end;
        else
          { char-select (default). }
          ch := UpCase(ch);
          if ch in [' ', '0'..'9', 'A'..'Z'] then
          begin
            if ch = ' ' then done := True
            else begin
              for byteIndex := 1 to menuLength do
                if menu[byteIndex] = ch then begin
                  done := True;
                  mouseCellY := 1;
                  while byteIndex <> options[mouseCellY].firstChar do
                    Inc(mouseCellY);
                  GDVars.horizontalChoice := mouseCellY;
                  DisplayOption(GDVars.horizontalChoice);
                end;
            end;
          end;
          if reinterpret then
            if ch in ['1'..'9', '\'] then
            begin
              if ch = '\' then ch := '7'
              else ch := Char(GDConsts.digitScanCodes[Ord(ch) - Ord('1')]);
              ext := True;
              done := True;
            end;
        end;
      end;
    end;
  until done;
  { epilogue. }
  MenuHorizontal := ch;
  GDVars.extendedKeyFlag := ext;
  GameIo.FlushKeys;
  if GDVars.mouseButtonSeen <> 0 then
    repeat Mouse.GetMouse(inputValue, inputX, inputY) until inputValue = 0
  else if GDVars.joyOn then
    repeat Joystick.GetJoystick(inputValue, byteIndex) until inputValue = 0;
end;

procedure ClearBottomLine;
begin
  TextRend.printSpaces(0, C_Screen.PROMPT_ROW, Black, 40);
end;

function MenuVertical(query, menu: Types.TStr40; qCol, mCol, hlCol: Byte; ulCol, ulRow, lrCol, lrRow: ShortInt;
                      list: Types.PItemRec; addExit: Boolean; var redraw: Boolean; var idx: Integer; var sel:
                          Types.PItemRec): Char;
var
  width: Byte;
  { hotspot-row counter (DrawPage + mouse test) }
  line: Byte;
  count: Integer;
  ext: Boolean;
  rows: Integer;
  ch: Char;
  horizontalMenu: Types.TStr40;
  hasNextPage: Boolean;
  hasPreviousPage: Boolean;
  p: Types.PItemRec;
  labelCount: Integer;
  total: Integer;
  mouseRow: Byte;
  mouseColumn: Byte;

  { Returns the last label among the first n members, else the first member if it is a label, else nil. }
  function LastLabelBefore(n: Integer; l: Types.PItemRec): Types.PItemRec;
  var
    pp: Types.PItemRec;
    found: Types.PItemRec;
    i: Integer;
  begin
    i := 0;
    pp := l;
    found := nil;
    while (pp <> nil) and (i < n) do begin
      if pp^.inUse <> 0 then
        found := pp;
      pp := pp^.next;
      Inc(i);
    end;
    if (found = nil) and (l^.inUse <> 0) then
      LastLabelBefore := l
    else
      LastLabelBefore := found;
  end;

  { Clears the window and draws one member per row from member top on, recording each row in hotspotRows. }
  procedure DrawPage(top: Integer);
  var
    pp: Types.PItemRec;
    { Unused in this version; see the other implementations of this routine. }
    q: Types.PItemRec;
    row: ShortInt;
  begin
    FillChar(GDVars.hotspotRows, SizeOf(GDVars.hotspotRows), 255);
    Border.ClearBox(ulCol, ulRow, lrCol, lrRow);
    Mouse.HideMouse;
    pp := MenuCore.FindListMember(top, list);
    q := LastLabelBefore(top, list);
    row := ulRow;
    line := 1;
    while (pp <> nil) and (row <= lrRow) do begin
      GDVars.hotspotRows[line] := row;
      if pp^.inUse <> 0 then
        TextRend.displayString(ulCol, row, qCol, Black, pp^.name)
      else
        TextRend.displayString(ulCol, row, mCol, Black, pp^.name);
      if Length(pp^.name) < width then
        TextRend.renderChar(ulCol + Length(pp^.name), row, Black, Black, width - Length(pp^.name), 32, 1);
      pp := pp^.next;
      Inc(row);
      Inc(line);
    end;
    Mouse.ShowMouse;
  end;

  { Returns the position of the first non-space character of s (its length when all spaces, 1 when empty). }
  function FirstNonBlank(s: Types.TStr40): Byte;
  var
    i: Byte;
    len: Byte;
  begin
    i := 1;
    len := Length(s);
    while (i < len) and (s[i] = ' ') do
      Inc(i);
    FirstNonBlank := i;
  end;

  { Returns the position of the last non-space character of s (1 when all spaces, 0 when empty). }
  function LastNonBlank(s: Types.TStr40): Byte;
  var
    n: Byte;
  begin
    n := Length(s);
    while (n > 1) and (s[n] = ' ') do
      Dec(n);
    LastNonBlank := n;
  end;

  { Redraws member n, trimmed of spaces, inverse in hlCol. }
  procedure HighlightLine(n: Integer);
  var
    pp: Types.PItemRec;
    a: Byte;
    b: Byte;
  begin
    pp := MenuCore.FindListMember(n, list);
    a := FirstNonBlank(pp^.name);
    b := LastNonBlank(pp^.name) - a + 1;
    TextRend.displayString(ulCol + a - 1, ulRow + (n - GDVars.firstVisibleIndex), Black, hlCol, Copy(pp^.name, a, b));
  end;

  { Redraws member n, trimmed of spaces, in its resting color (qCol for a label, mCol otherwise). }
  procedure UnhighlightLine(n: Integer);
  var
    pp: Types.PItemRec;
    a: Byte;
    b: Byte;
  begin
    pp := MenuCore.FindListMember(n, list);
    a := FirstNonBlank(pp^.name);
    b := LastNonBlank(pp^.name) - a + 1;
    if pp^.inUse <> 0 then
      TextRend.displayString(ulCol + a - 1, ulRow + (n - GDVars.firstVisibleIndex), qCol, Black, Copy(pp^.name, a, b))
    else
      TextRend.displayString(ulCol + a - 1, ulRow + (n - GDVars.firstVisibleIndex), mCol, Black, Copy(pp^.name, a, b));
  end;

  { Moves the highlight off labels, wrapping within the page, for at most a page of steps. }
  procedure SkipLabels(down: Boolean);
  var
    k: Integer;
  begin
    k := 0;
    if down then begin
      while (k < rows) and (MenuCore.FindListMember(idx, list)^.inUse <> 0) do begin
        Inc(k);
        Inc(idx);
        if GDVars.firstVisibleIndex + rows - 1 < idx then
          idx := GDVars.firstVisibleIndex;
        if count - 1 < idx then
          idx := GDVars.firstVisibleIndex;
      end;
    end else
      while (k < rows) and (MenuCore.FindListMember(idx, list)^.inUse <> 0) do begin
        Inc(k);
        Dec(idx);
        if idx < GDVars.firstVisibleIndex then
          idx := GDVars.firstVisibleIndex + rows - 1;
        if count - 1 < idx then
          idx := count - 1;
      end;
  end;

  { Turns a page down or up, keeping the highlight on the same row, then moves it off labels and redraws the window. }
  procedure MovePage(down: Boolean);
  var
    rel: Integer;
  begin
    rel := idx - GDVars.firstVisibleIndex;
    if down then begin
      Inc(GDVars.firstVisibleIndex, rows);
      if count - rows < GDVars.firstVisibleIndex then
        GDVars.firstVisibleIndex := count - rows;
    end else begin
      Dec(GDVars.firstVisibleIndex, rows);
      if GDVars.firstVisibleIndex < 0 then
        GDVars.firstVisibleIndex := 0;
    end;
    idx := GDVars.firstVisibleIndex + rel;
    SkipLabels(down);
    DrawPage(GDVars.firstVisibleIndex);
  end;

  { Moves the highlight one member down or up, wrapping within the page, then off labels. }
  procedure MoveLine(down: Boolean);
  var
    { Unused in this version; see the other implementations of this routine. }
    pp: Types.PItemRec;
    { Unused in this version; see the other implementations of this routine. }
    k: Integer;
    { Unused in this version; see the other implementations of this routine. }
    n: Integer;
  begin
    if down then begin
      Inc(idx);
      if GDVars.firstVisibleIndex + rows - 1 < idx then
        idx := GDVars.firstVisibleIndex;
      if count - 1 < idx then
        idx := GDVars.firstVisibleIndex;
    end else begin
      Dec(idx);
      if idx < GDVars.firstVisibleIndex then
        idx := GDVars.firstVisibleIndex + rows - 1;
      if count - 1 < idx then
        idx := count - 1;
    end;
    SkipLabels(down);
  end;

begin
  if list = nil then begin
    idx := 0;
    sel := nil;
    GDVars.keyRowLo := 127;
    GDVars.keyRowHi := -128;
    MenuVertical := C_Keys.NONE;
  end else begin
    GDVars.keyRowLo := ulCol;
    GDVars.keyRowHi := lrCol;
    GDVars.horizontalChoice := 1;
    width := lrCol - ulCol + 1;
    count := MenuCore.ListCount(list);
    rows := lrRow - ulRow + 1;
    p := list;
    labelCount := 0;
    while (p <> nil) and (p^.inUse <> 0) do begin
      p := p^.next;
      Inc(labelCount);
    end;
    p := list;
    total := 0;
    while p <> nil do begin
      p := p^.next;
      Inc(total);
    end;
    if total <= rows then
      GDVars.firstVisibleIndex := 0;
    if GDVars.firstVisibleIndex > idx then begin
      GDVars.firstVisibleIndex := idx;
      redraw := True;
    end;
    if GDVars.firstVisibleIndex > total then begin
      GDVars.firstVisibleIndex := 0;
      redraw := True;
    end;
    Inc(idx);
    MoveLine(False);
    if redraw then
      DrawPage(GDVars.firstVisibleIndex);
    redraw := False;
    repeat
      HighlightLine(idx);
      horizontalMenu := menu;
      hasNextPage := False;
      hasPreviousPage := False;
      if count - rows > GDVars.firstVisibleIndex then begin
        horizontalMenu := horizontalMenu + ' Next';
        hasNextPage := True;
      end;
      if GDVars.firstVisibleIndex > labelCount then begin
        horizontalMenu := horizontalMenu + ' Prev';
        hasPreviousPage := True;
      end;
      if addExit then
        horizontalMenu := horizontalMenu + ' Exit';
      ch := MenuCore.MenuHorizontal(query, horizontalMenu, qCol, mCol, hlCol, True, False, ext);
      UnhighlightLine(idx);
      if ext then
        case ch of
          C_Keys.UP: MoveLine(False);
          C_Keys.DOWN: MoveLine(True);
          C_Keys.PAGE_UP: if hasPreviousPage then MovePage(False);
          C_Keys.PAGE_DOWN: if hasNextPage then MovePage(True);
        end else
        case ch of
          'P': MovePage(False);
          'N': MovePage(True);
          C_Keys.ESCAPE, 'E', C_Keys.NONE:
            begin
              sel := nil;
              MenuVertical := C_Keys.NONE;
              GDVars.keyRowLo := 127;
              GDVars.keyRowHi := -128;
              Exit;
            end;
        else
          if (GDVars.mouseButtonSeen <> 0) and (ch = C_Keys.ENTER) then begin
            mouseColumn := GDVars.mouseY div 8;
            mouseRow := GDVars.mouseX div 8;
            if (mouseRow >= GDVars.keyRowLo) and (mouseRow <= GDVars.keyRowHi) then begin
              line := 1;
              while (line <= 25) and (GDVars.hotspotRows[line] <> 255) do begin
                if GDVars.hotspotRows[line] = mouseColumn then begin
                  UnhighlightLine(idx);
                  idx := line - 1 + GDVars.firstVisibleIndex;
                  HighlightLine(idx);
                end;
                Inc(line);
              end;
            end;
          end else begin
            sel := MenuCore.FindListMember(idx, list);
            MenuVertical := ch;
            GDVars.keyRowLo := 127;
            GDVars.keyRowHi := -128;
            Exit;
          end;
        end;
    until False;
  end;
end;

function YesNoMenu(query: Types.TStr40; qCol, mCol, hlCol: Byte): Char;
var
  ext: Boolean;
  ch: Char;
begin
  GDVars.horizontalChoice := 2;
  repeat
    ch := MenuCore.MenuHorizontal(query, 'Yes No', qCol, mCol, hlCol, False, False, ext);
  until ch in ['Y', 'N'];
  YesNoMenu := ch;
end;

procedure AllocStringList(n: Integer; var list: Types.PItemRec);
var
  p: Types.PItemRec;
  i: Integer;
begin
  GetMem(list, SizeOf(Types.TCharacterListNode));
  list^.next := nil;
  list^.inUse := 0;
  list^.name := '';
  p := list;
  for i := 2 to n do begin
    GetMem(p^.next, SizeOf(Types.TCharacterListNode));
    p := p^.next;
    p^.next := nil;
    p^.inUse := 0;
    p^.name := '';
  end;
end;

procedure FreeStringList(var list: Types.PItemRec);
var
  p: Types.PItemRec;
  q: Types.PItemRec;
begin
  p := list;
  while p <> nil do begin
    q := p;
    p := p^.next;
    FreeMem(q, SizeOf(Types.TCharacterListNode));
  end;
end;

begin
end.
