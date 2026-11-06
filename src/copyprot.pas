{ Documentation lookup copy protection. Random(1) leaves the tavern-tale branch unreachable.

  GDConsts.answerLetterTable holds the signed letter deltas; the records of GDConsts.codeEntries carry running letter
  offsets and the journal/tavern prompt numbers. protMark is a tamper watermark cleared and then set one byte per stage;
  FixMain resets the game if any byte is still zero. }
{$O+,F+}
unit CopyProt;

interface

{ Runs the documentation check: asks for word N of journal entry M on page P of the journal, giving three tries to type
  it. The answer is decoded from GDConsts.answerLetterTable through the entry's record in GDConsts.codeEntries. Each
  stage sets one byte of the protMark watermark, which is cleared on entry. Note: the source group is Random(1), always
  0, so the tavern-tale questions are never asked.
  @returns(1 when the last answer typed was right, else 0.) }
function CopyProtection: Byte;

{ Calls the trace overlay's priming entry, so the overlay manager loads it. }
procedure PrimeCopyProt;

implementation

uses Border, TextRend, CharHlp, Debug, Crt, GDConsts, GDVars, Types;

procedure PrimeCopyProt;
begin
  Debug.PrimeDebug;
end;

function CopyProtection: Byte;

  { Each stored letter is a signed delta from $46 plus the word length. }
  function Decode(codeIndex: Word): String;
  var
    letterCount: Byte;
    letterIndex: Byte;
    firstLetterOffset: Byte;
    decodedChar: Byte;
    answerText: String;
  begin
    answerText := '';
    letterCount := GDConsts.codeEntries[codeIndex].letters;
    firstLetterOffset := GDConsts.codeEntries[codeIndex].firstLetter;
    for letterIndex := 1 to letterCount do begin
      decodedChar := GDConsts.answerLetterTable[firstLetterOffset + letterIndex] + 70 + letterCount;
      answerText := answerText + Chr(decodedChar);
    end;
    Decode := answerText;
  end;

var
  { Unused in this version; see the other implementations of this routine. }
  charIndex: Byte;
  codeIndex: Byte;
  attempt: Byte;
  { Unused in this version; see the other implementations of this routine. }
  passed: Byte;
  correctAnswer: String;
  wordNumber: Byte;
  entryNumber: Byte;
  pageNumber: Byte;
  enteredAnswer: String;
  sourceGroup: Byte;
begin
  FillChar(GDVars.protMark, SizeOf(GDVars.protMark), 0);
  Border.DrawWindowFrame(True);
  attempt := 0;
  repeat
    Inc(attempt);
    correctAnswer := '';
    { Note: Random(1) is always 0, so the tavern arm below is never taken. }
    sourceGroup := Random(1);
    GDVars.protMark[1] := 1;
    TextRend.displayString(3, 2, LightGreen, Black, ' what is word # ');
    if sourceGroup = 0 then begin
      codeIndex := Random(25) + 1;
      wordNumber := GDConsts.codeEntries[codeIndex].wordNo;
      entryNumber := GDConsts.codeEntries[codeIndex].entryNo;
      pageNumber := GDConsts.codeEntries[codeIndex].pageNo;
      correctAnswer := Decode(codeIndex);
      TextRend.displayString(19, 2, LightGreen, Black, CharHlp.Uint8Str(wordNumber) + '    ');
      TextRend.displayString(3, 4, LightGreen, Black,
                             ' of journal entry # ' + CharHlp.Uint8Str(entryNumber) + '     ');
      TextRend.displayString(3, 6, LightGreen, Black,
                             ' (journal, page ' + CharHlp.Uint8Str(pageNumber) + ')?      ');
    end else begin
      codeIndex := Random(25) + 26;
      wordNumber := GDConsts.codeEntries[codeIndex].wordNo;
      entryNumber := GDConsts.codeEntries[codeIndex].entryNo;
      pageNumber := GDConsts.codeEntries[codeIndex].pageNo;
      correctAnswer := Decode(codeIndex);
      TextRend.displayString(19, 2, LightGreen, Black, CharHlp.Uint8Str(wordNumber) + '     ');
      TextRend.displayString(3, 4, LightGreen, Black,
                             ' of tavern tale # ' + CharHlp.Uint8Str(entryNumber) + '     ');
      TextRend.displayString(3, 6, LightGreen, Black,
                             ' (journal, page ' + CharHlp.Uint8Str(pageNumber) + ')?      ');
    end;
    GDVars.protMark[2] := 1;
    enteredAnswer := TextRend.readString('Enter ', Yellow, Black, 20);
  until (attempt = 3) or (enteredAnswer = correctAnswer);
  GDVars.protMark[3] := 1;
  if enteredAnswer = correctAnswer then
    CopyProtection := 1
  else
    CopyProtection := 0;
  GDVars.protMark[4] := 1;
end;

begin
end.
