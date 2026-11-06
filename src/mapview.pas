{ Redraws the 3D map view, choosing its sky color and (on CGA) its band and floor colors, or otherwise redisplays the
  current picture. }
{$O+,F+}
unit MapView;
interface

{ Redraws the map view. Nothing is drawn while partyDefeated is set. When view3dFlag or areaView is set, the sky color
  comes from the zone's sky selector (skyIndexHighEvent when the event at the party's cell is above $7F, else
  skyIndexNormal); on CGA the band and floor colors are recomputed from the ECL selectors after an ECL write to them,
  and other modes use a dark gray floor; an area lock turns the automap off, and View3D draws the view. Otherwise the
  current picture is redisplayed if a redraw was requested; while picture 9 is loaded the request is dropped. }
procedure DisplayMapView;

{ Calls the priming entries of MapTiles, Portrait and the trace overlay (not View3D), so the overlay manager loads those
  overlays. }
procedure PrimeMapView;

implementation

uses Types, View3D, Portrait, MapTiles, Debug, Crt, GDConsts, GDVars;

procedure PrimeMapView;
begin
  MapTiles.PrimeMapTiles;
  Debug.PrimeDebug;
  Portrait.PrimePortrait;
end;

procedure DisplayMapView;
var
  { Unused in this version; see the other implementations of this routine. }
  wildX: Integer;
  { Unused in this version; see the other implementations of this routine. }
  wildY: Integer;

  { CGA color of the upper horizon band for an ECL horizon selector. }
  function HorizonUpperColorOf(w: Byte): Byte;
  begin
    case w of
      8: HorizonUpperColorOf := Black;
      65: HorizonUpperColorOf := Black;
      232: HorizonUpperColorOf := White;
    else
      HorizonUpperColorOf := White;
    end;
  end;

  { CGA color of the lower horizon band for an ECL horizon selector. }
  function HorizonLowerColorOf(w: Byte): Byte;
  begin
    case w of
      8: HorizonLowerColorOf := DarkGray;
      65: HorizonLowerColorOf := LightGray;
      232: HorizonLowerColorOf := LightGray;
    else
      HorizonLowerColorOf := LightGray;
    end;
  end;

  { CGA floor color for an ECL floor selector. }
  function FloorColorOf(w: Byte): Byte;
  begin
    case w of
      11: FloorColorOf := DarkGray;
      9: FloorColorOf := Brown;
      219: FloorColorOf := Brown;
      6: FloorColorOf := Blue;
    else
      FloorColorOf := Brown;
    end;
  end;

begin
  if GDVars.picArcId = 9 then GDVars.pictureRedrawRequested := 0;
  if GDVars.partyDefeated then Exit;
  if (GDVars.zone0^.view3dFlag <> 0) or (GDVars.zone0^.areaView <> 0) then begin
    GDVars.mapState.event := View3D.GetMapEvent(GDVars.mapState.x, GDVars.mapState.y);
    if GDVars.mapState.event > $7F then
      GDVars.viewColSky := GDConsts.skyMapArr[GDVars.zone0^.skyIndexHighEvent]
    else
      GDVars.viewColSky := GDConsts.skyMapArr[GDVars.zone0^.skyIndexNormal];
    if GDVars.displayMode = Types.Cga then begin
      if GDVars.viewColorsChanged then begin
        GDVars.viewHorizonUpper := HorizonUpperColorOf(GDVars.horizonColorSel);
        GDVars.viewHorizonLower := HorizonLowerColorOf(GDVars.horizonColorSel);
        GDVars.viewColFloor := FloorColorOf(GDVars.floorColorSel);
        View3D.SetView3DColors(GDVars.viewColSky, GDVars.viewHorizonUpper, GDVars.viewHorizonLower,
                               GDVars.viewColFloor);
      end;
    end else
      GDVars.viewColFloor := DarkGray;
    if GDVars.zone0^.areaLock <> 0 then GDVars.automapOn := False;
    View3D.Display3DMapView(GDVars.mapState.x, GDVars.mapState.y, GDVars.mapState.facing);
  end else begin
    if GDVars.pictureRedrawRequested <> 0 then Portrait.DisplayBigPic;
  end;
  GDVars.pictureRedrawRequested := 0;
end;

begin
end.
