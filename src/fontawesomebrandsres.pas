{
  FontAwesomeBrandsRes - links the Font Awesome Brands Free font resource
  into the program.

  Add this unit to the uses clause of any unit of your project to enable
  TFontAwesome.GetFAIconBrandsFree. The unit contains no code: FPC links the
  resources of every unit that is part of the program, so the font ends up
  in the executable only when this unit is used.
}
unit FontAwesomeBrandsRes;

{$mode objfpc}{$H+}

interface

implementation

{$R lazfa_brands_free.res}

end.
