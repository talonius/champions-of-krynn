{ ECL opcode-name lookup and debug trace output. }
{$O+,F+}
unit Debug;

interface

uses Types, TextRend, Crt, GDConsts, GDVars;

{ While debug tracing is on, shows the three values on the top line and the message at the bottom, waits for a key, then
  clears the top line. Does nothing otherwise.
  @param(messageText Message shown with a pause.)
  @param(value1 First value shown.)
  @param(value2 Second value shown.)
  @param(value3 Third value shown.) }
procedure PrintDebug(messageText: Types.TStr40; value1, value2, value3: Byte);

{ Empty; calling it loads this overlay. }
procedure PrimeDebug;

{ Returns the mnemonic of the current ECL opcode, GDVars.eclOpcode. An opcode with no name, $1F among them, gives
  "BULLSHIT" followed by the parameter's value.
  @param(opcode Used only in the text for an unnamed opcode.)
  @returns(The opcode's mnemonic.) }
function OpcodeName(opcode: Byte): String;

implementation

procedure PrimeDebug;
begin
end;

function OpcodeName(opcode: Byte): String;
var
  opcodeText: String;
begin
  case GDVars.eclOpcode of
    $00: OpcodeName := 'EXIT';
    $01: OpcodeName := 'GOTO';
    $02: OpcodeName := 'GOSUB';
    $03: OpcodeName := 'COMPARE';
    $04: OpcodeName := 'ADD';
    $05: OpcodeName := 'SUBTRAT';
    $06: OpcodeName := 'DIVIDE';
    $07: OpcodeName := 'MULTIPLY';
    $08: OpcodeName := 'RANDOM';
    $09: OpcodeName := 'SAVE';
    $0A: OpcodeName := 'LOAD CHARACTER';
    $0B: OpcodeName := 'LOAD MONSTER';
    $0C: OpcodeName := 'SETUP MONSTER';
    $0D: OpcodeName := 'APPROACH';
    $0E: OpcodeName := 'PICTURE';
    $0F: OpcodeName := 'INPUT NUMBER';
    $10: OpcodeName := 'INPUT STRING';
    $11: OpcodeName := 'PRINT';
    $12: OpcodeName := 'PRINTCLEAR';
    $13: OpcodeName := 'RETURN';
    $14: OpcodeName := 'COMPARE AND';
    $15: OpcodeName := 'VERTICAL MENU';
    $16: OpcodeName := 'IF = ';
    $17: OpcodeName := 'IF <>';
    $18: OpcodeName := 'IF <';
    $19: OpcodeName := 'IF >';
    $1A: OpcodeName := 'IF <=';
    $1B: OpcodeName := 'IF >=';
    $1C: OpcodeName := 'CLEARMONSTERS';
    $1D: OpcodeName := 'PARTYSTRENGTH';
    $1E: OpcodeName := 'CHECKPARTY';
    $20: OpcodeName := 'NEWECL';
    $21: OpcodeName := 'LOAD FILES';
    $37: OpcodeName := 'LOAD PIECES';
    $22: OpcodeName := 'PARTY SURPRISE';
    $23: OpcodeName := 'SURPRISE';
    $24: OpcodeName := 'COMBAT';
    $25: OpcodeName := 'ON GOTO';
    $26: OpcodeName := 'ON GOSUB';
    $27: OpcodeName := 'TREASURE';
    $28: OpcodeName := 'ROB';
    $29: OpcodeName := 'ENCOUNTER MENU';
    $2A: OpcodeName := 'GETTABLE';
    $2B: OpcodeName := 'HORIZONTAL MENU';
    $2C: OpcodeName := 'PARLAY';
    $2D: OpcodeName := 'CALL';
    $2E: OpcodeName := 'DAMAGE';
    $2F: OpcodeName := 'AND';
    $30: OpcodeName := 'OR';
    $31: OpcodeName := 'SPRITE OFF';
    $32: OpcodeName := 'FIND ITEM';
    $33: OpcodeName := 'PRINT RETURN';
    $34: OpcodeName := 'ECL CLOCK';
    $35: OpcodeName := 'SAVE TABLE';
    $36: OpcodeName := 'ADD NPC';
    $38: OpcodeName := 'PROGRAM';
    $39: OpcodeName := 'WHO';
    $3A: OpcodeName := 'DELAY';
    $3B: OpcodeName := 'SPELL';
    $3C: OpcodeName := 'PROTECTION';
    $3D: OpcodeName := 'CLEAR BOX';
    $3E: OpcodeName := 'DUMP';
    $3F: OpcodeName := 'FIND SPECIAL';
    $40: OpcodeName := 'DESTROY ITEMS';
    $41: OpcodeName := 'ADD EP';
  else begin
    Str(opcode, opcodeText);
    OpcodeName := 'BULLSHIT ' + opcodeText;
  end;
  end;
end;

procedure PrintDebug(messageText: Types.TStr40; value1, value2, value3: Byte);
var
  valueText1: String;
  valueText2: String;
  valueText3: String;
  { Unused in this version; see the other implementations of this routine. }
  lineIndex: Byte;
begin
  if GDVars.debugActive <> 0 then begin
    Str(value1, valueText1);
    Str(value2, valueText2);
    Str(value3, valueText3);
    TextRend.ClearRect(0, 0, 39, 0);
    TextRend.displayString(0, 0, Yellow, Black, valueText1 + ' , ' + valueText2 + ' , ' + valueText3);
    TextRend.displayAndPause(Yellow, Black, messageText);
    TextRend.ClearRect(0, 0, 39, 0);
  end;
end;

begin
end.
