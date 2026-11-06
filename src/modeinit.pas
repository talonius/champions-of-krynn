{ Sets cmpStr, the value the second command-line parameter must match to unlock the developer options, to the item-name
  part 'Helm' (nameParts[41]). Given it, FixMain skips the copy-protection checks, Explore opens the area map
  everywhere, CharGen's J key toggles free training, and CbtActs ends combat in victory. }
{$F+}
unit ModeInit;
interface
implementation
uses GDConsts, GDVars;
begin
  GDVars.cmpStr := GDConsts.nameParts[41];
end.
