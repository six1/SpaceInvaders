program SpaceInvaders;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, unitMain, SysUtils
  {$IFDEF Windows}
  , jwawinGDI  // for binding Space Invaders Font ONLY WIN!
  {$ENDIF}
  { you can add units after this };

{$R *.res}

var
   sFontFile : String;
begin
  {$IFDEF Windows}
  sFontFile := 'Assets\Font\space_invaders.ttf';
  If FileExists(sFontFile) Then
     AddFontResourceEx(PChar(sFontFile), FR_PRIVATE, nil);
  {$ENDIF}
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.

