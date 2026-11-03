program fademo;
{$mode objfpc}{$H+}
uses
  Interfaces, Classes, SysUtils, TypInfo, Forms, Controls, Graphics, Buttons,
  ComCtrls, ImgList, Process, FontAwesomeIcons,
  FontAwesomeRegularRes, FontAwesomeBrandsRes;  // opt-in resources

type TSolidArr = array of TFASolidFree;

procedure Log(const S: String); begin WriteLn(S); Flush(Output); end;

function RSSKb: Integer;
var L: TStringList; I: Integer;
begin
  Result := -1; L := TStringList.Create;
  try
    L.LoadFromFile('/proc/self/status');
    for I := 0 to L.Count - 1 do
      if Pos('VmRSS:', L[I]) = 1 then
        Result := StrToInt(Trim(StringReplace(Copy(L[I], 7, 100), 'kB', '', [])));
  finally L.Free; end;
end;

procedure Pump(AMs: Integer);
var T: QWord;
begin
  T := GetTickCount64;
  while GetTickCount64 - T < QWord(AMs) do begin Application.ProcessMessages; Sleep(5); end;
end;

procedure Sheet(const AFile: String; AStyle: TFontAwesomeStyle; ACount, ASize: Integer);
var B, Ic: TBitmap; I, Cols, Cell: Integer;
begin
  Cols := 20; Cell := ASize + 4;
  B := TBitmap.Create;
  try
    B.SetSize(Cols * Cell, ((ACount + Cols - 1) div Cols) * Cell);
    B.Canvas.Brush.Color := clWhite; B.Canvas.FillRect(0, 0, B.Width, B.Height);
    for I := 0 to ACount - 1 do
    begin
      case AStyle of
        fasSolidFree:   Ic := FontAwesome.GetFAIconSolidFree(TFASolidFree(I), ASize);
        fasRegularFree: Ic := FontAwesome.GetFAIconRegularFree(TFARegularFree(I), ASize);
      else              Ic := FontAwesome.GetFAIconBrandsFree(TFABrandsFree(I), ASize);
      end;
      B.Canvas.Draw((I mod Cols) * Cell + 2, (I div Cols) * Cell + 2, Ic);
      Ic.Free;
    end;
    B.SaveToFile(AFile);
  finally B.Free; end;
end;

var
  Dir, O: String;
  S, S2: TFASolidFree; R, R2: TFARegularFree; Br, Br2: TFABrandsFree;
  Missing, I: Integer;
  T0: QWord;
  Bmp: TBitmap;
  IL: TImageList;
  Form: TForm;
  BB: TBitBtn;
  TB: TToolBar;
