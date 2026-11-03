{
  FontAwesomeIcons - renders Font Awesome Free 7.3.1 icons into TBitmap.

  The fonts (converted OTF -> TTF, because LazFreeType supports TrueType
  outlines only) are compiled into the program as RCDATA resources, so no
  files have to be shipped with the executable. A font is parsed on the
  first use of its style, and bitmaps are created strictly on demand: there
  is no "all icons" buffer in memory.

  Resources and executable size:
    - Solid Free (~360 KB) is linked by this unit (define LAZFA_NO_SOLID
      in the package options to leave it out).
    - Regular Free (~70 KB) and Brands Free (~185 KB) are opt-in: add the
      unit FontAwesomeRegularRes and/or FontAwesomeBrandsRes to the uses
      clause of any unit of your project. Those units contain nothing but
      the $R directive, so the resource is linked only when the unit is
      part of the program.
    Calling a function of a style whose resource is not linked raises
    EFontAwesome with a hint which unit to add.

  Licenses: code - modified LGPL; icons - CC BY 4.0; fonts - SIL OFL 1.1
  (see fonts/LICENSE-FontAwesome.txt).
}
unit FontAwesomeIcons;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, LCLType, Graphics, GraphType, IntfGraphics, FPImage,
  LazUTF8, EasyLazFreeType, LazFreeTypeIntfDrawer;

{$I fa_solid_free.inc}
{$I fa_regular_free.inc}
{$I fa_brands_free.inc}

const
  FontAwesomeVersion = '7.3.1';

type
  EFontAwesome = class(Exception);

  TFontAwesomeStyle = (fasSolidFree, fasRegularFree, fasBrandsFree, fasCustom);

  { TFontAwesome }

  TFontAwesome = class
  private
    FFonts: array[TFontAwesomeStyle] of TFreeTypeFont;
    FFileName: String;
    FColor: TColor;
    procedure SetFileName(const AValue: String);
    function GetFont(AStyle: TFontAwesomeStyle): TFreeTypeFont;
  protected
    function ResolveColor(AColor: TColor): TFPColor; virtual;
    { Where to draw glyph AGlyph of AFont in an ASize x ASize bitmap:
      APixelSize = font size to use (<= ASize, smaller only if the outline
      sticks out of the design box), AX/AY = pen position (AY = baseline,
      y pointing down). Leaves AFont.SizeInPixels = APixelSize. }
    procedure ComputePlacement(AFont: TFreeTypeFont; AGlyph, ASize: Integer;
      out APixelSize, AX, AY: Single); virtual;
    function GetStyleFont(AStyle: TFontAwesomeStyle): TFreeTypeFont;
    function Render(AStyle: TFontAwesomeStyle; ACodepoint: Cardinal;
      ASize: Integer; AColor: TColor): TBitmap; virtual;
  public
    constructor Create;
    destructor Destroy; override;

    { Built-in icons (resources). Result: a new ASize x ASize 32-bit bitmap
      with alpha channel, owned by the caller.
      AColor = clNone (default) means "use the Color property". }
    function GetFAIconSolidFree(ACode: TFASolidFree; ASize: Integer;
      AColor: TColor = clNone): TBitmap;
    function GetFAIconRegularFree(ACode: TFARegularFree; ASize: Integer;
      AColor: TColor = clNone): TBitmap;
    function GetFAIconBrandsFree(ACode: TFABrandsFree; ASize: Integer;
      AColor: TColor = clNone): TBitmap;

    { "Custom" escape hatch: icon from the TTF file set in FileName
      (e.g. Font Awesome Pro converted to TTF).
      ACode = the icon character in UTF-8, or its Unicode code point. }
    function GetFAIcon(constref ACode: String; ASize: Integer;
      AColor: TColor = clNone): TBitmap; overload;
    function GetFAIcon(ACodepoint: Cardinal; ASize: Integer;
      AColor: TColor = clNone): TBitmap; overload;

    { True if the font of the given style contains a glyph for the code point }
    function HasIcon(AStyle: TFontAwesomeStyle; ACodepoint: Cardinal): Boolean;
    { True if the resource of a built-in style is linked into the program }
    class function StyleAvailable(AStyle: TFontAwesomeStyle): Boolean;
    { Frees parsed fonts and their glyph caches (reloaded on next use) }
    procedure ReleaseFonts;

    { Default icon color. clBtnText follows the system theme (light/dark).
      System colors are resolved when the bitmap is rendered - bitmaps
      created earlier do not change when the theme changes. }
    property Color: TColor read FColor write FColor default clBtnText;
    property FileName: String read FFileName write SetFileName;
  end;

