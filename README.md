# LazFontAwesome

**[Font Awesome Free](https://fontawesome.com) 7.3.1 icons for Lazarus.** Render any of the 2163 free icons into a `TBitmap` (32-bit with alpha) at any size and color, and put them into your own `TImageList`, `TImage`, buttons or menus.

- **Pure Lazarus.** Rendering uses only LCL classes and LazFreeType, which ships with Lazarus. There is no `libfreetype`, no DLL or `.so`, and no other external library.
- **Single executable.** The Free fonts are compiled into the program as resources, so there are no font files to deploy next to your `.exe`. Only the style you use is linked: Solid is included by default, and Regular and Brands are added by putting one unit in your `uses` clause.
- **Typed icon names.** Every icon is an enum value named after its Font Awesome name: `folder-open` is `fas_folder_open`. You get code completion and compile-time checking, and no Unicode code points to look up.
- **Sharp at every size.** Icons are rendered from vector outlines, so 16, 24, 32 or 256 px are all crisp, which also suits HiDPI and multi-resolution `TImageList`s.
- **Low memory.** Nothing is pre-rendered. A font is parsed on first use (about 1 MB for all three styles), and you only keep the bitmaps you create.

> **Lazarus only.** The library relies on LCL classes (`TBitmap`, `TLazIntfImage`) and the LazFreeType package. It does **not** support Embarcadero Delphi, and it cannot be used from plain Free Pascal without the LCL.

> **About the fonts.** Font Awesome 7 ships its desktop fonts as OpenType with CFF outlines (`.otf`), which LazFreeType cannot read: it only supports TrueType outlines. The fonts included here were converted from the official OTF files to TTF. As the SIL Open Font License requires for modified fonts, they were renamed to *LazFA7 Free Solid*, *LazFA7 Free Regular* and *LazFA7 Brands*. Only the **Free** styles are included; see [Custom fonts](#custom-fonts-font-awesome-pro) for Pro.

## Gallery

<!-- screenshots -->

## Installation

Tested with Lazarus 4.8 and FPC 3.2.2. The package only needs the `LCL` package, which every Lazarus installation has.

1. Download or clone this repository.
2. In Lazarus choose **Package → Open Package File (.lpk)…** and open `lazfontawesome.lpk`.
3. In the package window click **Compile**.

That's all. LazFontAwesome is a *runtime* package: it adds no components to the palette, so it does not need **Install** or an IDE rebuild. After the steps above, Lazarus knows where to find the package.

To use it in a project, add it as a requirement once per project, either way:

- in the package window click **Use → Add to Project**, or
- open **Project → Project Inspector**, click **Add → New Requirement** and choose `lazfontawesome`.

Lazarus then compiles the package together with your project. The fonts, include files and resources are found through the package's own search paths, so your project needs no extra settings.

**Command line (`lazbuild`):**

```sh
lazbuild --add-package-link /path/to/lazfontawesome.lpk   # once
lazbuild myproject.lpi
```

## Usage

### Demo

To see LazFontAwesome in action, run demo `test/fademo.lpr`

### Basic example with the global `FontAwesome` object

The unit `FontAwesomeIcons` provides a shared `TFontAwesome` instance through the function `FontAwesome`. It is created on first use and freed when the program ends.

```pascal
uses
  FontAwesomeIcons;

procedure TForm1.FormCreate(Sender: TObject);
var
  Bmp: TBitmap;
begin
  ImageList1.Width := 24;
  ImageList1.Height := 24;

  Bmp := FontAwesome.GetFAIconSolidFree(fas_floppy_disk, 24);
  try
    ImageList1.Add(Bmp, nil);           // image index 0
  finally
    Bmp.Free;                           // the bitmap belongs to the caller
  end;

  // explicit color instead of the default one
  Bmp := FontAwesome.GetFAIconSolidFree(fas_trash, 24, clRed);
  try
    ImageList1.Add(Bmp, nil);           // image index 1
  finally
    Bmp.Free;
  end;

  // straight into a TImage
  Bmp := FontAwesome.GetFAIconSolidFree(fas_house, 64);
  try
    Image1.Picture.Assign(Bmp);
  finally
    Bmp.Free;
  end;

  BitBtn1.Images := ImageList1;
  BitBtn1.ImageIndex := 0;
end;
```

**Color.** The default icon color is `FontAwesome.Color`, which is `clBtnText` initially. It follows the system theme, so icons work on both light and dark themes. Every function takes an optional `AColor` parameter. Leaving it at `clNone` (the default) uses `Color`. System colors are converted to RGB when the bitmap is rendered, so after a theme change regenerate the bitmaps.

```pascal
FontAwesome.Color := clNavy;                                  // new default for all icons
Bmp := FontAwesome.GetFAIconSolidFree(fas_gear, 16);          // navy
Bmp := FontAwesome.GetFAIconSolidFree(fas_gear, 16, clGreen); // green, this call only
```

### Using the class directly

The global object is only a convenience. You can also create your own `TFontAwesome` instances, for example with their own default color or a different custom font file. Each instance loads its own copy of a font on first use.

```pascal
uses
  FontAwesomeIcons;

var
  FA: TFontAwesome;
  Bmp: TBitmap;
begin
  FA := TFontAwesome.Create;
  try
    FA.Color := clHighlight;
    Bmp := FA.GetFAIconSolidFree(fas_bell, 32);
    try
      ImageList1.Add(Bmp, nil);
    finally
      Bmp.Free;
    end;
  finally
    FA.Free;
  end;
end;
```

### Regular and Brands styles

Only the Solid font is linked into your program by default. To use Regular and/or Brands, add their resource units to the `uses` clause of **any** unit in your project:

```pascal
uses
  FontAwesomeIcons,
  FontAwesomeRegularRes,   // + ~70 KB: enables GetFAIconRegularFree
  FontAwesomeBrandsRes;    // + ~185 KB: enables GetFAIconBrandsFree

procedure TForm1.FormCreate(Sender: TObject);
var
  Bmp: TBitmap;
begin
  Bmp := FontAwesome.GetFAIconRegularFree(far_heart, 24, clRed);
  try
    ImageList1.Add(Bmp, nil);
  finally
    Bmp.Free;
  end;

  Bmp := FontAwesome.GetFAIconBrandsFree(fab_github, 24);
  try
    ImageList1.Add(Bmp, nil);
  finally
    Bmp.Free;
  end;
end;
```

The resource units contain no code, only the font resource. If a style is used without its unit, `EFontAwesome` is raised with a message naming the unit to add. `TFontAwesome.StyleAvailable(fasBrandsFree)` tells you in advance whether a style is linked.

| Style | Function | Enum type | Prefix | Icons | Linked by | Size |
|---|---|---|---|---|---|---|
| Solid | `GetFAIconSolidFree` | `TFASolidFree` | `fas_` | 1422 | `FontAwesomeIcons` | ~360 KB |
| Regular | `GetFAIconRegularFree` | `TFARegularFree` | `far_` | 169 | `FontAwesomeRegularRes` | ~70 KB |
| Brands | `GetFAIconBrandsFree` | `TFABrandsFree` | `fab_` | 572 | `FontAwesomeBrandsRes` | ~185 KB |

To leave even the Solid font out of the executable (for example when you only use Brands or a custom font), define `LAZFA_NO_SOLID` in the package's compiler options.

### Custom fonts (Font Awesome Pro)

The library includes only the Free fonts. To use another icon font, such as a Font Awesome Pro style you have a license for, point `FileName` to a **TrueType** (`.ttf`) file and request icons by character or by Unicode code point:

```pascal
FontAwesome.FileName := ExtractFilePath(ParamStr(0)) + 'fa-light-300.ttf';

Bmp := FontAwesome.GetFAIcon(#$EF#$80#$93, 24);   // the icon character in UTF-8 (U+F013, "gear")
Bmp := FontAwesome.GetFAIcon($F013, 24);          // or the Unicode code point
Bmp := FontAwesome.GetFAIcon($F013, 24, clRed);   // with an explicit color
```

- The code point of each icon is shown on its page on fontawesome.com.
- Font Awesome Pro also ships as `.otf` (CFF outlines), so it has to be converted to `.ttf` first. The script `tools/otf2ttf.pe` (FontForge) does that; see [Updating the fonts](#updating-the-fonts).
- A custom font is loaded from the file at runtime, so the file has to be shipped with your program. You can also compile it into your program as a resource: see how `src/fontawesomeregularres.pas` does it.
- Pro fonts are licensed separately by Fonticons, Inc. Do not commit them to a public repository.

## Icon names

Identifiers are the icon name from fontawesome.com with a style prefix (`fas_`, `far_`, `fab_`, the same prefixes Font Awesome uses), and `-` replaced by `_`:

| fontawesome.com | LazFontAwesome |
|---|---|
| `folder-open` (solid) | `fas_folder_open` |
| `heart` (regular) | `far_heart` |
| `42-group` (brands) | `fab_42_group` |

- Old and alternative names are available as aliases, e.g. `fas_cog = fas_gear` and `fas_save = fas_floppy_disk`.
- `FAIconName(fas_folder_open)` returns `'folder-open'`.
- `FAIconByName('folder-open', Icon)` finds the enum value by name, which is handy for icon names stored in configuration files.
- `cFASolidFreeCodes[fas_gear]` is the Unicode code point (`$F013`).
- FPC sets are limited to 256 elements, so `set of TFASolidFree` is not possible. Use arrays for lists of icons.

## HiDPI and multi-resolution image lists

A `TImageList` can hold every image in several sizes. Controls pick the one matching their `ImageWidth`/`ImagesWidth` and the screen DPI, provided the list has `Scaled = True`. Register the resolutions **before** adding images, and render each size from the font so that none of them is scaled:

```pascal
function AddFAIcon(AList: TCustomImageList; AIcon: TFASolidFree): Integer;
var
  R: TCustomImageListResolution;
  Bmps: array of TCustomBitmap;
  I: Integer;
begin
  Bmps := nil;
  for R in AList.Resolutions do                   // ascending by width
    Insert(FontAwesome.GetFAIconSolidFree(AIcon, R.Width), Bmps, Length(Bmps));
  try
    Result := AList.AddMultipleResolutions(Bmps);
  finally
    for I := 0 to High(Bmps) do
      Bmps[I].Free;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  ImageList1.Width := 16;                         // setting Width/Height clears the list
  ImageList1.Height := 16;
  ImageList1.Scaled := True;
  ImageList1.RegisterResolutions([16, 24, 32]);   // 100 %, 150 %, 200 %

  AddFAIcon(ImageList1, fas_floppy_disk);
  AddFAIcon(ImageList1, fas_folder_open);
end;
```

## Icon size and placement

Every bitmap is a square of `ASize` × `ASize` pixels. Most icons fit the square exactly. About a third of the Font Awesome 7 icons are wider than tall (e.g. `address-card`), and some stick out of the design box (e.g. `gear`). These are scaled down just enough to stay whole and are centered, so they never get clipped.

## Performance

Measured on Linux x86_64, GTK2:

- One 32 px icon renders in about 0.1 ms.
- Parsing all three fonts takes about 1 MB of RAM. Each style is loaded on its first use, and `ReleaseFonts` frees them again.
- `TFontAwesome` is not thread-safe. Use it from the main thread, or use one instance per thread.

## Updating the fonts

The repository contains everything needed to move to a newer Font Awesome release:

1. Download `fontawesome-free-X.Y.Z-desktop.zip` (the OTF fonts) and the npm package `@fortawesome/fontawesome-free` (for `metadata/icon-families.json`).
2. Convert each OTF to TTF and rename it, as the OFL requires:
   ```sh
   fontforge -lang=ff -script tools/otf2ttf.pe "Font Awesome 7 Free-Solid-900.otf" \
     fonts/lazfa7-free-solid-900.ttf LazFA7Free-Solid "LazFA7 Free Solid" "LazFA7 Free Solid"
   ```
   Repeat for Regular and Brands.
3. Regenerate the enums (`src/fa_*_free.inc`) and resources (`src/lazfa_*_free.res`) with the generator, which needs plain FPC only:
   ```sh
   fpc tools/lazfagen.lpr
   tools/lazfagen icon-families.json fonts src X.Y.Z
   ```
4. Run the tests in `test/`:
   - `fademo` checks that every enum value has a glyph in the font.
   - `cliptest` renders every icon at 12–64 px and fails if any icon is clipped.

## License

- **Library code:** see [`LICENSE`](LICENSE).
- **Fonts** (`fonts/*.ttf`, embedded in `src/lazfa_*.res`): [SIL Open Font License 1.1](fonts/LICENSE-FontAwesome.txt), Copyright Fonticons, Inc. These are Modified Versions of the Font Awesome Free fonts (converted from CFF to TrueType) and are therefore not named "Font Awesome", which is a Reserved Font Name.
- **Icon names and code points** (`src/fa_*_free.inc`): generated from the Font Awesome Free metadata, MIT License, Copyright Fonticons, Inc.

**If you distribute a program using this library:** the OFL requires that the font's copyright notice and license come with every copy. Include `fonts/LICENSE-FontAwesome.txt` with your program, or show its text in your About dialog.

**Brand icons** are trademarks of their respective owners. Font Awesome asks to use them only to represent the company, product or service they refer to.

Font Awesome is a trademark of Fonticons, Inc. This project is not affiliated with or endorsed by Fonticons, Inc.
