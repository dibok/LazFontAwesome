{
  cliptest - regression test for icon placement.

  For every icon of every built-in style and several sizes, the glyph is
  drawn at exactly the position TFontAwesome.ComputePlacement returns, but
  into a bitmap with a margin around the icon square. Any visible ink in the
  margin means the icon would be clipped in the real ASize x ASize bitmap.

  Usage: cliptest   (exit code 1 when any icon is clipped)
}
program cliptest;

{$mode objfpc}{$H+}

uses
  Interfaces, SysUtils, Forms, Graphics, GraphType, IntfGraphics, FPImage,
  EasyLazFreeType, LazFreeTypeIntfDrawer, TypInfo,
  FontAwesomeIcons, FontAwesomeRegularRes, FontAwesomeBrandsRes;

const
  MARGIN = 4;
  SIZES: array[0..6] of Integer = (12, 16, 20, 24, 32, 48, 64);
  INK_THRESHOLD = $1000;   // ~6 % coverage: ignore the faintest antialiasing

type
  { exposes the protected placement logic }
  TFontAwesomeProbe = class(TFontAwesome)
  public
    function ClippedPixels(AStyle: TFontAwesomeStyle; ACodepoint: Cardinal;
      ASize: Integer; out AScale: Single; out ATopRow, ABottomRow: Integer): Integer;
  end;

var
  GLeft, GRight: Integer;  // debug: ink column range of the last check


function TFontAwesomeProbe.ClippedPixels(AStyle: TFontAwesomeStyle;
  ACodepoint: Cardinal; ASize: Integer; out AScale: Single;
  out ATopRow, ABottomRow: Integer): Integer;
var
  F: TFreeTypeFont;
  G, X, Y, N: Integer;
  PixelSize, PX, PY: Single;
  Img: TLazIntfImage;
  Drw: TIntfFreeTypeDrawer;
  Inside: Boolean;
begin
  F := GetStyleFont(AStyle);
  G := F.CharIndex[ACodepoint];
  ComputePlacement(F, G, ASize, PixelSize, PX, PY);
  AScale := PixelSize / ASize;
  N := ASize + 2 * MARGIN;
  Img := TLazIntfImage.Create(0, 0, [riqfRGB, riqfAlpha]);
  Drw := TIntfFreeTypeDrawer.Create(Img);
  try
    Img.SetSize(N, N);
    Drw.FillPixels(colTransparent);
    Drw.DrawGlyph(G, F, PX + MARGIN, PY + MARGIN, colBlack);
    Result := 0;
    ATopRow := MaxInt;
    ABottomRow := -MaxInt;
    GLeft := MaxInt; GRight := -MaxInt;
    for Y := 0 to N - 1 do
      for X := 0 to N - 1 do
        if Img.Colors[X, Y].Alpha > INK_THRESHOLD then
        begin
          if Y - MARGIN < ATopRow then ATopRow := Y - MARGIN;
          if Y - MARGIN > ABottomRow then ABottomRow := Y - MARGIN;
          if X - MARGIN < GLeft then GLeft := X - MARGIN;
          if X - MARGIN > GRight then GRight := X - MARGIN;
          Inside := (X >= MARGIN) and (X < MARGIN + ASize) and
                    (Y >= MARGIN) and (Y < MARGIN + ASize);
          if not Inside then
            Inc(Result);
        end;
  finally
    Drw.Free;
    Img.Free;
  end;
end;

var
  P: TFontAwesomeProbe;
  Clipped, Shrunk, Total, Px, Top, Bottom, Sz, I: Integer;
  Scale, MinScale: Single;
  MinName: String;

procedure Check(AStyle: TFontAwesomeStyle; ACode: Cardinal; const AName: String);
begin
  Px := P.ClippedPixels(AStyle, ACode, Sz, Scale, Top, Bottom);
  Inc(Total);
  if Px > 0 then
  begin
    Inc(Clipped);
    if Clipped <= 20 then
      WriteLn(Format('  CLIPPED %-30s %3dpx: %d px outside, rows %d..%d cols %d..%d scale %.3f',
        [AName, Sz, Px, Top, Bottom, GLeft, GRight, Scale]));
  end;
  if Scale < 0.999 then
  begin
    Inc(Shrunk);
    if Scale < MinScale then
    begin
      MinScale := Scale;
      MinName := AName;
    end;
  end;
end;

var
  S: TFASolidFree;
  R: TFARegularFree;
  B: TFABrandsFree;
begin
  Application.Initialize;
  P := TFontAwesomeProbe.Create;
  try
    for I := Low(SIZES) to High(SIZES) do
    begin
      Sz := SIZES[I];
      Clipped := 0; Shrunk := 0; Total := 0;
      MinScale := 1; MinName := '-';
      for S := Low(S) to High(S) do
        Check(fasSolidFree, cFASolidFreeCodes[S], 'fas-' + FAIconName(S));
      for R := Low(R) to High(R) do
        Check(fasRegularFree, cFARegularFreeCodes[R], 'far-' + FAIconName(R));
      for B := Low(B) to High(B) do
        Check(fasBrandsFree, cFABrandsFreeCodes[B], 'fab-' + FAIconName(B));
      WriteLn(Format('%3d px: %d icons, clipped %d, shrunk to fit %d (smallest scale %.3f: %s)',
        [Sz, Total, Clipped, Shrunk, MinScale, MinName]));
      if Clipped > 0 then
        ExitCode := 1;
    end;
  finally
    P.Free;
  end;
end.