{ Shared instance, created on first use and freed at program shutdown. }
function FontAwesome: TFontAwesome;

{ Original Font Awesome icon name (as on fontawesome.com), derived from RTTI:
  FAIconName(fas_folder_open) = 'folder-open'. For an alias constant the
  name of the icon it points to is returned (FAIconName(fas_cog) = 'gear').
  The Pascal identifier itself: GetEnumName(TypeInfo(TFASolidFree), Ord(X)). }
function FAIconName(ACode: TFASolidFree): String; overload;
function FAIconName(ACode: TFARegularFree): String; overload;
function FAIconName(ACode: TFABrandsFree): String; overload;

{ Reverse lookup by Font Awesome icon name ('folder-open'), e.g. for icon
  names stored in configuration files. Case-insensitive. Alias names are not
  found (alias constants are not part of RTTI). }
function FAIconByName(const AName: String; out ACode: TFASolidFree): Boolean; overload;
function FAIconByName(const AName: String; out ACode: TFARegularFree): Boolean; overload;
function FAIconByName(const AName: String; out ACode: TFABrandsFree): Boolean; overload;

implementation

uses
  TypInfo, LazFreeType, TTTypes;

{$IFNDEF LAZFA_NO_SOLID}
  {$R lazfa_solid_free.res}
{$ENDIF}

const
  RES_NAMES: array[fasSolidFree..fasBrandsFree] of String = (
    'LAZFA_SOLID_FREE', 'LAZFA_REGULAR_FREE', 'LAZFA_BRANDS_FREE');
  RES_UNITS: array[fasSolidFree..fasBrandsFree] of String = (
    'FontAwesomeIcons (compiled with LAZFA_NO_SOLID)',
    'FontAwesomeRegularRes', 'FontAwesomeBrandsRes');

resourcestring
  rsResMissing = 'Font Awesome resource "%s" is not linked into the program. ' +
    'Add unit %s to the uses clause.';
  rsNoFileName = 'TFontAwesome.FileName is empty - custom icons need a TTF file';
  rsFileNotFound = 'Font file not found: %s';
  rsNotTTF = 'File "%s" is not a TrueType font (OTF/CFF and WOFF are not supported by LazFreeType)';
  rsNoGlyph = 'Icon U+%.4X not found in font (%s)';
  rsBadSize = 'Invalid icon size: %d';

var
  GFontAwesome: TFontAwesome = nil;

function FontAwesome: TFontAwesome;
begin
  if GFontAwesome = nil then
    GFontAwesome := TFontAwesome.Create;
  Result := GFontAwesome;
end;

{ 'fas_folder_open' -> 'folder-open': drop the style prefix (everything up to
  and including the first '_') and turn the remaining '_' back into '-'. }
function IdentToFAName(const AIdent: String): String;
var
  I: Integer;
begin
  Result := Copy(AIdent, Pos('_', AIdent) + 1, MaxInt);
  for I := 1 to Length(Result) do
    if Result[I] = '_' then
      Result[I] := '-';
end;

{ 'folder-open' -> ordinal of '<prefix>folder_open', or -1 }
function FANameToOrd(ATypeInfo: PTypeInfo; const APrefix, AName: String): Integer;
var
  S: String;
  I: Integer;
