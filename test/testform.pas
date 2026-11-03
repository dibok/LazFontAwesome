unit TestForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  ComCtrls, Buttons, ColorBox, FontAwesomeIcons;

type

  { TForm1 }

  TForm1 = class(TForm)
    BitBtn1: TBitBtn;
    BitBtn4: TBitBtn;
    BitBtn3: TBitBtn;
    BitBtn2: TBitBtn;
    cbDrawBounds: TCheckBox;
    ColorBox1: TColorBox;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    GroupBox3: TGroupBox;
    ImageList1: TImageList;
    ListView1: TListView;
    PaintBox1: TPaintBox;
    PaintBox2: TPaintBox;
    Panel1: TPanel;
    SpeedButton1: TSpeedButton;
    SpeedButton2: TSpeedButton;
    SpeedButton3: TSpeedButton;
    SpeedButton4: TSpeedButton;
    Splitter1: TSplitter;
    procedure cbDrawBoundsChange(Sender: TObject);
    procedure ColorBox1Change(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure ListView1SelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure PaintBox1Paint(Sender: TObject);
    procedure PaintBox2Paint(Sender: TObject);
  private
    procedure PrepareImageListAndControls;
    procedure ReloadIcons;
    procedure LoadSelectedIcon;
  public
    procedure AfterConstruction; override;
  end;

var
  Form1: TForm1;

implementation

uses ImgList;

{$R *.lfm}

{ TForm1 }

procedure TForm1.PaintBox1Paint(Sender: TObject);
var
  ico: TBitmap;
  x1, y1, x2, y2: Integer;
begin
  PaintBox1.Canvas.Pen.Style := psSolid;
  PaintBox1.Canvas.Pen.Color := clGrayText;
  PaintBox1.Canvas.Brush.Style := bsSolid;
  PaintBox1.Canvas.Rectangle(1, 1, PaintBox1.Width, PaintBox1.Height);

  if (ListView1.Selected=nil) then Exit;

  ico := FontAwesome.GetFAIconSolidFree(TFASolidFree(PtrInt(ListView1.Selected.Data)), PaintBox1.Height-10);
  try
    PaintBox1.Canvas.Draw((PaintBox1.Width - ico.Width) div 2, (PaintBox1.Height - ico.Height) div 2, ico);

    if cbDrawBounds.Checked then
    begin
      x1 := (PaintBox1.Width - ico.Width) div 2;
      y1 := (PaintBox1.Height - ico.Height) div 2;
      x2 := x1 + ico.Width;
      y2 := y1 + ico.Height;
      PaintBox1.Canvas.Pen.Style := psDash;
      PaintBox1.Canvas.Pen.Color := clRed;
      PaintBox1.Canvas.Brush.Style := bsClear;
      PaintBox1.Canvas.Rectangle(x1, y1, x2, y2);
    end;
  finally
    ico.Free;
  end;
end;

procedure TForm1.PaintBox2Paint(Sender: TObject);

  procedure _Draw(aSize, aX: Integer);
  var
    ico: TBitmap;
    x1, y1, x2, y2: Integer;
  begin
    ico := FontAwesome.GetFAIconSolidFree(TFASolidFree(PtrInt(ListView1.Selected.Data)), aSize);
    try
      x1 := aX;
      y1 := (PaintBox2.Height - ico.Height) div 2;
      PaintBox2.Canvas.Draw(x1, y1, ico);

      if cbDrawBounds.Checked then
      begin
        x1 := aX;
        y1 := (PaintBox2.Height - ico.Height) div 2;
        x2 := x1 + ico.Width;
        y2 := y1 + ico.Height;
        PaintBox2.Canvas.Pen.Style := psDash;
        PaintBox2.Canvas.Pen.Color := clRed;
        PaintBox2.Canvas.Brush.Style := bsClear;
        PaintBox2.Canvas.Rectangle(x1, y1, x2, y2);
      end;
    finally
      ico.Free;
    end;
  end;

begin
  PaintBox2.Canvas.Pen.Style := psSolid;
  PaintBox2.Canvas.Pen.Color := clGrayText;
  PaintBox2.Canvas.Brush.Style := bsSolid;
  PaintBox2.Canvas.Rectangle(1, 1, PaintBox2.Width, PaintBox2.Height);

  if (ListView1.Selected=nil) then Exit;

  _Draw(16, 10);
  _Draw(24, 36);
  _Draw(32, 66);
  _Draw(48, 114);
end;

procedure TForm1.PrepareImageListAndControls;
begin
  ImageList1.Scaled := True;
  ImageList1.RegisterResolutions([16, 24, 32, 48]);
  BitBtn1.ImageWidth := 16;
  BitBtn2.ImageWidth := 24;
  BitBtn3.ImageWidth := 32;
  BitBtn4.ImageWidth := 48;
end;

{ Adds one icon to every registered resolution of the list,
  each rendered from the font at its exact size. Returns the image index. }
function AddFAIcon(AList: TImageList; AIcon: TFASolidFree;
  AColor: TColor = clNone): Integer;
var
  R: TCustomImageListResolution;
  Bmps: array of TCustomBitmap;
  I: Integer;
begin
  SetLength(Bmps, AList.ResolutionCount);
  I := 0;
  for R in AList.Resolutions do          // ascending by width, as required
  begin
    Bmps[I] := FontAwesome.GetFAIconSolidFree(AIcon, R.Width, AColor);
    Inc(I);
  end;
  try
    Result := AList.AddMultipleResolutions(Bmps);
  finally
    for I := 0 to High(Bmps) do
      Bmps[I].Free;
  end;
end;

procedure ClearImages(AList: TCustomImageList);
var
  I: Integer;
begin
  AList.BeginUpdate;            // one change notification instead of Count
  try
    for I := AList.Count - 1 downto 0 do
      AList.Delete(I);
  finally
    AList.EndUpdate;
  end;
end;

procedure TForm1.ReloadIcons;
var
  t: TFASolidFree;
  it: TListItem;
begin
  ListView1.BeginUpdate;
  try
    ListView1.Clear;
    ClearImages(ImageList1);
    for t in TFASolidFree do
    begin
      it := ListView1.Items.Add;
      it.Data := Pointer(PtrInt(t));
      it.Caption := FAIconName(t);
      it.ImageIndex := AddFAIcon(ImageList1, t);
    end;
  finally
    ListView1.EndUpdate;
  end;
end;

procedure TForm1.ListView1SelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
begin
  if Selected then
    LoadSelectedIcon;
end;

procedure TForm1.cbDrawBoundsChange(Sender: TObject);
begin
  PaintBox1.Repaint;
  PaintBox2.Repaint;
end;

procedure TForm1.ColorBox1Change(Sender: TObject);
var i_last_index: Integer;
begin
  i_last_index := ListView1.ItemIndex;
  FontAwesome.Color := ColorBox1.Selected;
  BitBtn1.ImageIndex := -1;
  BitBtn2.ImageIndex := -1;
  BitBtn3.ImageIndex := -1;
  BitBtn4.ImageIndex := -1;
  ReloadIcons;
  ListView1.ItemIndex := i_last_index;
  LoadSelectedIcon;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  ListView1.ItemIndex := 11;
end;

procedure TForm1.LoadSelectedIcon;
var
  ico: TBitmap;
begin
  if ListView1.Selected=nil then Exit;

  PaintBox1.Repaint;
  BitBtn1.ImageIndex := ListView1.Selected.Index;
  BitBtn2.ImageIndex := ListView1.Selected.Index;
  BitBtn3.ImageIndex := ListView1.Selected.Index;
  BitBtn4.ImageIndex := ListView1.Selected.Index;

  ico := FontAwesome.GetFAIconSolidFree(TFASolidFree(PtrInt(ListView1.Selected.Data)), 16);
  SpeedButton1.Glyph.Assign(ico);
  ico.Free;
  ico := FontAwesome.GetFAIconSolidFree(TFASolidFree(PtrInt(ListView1.Selected.Data)), 24);
  SpeedButton2.Glyph.Assign(ico);
  ico.Free;
  ico := FontAwesome.GetFAIconSolidFree(TFASolidFree(PtrInt(ListView1.Selected.Data)), 32);
  SpeedButton3.Glyph.Assign(ico);
  ico.Free;
  ico := FontAwesome.GetFAIconSolidFree(TFASolidFree(PtrInt(ListView1.Selected.Data)), 48);
  SpeedButton4.Glyph.Assign(ico);
  ico.Free;
end;

procedure TForm1.AfterConstruction;
begin
  inherited AfterConstruction;

  PrepareImageListAndControls;
  ReloadIcons;
  LoadSelectedIcon;
end;

end.

