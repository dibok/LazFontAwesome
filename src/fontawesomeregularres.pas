{
  FontAwesomeRegularRes - links the Font Awesome Regular Free font resource
  into the program.

  Add this unit to the uses clause of any unit of your project to enable
  TFontAwesome.GetFAIconRegularFree. The unit contains no code: FPC links the
  resources of every unit that is part of the program, so the font ends up
  in the executable only when this unit is used.
}
unit FontAwesomeRegularRes;

{$mode objfpc}{$H+}

interface

implementation

{$R lazfa_regular_free.res}

end.