begin
  S := LowerCase(Trim(AName));
  for I := 1 to Length(S) do
    if S[I] = '-' then
      S[I] := '_';
  Result := GetEnumValue(ATypeInfo, APrefix + S);
end;

function FAIconName(ACode: TFASolidFree): String;
begin
  Result := IdentToFAName(GetEnumName(TypeInfo(TFASolidFree), Ord(ACode)));
end;

function FAIconName(ACode: TFARegularFree): String;
begin
  Result := IdentToFAName(GetEnumName(TypeInfo(TFARegularFree), Ord(ACode)));
end;

function FAIconName(ACode: TFABrandsFree): String;
begin
  Result := IdentToFAName(GetEnumName(TypeInfo(TFABrandsFree), Ord(ACode)));
end;

function FAIconByName(const AName: String; out ACode: TFASolidFree): Boolean;
var
  V: Integer;
begin
  V := FANameToOrd(TypeInfo(TFASolidFree), 'fas_', AName);
  Result := V >= 0;
  if Result then ACode := TFASolidFree(V) else ACode := Low(TFASolidFree);
end;

function FAIconByName(const AName: String; out ACode: TFARegularFree): Boolean;
var
  V: Integer;
begin
  V := FANameToOrd(TypeInfo(TFARegularFree), 'far_', AName);
  Result := V >= 0;
  if Result then ACode := TFARegularFree(V) else ACode := Low(TFARegularFree);
end;

function FAIconByName(const AName: String; out ACode: TFABrandsFree): Boolean;
var
  V: Integer;
begin
  V := FANameToOrd(TypeInfo(TFABrandsFree), 'fab_', AName);
  Result := V >= 0;
  if Result then ACode := TFABrandsFree(V) else ACode := Low(TFABrandsFree);
end;

{ TFontAwesome }

constructor TFontAwesome.Create;
begin
  inherited Create;
  FColor := clBtnText;
end;

destructor TFontAwesome.Destroy;
begin
  ReleaseFonts;
  inherited Destroy;
end;

procedure TFontAwesome.ReleaseFonts;
var
  S: TFontAwesomeStyle;
begin
  for S := Low(S) to High(S) do
    FreeAndNil(FFonts[S]);
end;

procedure TFontAwesome.SetFileName(const AValue: String);
begin
  if FFileName = AValue then Exit;
  FFileName := AValue;
  FreeAndNil(FFonts[fasCustom]);    // the new file is loaded on first use
end;

class function TFontAwesome.StyleAvailable(AStyle: TFontAwesomeStyle): Boolean;
begin
  if AStyle = fasCustom then
    Result := True
  else
    Result := FindResource(HInstance, PChar(RES_NAMES[AStyle]), PChar(RT_RCDATA)) <> 0;
end;

function TFontAwesome.GetFont(AStyle: TFontAwesomeStyle): TFreeTypeFont;
var
  Stream: TStream;
  Sig: Cardinal;
begin
  Result := FFonts[AStyle];
  if Result <> nil then Exit;

  if AStyle = fasCustom then
  begin
    if FFileName = '' then
      raise EFontAwesome.Create(rsNoFileName);
    if not FileExists(FFileName) then
      raise EFontAwesome.CreateFmt(rsFileNotFound, [FFileName]);
    Stream := TMemoryStream.Create;
    try
      TMemoryStream(Stream).LoadFromFile(FFileName);
      // sfnt version tag: first 4 bytes, big-endian
      Sig := 0;
      if Stream.Size >= 4 then
        Sig := BEtoN(PCardinal(TMemoryStream(Stream).Memory)^);
      if (Sig <> $00010000) and (Sig <> $74727565 {'true'}) then
        raise EFontAwesome.CreateFmt(rsNotTTF, [FFileName]);
    except
      Stream.Free;
      raise;
    end;
  end
  else
  begin
    if not StyleAvailable(AStyle) then
      raise EFontAwesome.CreateFmt(rsResMissing, [RES_NAMES[AStyle], RES_UNITS[AStyle]]);
    // TResourceStream does not copy the data - it points into the program image
    Stream := TResourceStream.Create(HInstance, RES_NAMES[AStyle], PChar(RT_RCDATA));
  end;

  Result := TFreeTypeFont.Create;
  try
    Result.AccessFromStream(Stream, True);   // the font takes ownership of the stream
    // Hinted would round the baseline to whole pixels; at sizes that are not
    // a multiple of 8 (e.g. 20 px: ascent 17.5) that cuts half a row off
    // full-height icons. The converted fonts carry no hinting instructions,
    // so unhinted rendering loses nothing else.
    Result.Hinted := False;
    Result.ClearType := False;   // subpixel rendering gives colored fringes on transparent background
    Result.Quality := grqHighQuality;
  except
    Result.Free;
    raise;
  end;
  FFonts[AStyle] := Result;