begin
  Dir := IncludeTrailingPathDelimiter(ParamStr(1));
  Application.Initialize;
  Log(Format('RSS at start: %d kB', [RSSKb]));

  // 1. Does every enum value have a glyph in the (converted) font?
  Missing := 0;
  for S := Low(S) to High(S) do
    if not FontAwesome.HasIcon(fasSolidFree, cFASolidFreeCodes[S]) then begin Inc(Missing); Log('missing ' + FAIconName(S)); end;
  for R := Low(R) to High(R) do
    if not FontAwesome.HasIcon(fasRegularFree, cFARegularFreeCodes[R]) then begin Inc(Missing); Log('missing ' + FAIconName(R)); end;
  for Br := Low(Br) to High(Br) do
    if not FontAwesome.HasIcon(fasBrandsFree, cFABrandsFreeCodes[Br]) then begin Inc(Missing); Log('missing ' + FAIconName(Br)); end;
  Log(Format('enum check: solid=%d regular=%d brands=%d, missing glyphs=%d',
    [Ord(High(TFASolidFree)) + 1, Ord(High(TFARegularFree)) + 1, Ord(High(TFABrandsFree)) + 1, Missing]));
  Log(Format('RSS after parsing 3 fonts: %d kB', [RSSKb]));

  // 2. Rendering time
  T0 := GetTickCount64;
  for I := 0 to 99 do
  begin
    Bmp := FontAwesome.GetFAIconSolidFree(fas_gear, 32);
    Bmp.Free;
  end;
  Log(Format('100x GetFAIconSolidFree(fas_gear, 32): %d ms', [GetTickCount64 - T0]));
  Bmp := FontAwesome.GetFAIconSolidFree(fas_cog, 24);   // alias
  Log(Format('alias fas_cog -> %s, bitmap %dx%d', [FAIconName(fas_cog), Bmp.Width, Bmp.Height]));
  Log('FAIconName(fas_folder_open) = ' + FAIconName(fas_folder_open) +
      ', FAIconName(fab_42_group) = ' + FAIconName(fab_42_group) +
      ', FAIconName(fas_file) = ' + FAIconName(fas_file));
  // round trip: every icon name -> enum -> same name
  Missing := 0;
  for S := Low(S) to High(S) do
    if not FAIconByName(FAIconName(S), S2) or (S2 <> S) then Inc(Missing);
  for R := Low(R) to High(R) do
    if not FAIconByName(FAIconName(R), R2) or (R2 <> R) then Inc(Missing);
  for Br := Low(Br) to High(Br) do
    if not FAIconByName(FAIconName(Br), Br2) or (Br2 <> Br) then Inc(Missing);
  Log(Format('name round trip errors: %d; FAIconByName(''Folder-Open'') = %s; unknown -> %s',
    [Missing, BoolToStr(FAIconByName('Folder-Open', S2) and (S2 = fas_folder_open), True),
     BoolToStr(FAIconByName('no-such-icon', S2), True)]));
  Bmp.Free;

  // 2b. Color: clNone (default argument) -> TFontAwesome.Color
  FontAwesome.Color := clBlue;
  Bmp := FontAwesome.GetFAIconSolidFree(fas_square, 16);
  Log(Format('Color=clBlue, default arg -> center pixel %s', [ColorToString(Bmp.Canvas.Pixels[8, 8])]));
  Bmp.Free;
  Bmp := FontAwesome.GetFAIconSolidFree(fas_square, 16, clRed);
  Log(Format('explicit clRed -> center pixel %s', [ColorToString(Bmp.Canvas.Pixels[8, 8])]));
  Bmp.Free;
  FontAwesome.Color := clBtnText;

  // 3. Control sheets
  Sheet(Dir + 'solid.bmp', fasSolidFree, 200, 32);
  Sheet(Dir + 'regular.bmp', fasRegularFree, 169, 32);
  Sheet(Dir + 'brands.bmp', fasBrandsFree, 200, 32);

  // 4. Custom escape hatch: FileName (here: the Solid TTF posing as a "Pro file")
  FontAwesome.FileName := ParamStr(2);
  Bmp := FontAwesome.GetFAIcon(UTF8Encode(WideChar($F015)), 32, clNavy);
  Log(Format('custom GetFAIcon(house): %dx%d', [Bmp.Width, Bmp.Height]));
  Bmp.Free;
  try
    FontAwesome.GetFAIcon($E999, 16).Free;
  except
    on E: Exception do Log('custom missing: ' + E.Message);
  end;
  FontAwesome.FileName := ParamStr(3);  // OTF -> error
  try
    FontAwesome.GetFAIcon($F015, 16).Free;
  except
    on E: Exception do Log('custom OTF: ' + E.Message);
  end;

  // 5. Typical use: own TImageList with selected icons
  IL := TImageList.Create(nil);
  IL.Width := 24; IL.Height := 24;
  // note: "set of TFASolidFree" is impossible (FPC sets have max 256 elements),
  // hence an array
  for S in TSolidArr.Create(fas_house, fas_gear, fas_trash, fas_floppy_disk, fas_magnifying_glass) do
  begin
    Bmp := FontAwesome.GetFAIconSolidFree(S, 24, $00404040);
    IL.Add(Bmp, nil);
    Bmp.Free;
  end;
  Bmp := FontAwesome.GetFAIconBrandsFree(fab_github, 24); IL.Add(Bmp, nil); Bmp.Free;
  Bmp := FontAwesome.GetFAIconRegularFree(far_heart, 24, clRed); IL.Add(Bmp, nil); Bmp.Free;

  Form := TForm.CreateNew(nil);
  Form.SetBounds(0, 0, 420, 140);
  TB := TToolBar.Create(Form); TB.Parent := Form; TB.Images := IL; TB.ButtonHeight := 32; TB.ButtonWidth := 32;
  for I := 0 to IL.Count - 1 do
    with TToolButton.Create(Form) do begin Parent := TB; ImageIndex := I; end;
  BB := TBitBtn.Create(Form); BB.Parent := Form; BB.SetBounds(10, 60, 150, 40);
  BB.Caption := 'Zapisz'; BB.Images := IL; BB.ImageIndex := 3;
  Form.Show;
  Pump(500);
  RunCommand('import', ['-window', 'root', Dir + 'demo.png'], O);
  Log(Format('RSS at end: %d kB', [RSSKb]));
  Form.Free;
  IL.Free;
  Log('DONE');
end.