end;

function TFontAwesome.HasIcon(AStyle: TFontAwesomeStyle; ACodepoint: Cardinal): Boolean;
begin
  Result := GetFont(AStyle).CharIndex[ACodepoint] > 0;
end;

function TFontAwesome.ResolveColor(AColor: TColor): TFPColor;
begin
  if AColor = clNone then
    AColor := FColor;
  if (AColor = clNone) or (AColor = clDefault) then
    AColor := clBtnText;
  Result := TColorToFPColor(ColorToRGB(AColor));
  Result.Alpha := alphaOpaque;
end;

procedure TFontAwesome.ComputePlacement(AFont: TFreeTypeFont; AGlyph,
  ASize: Integer; out APixelSize, AX, AY: Single);
  { Placement is computed from the font's design box and the exact glyph
    outline, in pixels with y pointing up (baseline = 0):
      design box: x 0..advance, y -descent..ascent
                  (Font Awesome: em 512 = ascent 448 + descent 64,
                  so at SizeInPixels = ASize the box is ASize tall)
      outline:    exact bbox from the glyph metrics (26.6 fixed point)
    The union of both is centered in the bitmap and scaled down only if
    it does not fit. Normal icons are therefore positioned by the design
    box (common baseline, consistent size), while icons whose outline
    sticks out of it (wider icons like address-card, overshooting ones like
    gear, many Brands logos) are shrunk just enough to stay whole.

    Pitfalls of LazFreeType (a FreeType 1 port) this code works around:
      - Outlines are scaled to a WHOLE number of pixels per em: asking for
        SizeInPixels = 31.5 renders the glyph at 32 px, 28.4 at 28 px, while
        Ascent/Descent still report values for the fractional size. So the
        font size is always an integer here, and the box is measured again
        at that size from the glyph metrics, which reflect the real outline.
      - ftaVerticalCenter centers the font's line height, which is padded
        with an invented 10 % line gap when the font has none
        (SmallLinePadding = False): every icon moved up by 5 % of its size.
      - TFreeTypeGlyph.Bounds is rounded outward to whole pixels (+1), so
        every full-width icon looked 1 px too wide. }
const
  EPS = 0.01;   // outlines touching the edge must not count as overflowing
var
  BoxL, BoxR, BoxB, BoxT: Single;
  Px: Integer;

  procedure Measure(APx: Integer);
  var
    M: TT_Glyph_Metrics;
  begin
    AFont.SizeInPixels := APx;
    FillChar(M{%H-}, SizeOf(M), 0);
    if TT_Get_Glyph_Metrics(AFont.Glyph[AGlyph].Data, M) <> TT_Err_Ok then
      raise EFontAwesome.CreateFmt(rsNoGlyph, [0, AFont.Family]);
    BoxL := Math.Min(0, M.bbox.xMin / 64);
    BoxR := Math.Max(M.advance / 64, M.bbox.xMax / 64);
    BoxB := Math.Min(-AFont.Descent, M.bbox.yMin / 64);
    BoxT := Math.Max(AFont.Ascent, M.bbox.yMax / 64);
  end;

  function Fits: Boolean;
  begin
    Result := (BoxR - BoxL <= ASize + EPS) and (BoxT - BoxB <= ASize + EPS);
  end;

begin
  Px := ASize;
  Measure(Px);
  if not Fits then
  begin
    // first guess from the proportion, then step down until it really fits
    Px := Math.Max(1, Trunc(ASize * Math.Min(ASize / (BoxR - BoxL), ASize / (BoxT - BoxB)) + EPS));
    Measure(Px);
    while (Px > 1) and not Fits do
    begin
      Dec(Px);
      Measure(Px);
    end;
  end;
  APixelSize := Px;
  AX := (ASize - (BoxR - BoxL)) / 2 - BoxL;
  AY := (ASize - (BoxT - BoxB)) / 2 + BoxT;   // baseline, y pointing down
end;

function TFontAwesome.GetStyleFont(AStyle: TFontAwesomeStyle): TFreeTypeFont;
begin
  Result := GetFont(AStyle);
end;

function TFontAwesome.Render(AStyle: TFontAwesomeStyle; ACodepoint: Cardinal;
  ASize: Integer; AColor: TColor): TBitmap;
var
  F: TFreeTypeFont;
  G: Integer;
  Img: TLazIntfImage;
  Drw: TIntfFreeTypeDrawer;
  PixelSize, X, Y: Single;
  C: TFPColor;
begin
  if (ASize < 1) or (ASize > 4096) then
    raise EFontAwesome.CreateFmt(rsBadSize, [ASize]);
  F := GetFont(AStyle);
  G := F.CharIndex[ACodepoint];
  if G <= 0 then
    raise EFontAwesome.CreateFmt(rsNoGlyph, [ACodepoint, F.Family]);
  C := ResolveColor(AColor);

  Result := nil;
  Img := TLazIntfImage.Create(0, 0, [riqfRGB, riqfAlpha]);
  try
    Img.SetSize(ASize, ASize);
    Drw := TIntfFreeTypeDrawer.Create(Img);
    try
      Drw.FillPixels(colTransparent);
      ComputePlacement(F, G, ASize, PixelSize, X, Y);
      Drw.DrawGlyph(G, F, X, Y, C);
    finally
      Drw.Free;
    end;
    Result := TBitmap.Create;
    Result.LoadFromIntfImage(Img);
  except
    Result.Free;
    Img.Free;
    raise;
  end;
  Img.Free;
end;

function TFontAwesome.GetFAIconSolidFree(ACode: TFASolidFree; ASize: Integer;
  AColor: TColor): TBitmap;
begin
  Result := Render(fasSolidFree, cFASolidFreeCodes[ACode], ASize, AColor);
end;

function TFontAwesome.GetFAIconRegularFree(ACode: TFARegularFree;
  ASize: Integer; AColor: TColor): TBitmap;
begin
  Result := Render(fasRegularFree, cFARegularFreeCodes[ACode], ASize, AColor);
end;

function TFontAwesome.GetFAIconBrandsFree(ACode: TFABrandsFree;
  ASize: Integer; AColor: TColor): TBitmap;
begin
  Result := Render(fasBrandsFree, cFABrandsFreeCodes[ACode], ASize, AColor);
end;

function TFontAwesome.GetFAIcon(constref ACode: String; ASize: Integer;
  AColor: TColor): TBitmap;
var
  Len: Integer;
  CP: Cardinal;
begin
  if ACode = '' then
    raise EFontAwesome.CreateFmt(rsNoGlyph, [0, FFileName]);
  CP := UTF8CodepointToUnicode(PChar(ACode), Len);
  Result := Render(fasCustom, CP, ASize, AColor);
end;

function TFontAwesome.GetFAIcon(ACodepoint: Cardinal; ASize: Integer;
  AColor: TColor): TBitmap;
begin
  Result := Render(fasCustom, ACodepoint, ASize, AColor);
end;

finalization
  FreeAndNil(GFontAwesome);
end.
