unit unitMain;

// Space Invaders
// 2021/2 six1  www.lazarusforum.de
// Inspired on Game "Space Invaders 1978 by Taito"

{$mode objfpc}{$H+}

interface

uses
  {$IFDEF Windows}
  Windows,
  {$endif}
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, ComCtrls
  , BASS
  , ShapeCorner
  , math
  , DCPblowfish, DCPtwofish, DCPsha256, UniqueInstance
  , LCLIntf, LCLType
  , uInputQueryPos
  ;

type
  TAlienPos = record
    pos:integer;
    speed:integer;
    direction:boolean;
  end;

type
  TShoot = record
    pic:TImage;
    sidewaysDirection:integer;
    sidewaysAngle:integer;
  end;

type TMusic = record
  Opening1,
  GameOver,
  Explosion,
  Shoot,
  InvaderKilled,
  NextStage,
  UfoLowPitch,
  InvaderMove1,
  InvaderMove2,
  Opening2:integer;
  end;

type TLevel = record
  Anzahl_Alien_Reihen,
  Anzahl_Alien_pro_Reihen,
  Anzahl_Defense,           // Anzahl Defenses
  FireSpeed,                // negativ values: max shoots on screen at same time! One Shoot firing!
  BulletSpeed,              // Geschwindigkeit Geschosse. Bewegung in Pixel pro TimerGame(ms) Event
  MaxHitDefense,            // Maximale Treffer der Defense bis Zerstörung
  MaxHitGun,                // Maximale Treffer der Gun bis Zerstörung
  CountHitGun,              // Zähler Treffer Gun
  SpeedGun,                 // Bewegungsgeschwindigkeit Gun in Pixel pro TimerGame(ms) Event
  AlienFire,                // Schwellwert Auslösung Alien Fire ( TimerGame(ms) Event )
  AlienFireCount:integer;   // Counter Auslösung Alien Fire ( TimerGame(ms) Event )
  AlienFireSideways:boolean;// Bullets können seitlich fliegen. Versatz in Pixel
  AlienMothershipSpeed,     // Speed Alien Mothership in Pixel pro TimerGame(ms) Event  (lower is higher Speed)
  AlienMothershipGunSpeed,  // Feuergeschwindigkeit Alien Mothership
  AlienMothershipGunCount,  // Counter Feuergeschwindigkeit Alien Mothership
  AlienMothershipStart,     // Startzeitpunkt Alien Mothership
  AlienMothershipMaxHit,    // maximale Treffer für Zerstörung Alien Mothership
  AlienMothershipCountHit,  // Counter Treffer Alien Mothership
  Max_Ammunition,           // maximale Anzahl Schüsse für Level
  Count_Ammunition          // verwendete Schüsse im Level
  :integer;
end;

type

  { TForm1 }

  TForm1 = class(TForm)
    Background: TImage;
    Background1: TImage;
    HallOfFame: TListBox;
    ImageArcadeMachine: TImage;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    PicAlien1_1: TImage;
    PicAlien1_2: TImage;
    PicAlien2_1: TImage;
    PicAlien2_2: TImage;
    PicAlien3_1: TImage;
    PicAlien3_2: TImage;
    PicAlienBullet1: TImage;
    PicAlienBullet2: TImage;
    PicAlienMotherShip: TImage;
    PicDefense: TImage;
    PicDefense1: TImage;
    PicExplosion: TImage;
    PicExplosion1: TImage;
    PicExplosion2: TImage;
    PicGun: TImage;
    PicGunHit: TImage;
    PicPlayerBullet: TImage;
    PlayGround: TNewShape;
    ProgressBar1: TProgressBar;
    Timer1: TTimer;
    TimerGame: TTimer;
    TimerWindowPosition: TTimer;
    TimerGameEnd: TTimer;
    TimerStage: TTimer;
    UniqueInstance1: TUniqueInstance;
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Timer1Timer(Sender: TObject);
    procedure TimerGameTimer(Sender: TObject);
    procedure StartGame(Stage:integer);
    procedure ShowGameMain;
    procedure RemoveItems;
    {$IFDEF Windows}
    procedure TimerWindowPositionTimer(Sender: TObject);
    {$ENDIF}
    procedure TimerGameEndTimer(Sender: TObject);
    procedure TimerStageTimer(Sender: TObject);
    Function CollisionDetection(Bullet, Target:TRect; {0=down, 1=up}Direction:integer):boolean;
    procedure HallOfFameEntry(points:integer);
    {$IFDEF Windows}
    procedure PositionWindow;
    {$endif}
  private
    GUN:TImage;
    Aliens:array of array of TImage;
    AliensPos:array of TAlienPos;
    Shoot:array of TShoot;
    AlienShoot:array of TShoot;
    Defense:array of TImage;
    AlienMothership:TImage;
    Change_Speed, Change_Speed_Count:integer;
    Fire:boolean;
    HitDefense:array of integer;
    GameRunning:boolean;
    AlienAnim, AlienAnimCount, AlienPicNo:integer;
    strs: array[0..128] of HSTREAM;
    strc: Integer;
    left_Bound:integer;
    Points_Total, Points_Alien_1, Points_Alien_2, Points_Alien_3, Points_Alien_Mothership:integer;
    levelPos:integer;
    GameLevel:array of TLevel;
    SoundON:boolean;
    AlienSoundNo:integer;
    Music:TMusic;
    BackGroundImage:array of string;
  public

  end;


var
  Form1: TForm1;

CONST
  SALT_SpaceInvaders = 'SpaceInvadersSIX1';

implementation

{$R *.lfm}

{ TForm1 }


function MyCompareFunc(List: TStringList; Index1, Index2: Integer): Integer;
var
  s1, s2: String;
begin
  // Evtl vorhandene Leerzeichen entfernen
  s1 := trim(leftstr(List[Index1],5));
  s2 := trim(leftstr(List[Index2],5));
  // Strings in Integer konvertieren und diese vergleichen
  Result := CompareValue(StrToIntdef(s2,-1), StrToIntdef(s1,-1));
end;

function Code(key:string; uncrypted_string:string; level:integer):string; {$ifndef linux} stdcall; {$else} cdecl; {$endif} //Encode(key, text, level)
var
  motor: TDCP_blowfish;
  i: integer;
  t: string;
begin
  if level=0
    then level:=1
    else if level>2
      then level:=2;
  motor:=TDCP_blowfish.Create(nil);
  t:=uncrypted_string;
  for i:=1 to level do begin
    motor.InitStr(key,TDCP_sha256);
    t:=motor.EncryptString(t);
    motor.Burn;
  end;
  result:=t;
  motor.Free;
end;

function Decode(key:string; crypted_string:string; level:integer):string; {$ifndef linux} stdcall; {$else} cdecl; {$endif} //Decode(key, text, level)
var
  motor: TDCP_blowfish;
  i: integer;
  t: string;
begin
  if level=0
    then level:=1
    else if level>2
      then level:=2;
  motor:=TDCP_blowfish.Create(nil);
  t:=crypted_string;
  for i:=1 to level do begin
    motor.InitStr(key,TDCP_sha256);
    t:=motor.DecryptString(t);
    motor.Burn;
  end;
  result:=t;
  motor.Free;
end;

{$IFDEF Windows}
procedure TForm1.PositionWindow;
var
  TheWindowHandle: THandle;
  aRect: TRect;
  ExternesProgramm:string;
begin
  // relativ zu externem Programm positionieren
   ExternesProgramm:='[HIER DEN NAMEN DES EXT. PROGRAMMES EINTRAGEN]';
   if ExternesProgramm <> '' then
   begin
     TheWindowHandle:=FindWindow(nil, PChar(ExternesProgramm));
     if TheWindowHandle <> 0 then
     begin
       TimerWindowPosition.Enabled:=true;
       GetWindowRect(TheWindowHandle, aRect);
       form1.left:=430 + aRect.Left;
       form1.top:=aRect.Top+56;
     end else
     begin
       TimerWindowPosition.Enabled:=false;
       form1.left := trunc((screen.Width-form1.Width)/2);
       form1.top := trunc((screen.Height-form1.Height)/2);
     end;
   end;
end;
{$ENDIF}

procedure TForm1.FormCreate(Sender: TObject);
var
  x, y:integer;
  MMFile:string;
  f: PChar;
  L: TStringList;
  scale_x, scale_y:double;
  {$IFDEF LINUX}
  H:HWND;
  {$ENDIF}
begin
  Randomize;
  {$IFDEF Windows}
  TimerWindowPosition.OnTimer:=@TimerWindowPositionTimer;
  Label1.Font.Name:='Space Invaders';
  Label2.Font.Name:='Space Invaders';
  Label3.Font.Name:='Space Invaders';
  Label4.Font.Name:='Space Invaders';
  Label1.Font.size:=8;
  Label2.Font.size:=8;
  Label3.Font.size:=8;
  {$ENDIF}
  {$IFDEF Linux}
  Label1.Font.Name:='Consolas';
  Label2.Font.Name:='Consolas';
  Label3.Font.Name:='Consolas';
  Label4.Font.Name:='Consolas';
  Label1.Font.size:=10;
  Label2.Font.size:=10;
  Label3.Font.size:=10;
  {$ENDIF}
  HallOfFame.Font.Name:='Consolas';
  HallOfFame.Font.Size:=10;

  {$IFDEF Windows}
  PositionWindow;
  {$ENDIF}


  // check the correct BASS was loaded
  if (HIWORD(BASS_GetVersion) <> BASSVERSION) then
  begin
  	Showmessage('An incorrect version of BASS.DLL was loaded');
  	Halt;
  end;

  // Initialize audio - default device, 44100hz, stereo, 16 bits
  {$IFDEF LINUX}
   if not BASS_Init(-1, 44100, 0, @H, nil) then
   	Showmessage('Error initializing audio!');
  {$ELSE}
  if not BASS_Init(-1, 44100, 0, Handle, nil) then
  	Showmessage('Error initializing audio!');
  {$ENDIF}

  if (fileexists(extractfilepath(application.exename)+stringreplace('Assets\Pictures\Instruct3.png','\',PathDelim,[rfreplaceall]))) then
    Background1.Picture.LoadFromFile(extractfilepath(application.exename)+stringreplace('Assets\Pictures\Instruct3.png','\',PathDelim,[rfreplaceall]));


  strc := 0;		// stream count
  f := PChar(extractfilepath(application.exename)+stringreplace('Assets\Audio\01-opening-theme.mp3','\',PathDelim,[rfreplaceall]));
  strs[strc] := BASS_StreamCreateFile(False, f, 0, 0, 0);
  Music.Opening1:=strc;
  inc(strc);
  f := PChar(extractfilepath(application.exename)+stringreplace('Assets\Audio\gameover.mp3','\',PathDelim,[rfreplaceall]));
  strs[strc] := BASS_StreamCreateFile(False, f, 0, 0, 0);
  Music.GameOver:=strc;
  inc(strc);
  f := PChar(extractfilepath(application.exename)+stringreplace('Assets\Audio\explosion.wav','\',PathDelim,[rfreplaceall]));
  strs[strc] := BASS_StreamCreateFile(False, f, 0, 0, 0);
  Music.Explosion:=strc;
  inc(strc);
  f := PChar(extractfilepath(application.exename)+stringreplace('Assets\Audio\shoot.wav','\',PathDelim,[rfreplaceall]));
  strs[strc] := BASS_StreamCreateFile(False, f, 0, 0, 0);
  Music.Shoot:=strc;
  inc(strc);
  f := PChar(extractfilepath(application.exename)+stringreplace('Assets\Audio\invaderkilled.wav','\',PathDelim,[rfreplaceall]));
  strs[strc] := BASS_StreamCreateFile(False, f, 0, 0, 0);
  Music.InvaderKilled:=strc;
  inc(strc);
  f := PChar(extractfilepath(application.exename)+stringreplace('Assets\Audio\02-rounds-1-9.wav','\',PathDelim,[rfreplaceall]));
  strs[strc] := BASS_StreamCreateFile(False, f, 0, 0, 0);
  Music.NextStage:=strc;
  inc(strc);
  f := PChar(extractfilepath(application.exename)+stringreplace('Assets\Audio\ufo_lowpitch.wav','\',PathDelim,[rfreplaceall]));
  strs[strc] := BASS_StreamCreateFile(False, f, 0, 0, 0);
  Music.UfoLowPitch:=strc;
  inc(strc);
  // 8 - 9 Aliens moving Sound
  f := PChar(extractfilepath(application.exename)+stringreplace('Assets\Audio\fastinvader1.wav','\',PathDelim,[rfreplaceall]));
  strs[strc] := BASS_StreamCreateFile(False, f, 0, 0, 0);
  Music.InvaderMove1:=strc;
  inc(strc);
  f := PChar(extractfilepath(application.exename)+stringreplace('Assets\Audio\fastinvader2.wav','\',PathDelim,[rfreplaceall]));
  strs[strc] := BASS_StreamCreateFile(False, f, 0, 0, 0);
  Music.InvaderMove2:=strc;
  inc(strc);
  f := PChar(extractfilepath(application.exename)+stringreplace('Assets\Audio\spaceinvaders1.mpeg','\',PathDelim,[rfreplaceall]));
  strs[strc] := BASS_StreamCreateFile(False, f, 0, 0, 0);
  Music.Opening2:=strc;

  levelPos:=0;
  setlength(GameLevel,LevelPos+1);
  GameLevel[LevelPos].Anzahl_Alien_Reihen:=3;
  GameLevel[LevelPos].Anzahl_Alien_pro_Reihen:=6;
  GameLevel[LevelPos].Anzahl_Defense:=3;
  GameLevel[LevelPos].FireSpeed:=-3;
  GameLevel[LevelPos].BulletSpeed:=6;
  GameLevel[LevelPos].MaxHitDefense:=3;
  GameLevel[LevelPos].MaxHitGun:=2;
  GameLevel[LevelPos].CountHitGun:=0;
  GameLevel[LevelPos].SpeedGun:=6;
  GameLevel[LevelPos].AlienFire:=30;
  GameLevel[LevelPos].AlienFireCount:=0;
  GameLevel[LevelPos].AlienFireSideways:=false;
  GameLevel[LevelPos].AlienMothershipSpeed:=8;
  GameLevel[LevelPos].AlienMothershipGunSpeed:=40;
  GameLevel[LevelPos].AlienMothershipGunCount:=0;
  GameLevel[LevelPos].AlienMothershipStart:=random(200)+300;
  GameLevel[LevelPos].AlienMothershipMaxHit:=2;
  GameLevel[LevelPos].AlienMothershipCountHit:=0;
  GameLevel[LevelPos].Max_Ammunition:=-1;
  GameLevel[LevelPos].Count_Ammunition:=0;
  inc(LevelPos);
  setlength(GameLevel,LevelPos+1);
  GameLevel[LevelPos].Anzahl_Alien_Reihen:=3;
  GameLevel[LevelPos].Anzahl_Alien_pro_Reihen:=8;
  GameLevel[LevelPos].Anzahl_Defense:=2;
  GameLevel[LevelPos].FireSpeed:=-5;
  GameLevel[LevelPos].BulletSpeed:=6;
  GameLevel[LevelPos].MaxHitDefense:=3;
  GameLevel[LevelPos].MaxHitGun:=2;
  GameLevel[LevelPos].CountHitGun:=0;
  GameLevel[LevelPos].SpeedGun:=5;
  GameLevel[LevelPos].AlienFire:=30;
  GameLevel[LevelPos].AlienFireSideways:=false;
  GameLevel[LevelPos].AlienFireCount:=0;
  GameLevel[LevelPos].AlienMothershipSpeed:=10;
  GameLevel[LevelPos].AlienMothershipGunSpeed:=40;
  GameLevel[LevelPos].AlienMothershipGunCount:=0;
  GameLevel[LevelPos].AlienMothershipStart:=random(200)+300;
  GameLevel[LevelPos].AlienMothershipMaxHit:=2;
  GameLevel[LevelPos].AlienMothershipCountHit:=0;
  GameLevel[LevelPos].Max_Ammunition:=80;
  GameLevel[LevelPos].Count_Ammunition:=0;
  inc(LevelPos);
  setlength(GameLevel,LevelPos+1);
  GameLevel[LevelPos].Anzahl_Alien_Reihen:=3;
  GameLevel[LevelPos].Anzahl_Alien_pro_Reihen:=10;
  GameLevel[LevelPos].Anzahl_Defense:=2;
  GameLevel[LevelPos].FireSpeed:=10;
  GameLevel[LevelPos].BulletSpeed:=6;
  GameLevel[LevelPos].MaxHitDefense:=2;
  GameLevel[LevelPos].MaxHitGun:=2;
  GameLevel[LevelPos].CountHitGun:=0;
  GameLevel[LevelPos].SpeedGun:=5;
  GameLevel[LevelPos].AlienFire:=15;
  GameLevel[LevelPos].AlienFireCount:=0;
  GameLevel[LevelPos].AlienFireSideways:=true;
  GameLevel[LevelPos].AlienMothershipSpeed:=10;
  GameLevel[LevelPos].AlienMothershipGunSpeed:=20;
  GameLevel[LevelPos].AlienMothershipGunCount:=0;
  GameLevel[LevelPos].AlienMothershipStart:=random(200)+200;
  GameLevel[LevelPos].AlienMothershipMaxHit:=3;
  GameLevel[LevelPos].AlienMothershipCountHit:=0;
  GameLevel[LevelPos].Max_Ammunition:=100;
  GameLevel[LevelPos].Count_Ammunition:=0;
  inc(LevelPos);
  setlength(GameLevel,LevelPos+1);
  GameLevel[LevelPos].Anzahl_Alien_Reihen:=3;
  GameLevel[LevelPos].Anzahl_Alien_pro_Reihen:=10;
  GameLevel[LevelPos].Anzahl_Defense:=2;
  GameLevel[LevelPos].FireSpeed:=4;
  GameLevel[LevelPos].BulletSpeed:=6;
  GameLevel[LevelPos].MaxHitDefense:=2;
  GameLevel[LevelPos].MaxHitGun:=2;
  GameLevel[LevelPos].CountHitGun:=0;
  GameLevel[LevelPos].SpeedGun:=GameLevel[LevelPos].MaxHitDefense+2;
  GameLevel[LevelPos].AlienFire:=10;
  GameLevel[LevelPos].AlienFireCount:=0;
  GameLevel[LevelPos].AlienFireSideways:=true;
  GameLevel[LevelPos].AlienMothershipSpeed:=12;
  GameLevel[LevelPos].AlienMothershipGunSpeed:=10;
  GameLevel[LevelPos].AlienMothershipGunCount:=0;
  GameLevel[LevelPos].AlienMothershipStart:=random(200)+150;
  GameLevel[LevelPos].AlienMothershipMaxHit:=3;
  GameLevel[LevelPos].AlienMothershipCountHit:=0;
  GameLevel[LevelPos].Max_Ammunition:=100;
  GameLevel[LevelPos].Count_Ammunition:=0;
  inc(LevelPos);
  setlength(GameLevel,LevelPos+1);
  GameLevel[LevelPos].Anzahl_Alien_Reihen:=3;
  GameLevel[LevelPos].Anzahl_Alien_pro_Reihen:=10;
  GameLevel[LevelPos].Anzahl_Defense:=2;
  GameLevel[LevelPos].FireSpeed:=4;
  GameLevel[LevelPos].BulletSpeed:=6;
  GameLevel[LevelPos].MaxHitDefense:=2;
  GameLevel[LevelPos].MaxHitGun:=2;
  GameLevel[LevelPos].CountHitGun:=0;
  GameLevel[LevelPos].SpeedGun:=GameLevel[LevelPos].MaxHitDefense+2;
  GameLevel[LevelPos].AlienFire:=10;
  GameLevel[LevelPos].AlienFireCount:=0;
  GameLevel[LevelPos].AlienFireSideways:=true;
  GameLevel[LevelPos].AlienMothershipSpeed:=12;
  GameLevel[LevelPos].AlienMothershipGunSpeed:=10;
  GameLevel[LevelPos].AlienMothershipGunCount:=0;
  GameLevel[LevelPos].AlienMothershipStart:=random(200)+150;
  GameLevel[LevelPos].AlienMothershipMaxHit:=3;
  GameLevel[LevelPos].AlienMothershipCountHit:=0;
  GameLevel[LevelPos].Max_Ammunition:=100;
  GameLevel[LevelPos].Count_Ammunition:=0;
  inc(LevelPos);
  setlength(GameLevel,LevelPos+1);
  GameLevel[LevelPos].Anzahl_Alien_Reihen:=3;
  GameLevel[LevelPos].Anzahl_Alien_pro_Reihen:=6;
  GameLevel[LevelPos].Anzahl_Defense:=1;
  GameLevel[LevelPos].FireSpeed:=6;
  GameLevel[LevelPos].BulletSpeed:=6;
  GameLevel[LevelPos].MaxHitDefense:=3;
  GameLevel[LevelPos].MaxHitGun:=2;
  GameLevel[LevelPos].CountHitGun:=0;
  GameLevel[LevelPos].SpeedGun:=GameLevel[LevelPos].MaxHitDefense+2;
  GameLevel[LevelPos].AlienFire:=8;
  GameLevel[LevelPos].AlienFireCount:=0;
  GameLevel[LevelPos].AlienFireSideways:=true;
  GameLevel[LevelPos].AlienMothershipSpeed:=10;
  GameLevel[LevelPos].AlienMothershipGunSpeed:=15;
  GameLevel[LevelPos].AlienMothershipGunCount:=0;
  GameLevel[LevelPos].AlienMothershipStart:=random(200)+150;
  GameLevel[LevelPos].AlienMothershipMaxHit:=4;
  GameLevel[LevelPos].AlienMothershipCountHit:=0;
  GameLevel[LevelPos].Max_Ammunition:=100;
  GameLevel[LevelPos].Count_Ammunition:=0;
  inc(LevelPos);
  setlength(GameLevel,LevelPos+1);
  GameLevel[LevelPos].Anzahl_Alien_Reihen:=3;
  GameLevel[LevelPos].Anzahl_Alien_pro_Reihen:=6;
  GameLevel[LevelPos].Anzahl_Defense:=2;
  GameLevel[LevelPos].FireSpeed:=3;
  GameLevel[LevelPos].BulletSpeed:=6;
  GameLevel[LevelPos].MaxHitDefense:=3;
  GameLevel[LevelPos].MaxHitGun:=2;
  GameLevel[LevelPos].CountHitGun:=0;
  GameLevel[LevelPos].SpeedGun:=10;
  GameLevel[LevelPos].AlienFire:=20;
  GameLevel[LevelPos].AlienFireSideways:=true;
  GameLevel[LevelPos].AlienFireCount:=0;
  GameLevel[LevelPos].AlienMothershipSpeed:=5;
  GameLevel[LevelPos].AlienMothershipGunSpeed:=30;
  GameLevel[LevelPos].AlienMothershipGunCount:=0;
  GameLevel[LevelPos].AlienMothershipStart:=random(200)+150;
  GameLevel[LevelPos].AlienMothershipMaxHit:=4;
  GameLevel[LevelPos].AlienMothershipCountHit:=0;
  GameLevel[LevelPos].Max_Ammunition:=100;
  GameLevel[LevelPos].Count_Ammunition:=0;
  inc(LevelPos);
  setlength(GameLevel,LevelPos+1);
  GameLevel[LevelPos].Anzahl_Alien_Reihen:=3;
  GameLevel[LevelPos].Anzahl_Alien_pro_Reihen:=6;
  GameLevel[LevelPos].Anzahl_Defense:=3;
  GameLevel[LevelPos].FireSpeed:=3;
  GameLevel[LevelPos].BulletSpeed:=6;
  GameLevel[LevelPos].MaxHitDefense:=3;
  GameLevel[LevelPos].MaxHitGun:=2;
  GameLevel[LevelPos].CountHitGun:=0;
  GameLevel[LevelPos].SpeedGun:=10;
  GameLevel[LevelPos].AlienFire:=20;
  GameLevel[LevelPos].AlienFireCount:=0;
  GameLevel[LevelPos].AlienFireSideways:=true;
  GameLevel[LevelPos].AlienMothershipSpeed:=5;
  GameLevel[LevelPos].AlienMothershipGunSpeed:=30;
  GameLevel[LevelPos].AlienMothershipGunCount:=0;
  GameLevel[LevelPos].AlienMothershipStart:=random(200)+150;
  GameLevel[LevelPos].AlienMothershipMaxHit:=4;
  GameLevel[LevelPos].AlienMothershipCountHit:=0;
  GameLevel[LevelPos].Max_Ammunition:=100;
  GameLevel[LevelPos].Count_Ammunition:=0;
  inc(LevelPos);
  setlength(GameLevel,LevelPos+1);
  GameLevel[LevelPos].Anzahl_Alien_Reihen:=3;
  GameLevel[LevelPos].Anzahl_Alien_pro_Reihen:=6;
  GameLevel[LevelPos].Anzahl_Defense:=3;
  GameLevel[LevelPos].FireSpeed:=3;
  GameLevel[LevelPos].BulletSpeed:=6;
  GameLevel[LevelPos].MaxHitDefense:=3;
  GameLevel[LevelPos].MaxHitGun:=2;
  GameLevel[LevelPos].CountHitGun:=0;
  GameLevel[LevelPos].SpeedGun:=10;
  GameLevel[LevelPos].AlienFire:=20;
  GameLevel[LevelPos].AlienFireCount:=0;
  GameLevel[LevelPos].AlienFireSideways:=true;
  GameLevel[LevelPos].AlienMothershipSpeed:=5;
  GameLevel[LevelPos].AlienMothershipGunSpeed:=30;
  GameLevel[LevelPos].AlienMothershipGunCount:=0;
  GameLevel[LevelPos].AlienMothershipStart:=random(200)+150;
  GameLevel[LevelPos].AlienMothershipMaxHit:=4;
  GameLevel[LevelPos].AlienMothershipCountHit:=0;
  GameLevel[LevelPos].Max_Ammunition:=100;
  GameLevel[LevelPos].Count_Ammunition:=0;


  Points_Total:=0;
  Points_Alien_1:=10;
  Points_Alien_2:=15;
  Points_Alien_3:=20;
  Points_Alien_Mothership:=50;

  SoundON:=true;
  HallOfFame.Items.Clear;
  if fileexists(extractfilepath(application.exename)+stringreplace('Assets\HallOfFame.txt','\',PathDelim,[rfreplaceall])) then
  begin
    HallOfFame.Items.LoadFromFile(extractfilepath(application.exename)+stringreplace('Assets\HallOfFame.txt','\',PathDelim,[rfreplaceall]));
    for x := 0 to HallOfFame.Items.Count-1 do
    begin
      HallOfFame.Items[x]:=Decode(SALT_SpaceInvaders, HallOfFame.Items[x], 1);
    end;
  end;

  scale_x:=PlayGround.Width/720;       // scaling from first version
  scale_y:=PlayGround.Height/411;
  PicAlien1_1.Width:=trunc(PicAlien1_1.Width*scale_x);
  PicAlien1_1.Height:=trunc(PicAlien1_1.Height*scale_y);
  PicAlien2_1.Width:=trunc(PicAlien2_1.Width*scale_x);
  PicAlien2_1.Height:=trunc(PicAlien2_1.Height*scale_y);
  PicAlien3_1.Width:=trunc(PicAlien3_1.Width*scale_x);
  PicAlien3_1.Height:=trunc(PicAlien3_1.Height*scale_y);
  PicGun.Width:=trunc(PicGun.Width*scale_x);
  PicGun.Height:=trunc(PicGun.Height*scale_y);
  PicGunHit.Width:=trunc(PicGunHit.Width*scale_x);
  PicGunHit.Height:=trunc(PicGunHit.Height*scale_y);
  PicDefense.Width:=trunc(PicDefense.Width*scale_x);
  PicDefense.Height:=trunc(PicDefense.Height*scale_y);
  PicAlienMotherShip.Width:=trunc(PicAlienMotherShip.Width*scale_x);
  PicAlienMotherShip.Height:=trunc(PicAlienMotherShip.Height*scale_y);
  PicAlienBullet1.Width:=trunc(PicAlienBullet1.Width*scale_x);
  PicAlienBullet1.Height:=trunc(PicAlienBullet1.Height*scale_y);
  PicPlayerBullet.Width:=trunc(PicPlayerBullet.Width*scale_x);
  PicPlayerBullet.Height:=trunc(PicPlayerBullet.Height*scale_y);

  setlength(BackGroundImage, 3);
  BackGroundImage[0] := extractfilepath(application.exename)+stringreplace('Assets\Pictures\invaders1.png','\',PathDelim,[rfreplaceall]);
  BackGroundImage[1] := extractfilepath(application.exename)+stringreplace('Assets\Pictures\invaders2.png','\',PathDelim,[rfreplaceall]);
  BackGroundImage[2] := extractfilepath(application.exename)+stringreplace('Assets\Pictures\invaders3.png','\',PathDelim,[rfreplaceall]);

  ShowGameMain;
end;


procedure TForm1.ShowGameMain;
var
  x, y:integer;
begin
  GameRunning:=false;
  TimerGame.enabled:=false;
  LevelPos:=0;
  Label1.caption:='Hit any Key to start...';
  if Points_Total > 0 then
  begin
    Label2.caption:='Last Player '+inttostr(Points_Total)+' Points';
    HallOfFameEntry( Points_Total);
  end else
  begin
    Label2.caption:='';
  end;
  Label3.caption:='ESC-End';
  Label5.caption:='six1 2021 inspired by "Space Invaders 1978 by Taito"';
  RemoveItems;
  Points_Total:=0;
  Progressbar1.Visible:=false;
  Background.Visible:=false;
  Label5.Visible:=true;
  Background1.Visible:=true;
  HallOfFame.Visible:=true;
  Label4.Visible:=true;
  if SoundON then BASS_ChannelPlay(strs[Music.Opening2], True);
end;

procedure TForm1.RemoveItems;
var
  x, y:integer;
begin
  // Remove Aliens
  for y := 0 to high(Aliens) do
  begin
    for x := 0 to high(Aliens[y]) do
    begin
      if Aliens[y][x] <> NIL then
        Aliens[y][x].Visible:=false;
    end;
  end;
  // Remove defense
  for y := 0 to high(Defense) do
    if Defense[y] <> NIL then
      Defense[y].Visible:=false;
  // Remove Gun
  if GUN <> NIL then
    GUN.Visible:=false;
  // Remove Alien Mothership
  if AlienMothership <> NIL then
    AlienMothership.visible:=false;
  // Remove Alien Fire
  for x := high(AlienShoot) downto 0 do
  begin
      AlienShoot[x].pic.Free;
      Delete(AlienShoot, x, 1);
  end;
  // Remove Player Fire
  for x := high(Shoot) downto 0 do
  begin
      Shoot[x].pic.Free;
      Delete(Shoot, x, 1);
  end;
end;

{$IFDEF Windows}
procedure TForm1.TimerWindowPositionTimer(Sender: TObject);
begin
  PositionWindow;
end;
{$ENDIF}

procedure TForm1.TimerGameEndTimer(Sender: TObject);
var
  l, p:QWORD;
begin
  TimerGameEnd.Enabled:=false;
  GameRunning:=false;
  if SoundON then
  begin
    l:=BASS_ChannelGetLength(strs[Music.GameOver],0);
    BASS_ChannelPlay(strs[Music.GameOver], True);
    p:=BASS_ChannelGetPosition(strs[Music.GameOver],0);
    while p < l do
      p:=BASS_ChannelGetPosition(strs[Music.GameOver],0);
  end;
  ShowGameMain;
end;

procedure TForm1.TimerStageTimer(Sender: TObject);
begin
  TimerStage.Enabled:=false;
  StartGame(levelPos);
end;

procedure TForm1.HallOfFameEntry(points:integer);
var
  x, y, a, b, i:integer;
  UserString: string;
  L: TStringList;
begin
  // In "Hall of Fame" eintragen...
  i:=0;
  if HallOfFame.items.Count > 0 then
    i:=strtointdef(trim(leftstr(HallOfFame.items[HallOfFame.Items.Count-1],5)),-1);
  if points > i then
  begin
    UserString := InputBoxPos('Hall of Fame',
    'Please type in your Name (max. 10 Char)', '', Form1.left+160, Form1.top+300);
    HallOfFame.Items.Add(format('%-5s ',[inttostr(points)])+format('%10s ',[leftstr(UserString,10)]));
    L := TStringList.Create;
    try
      L.Assign(HallOfFame.Items);
      L.CustomSort(@MyCompareFunc);
      while L.Count > 10 do
        L.Delete(L.Count-1);
      HallOfFame.Items.Assign(L);
      for x := 0 to L.Count-1 do
      begin
        L[x]:=Code(SALT_SpaceInvaders, L[x], 1);
      end;
      L.SaveToFile(extractfilepath(application.exename)+stringreplace('Assets\HallOfFame.txt','\',PathDelim,[rfreplaceall]));
    finally
      L.Free;
    end;
  end;
end;

procedure TForm1.StartGame(Stage:integer);
var
  x, y, a, b, i:integer;
begin
  TimerGame.enabled:=false;
  HallOfFame.Visible:=false;
  Label4.Visible:=false;
  ProgressBar1.Visible:=false;
  application.ProcessMessages;
  if SoundON then BASS_ChannelStop(strs[Music.Opening2]);
  if Stage > high(GameLevel) then
  begin
    ShowGameMain;
    exit;
  end;

  i:=Random(high(BackGroundImage)+1);
  if fileexists(BackGroundImage[i]) then
    BackGround.Picture.LoadFromFile(BackGroundImage[i]);

  if Stage > 0 then
  begin
    Background.Visible:=false;
    Label1.caption:='Loading next Level...';
    Label5.Visible:=false;
    Background1.Visible:=true;
    ProgressBar1.Visible:=true;
    Label3.caption:='Stage '+inttostr(Stage+1);
    RemoveItems;
    if SoundON then BASS_ChannelPlay(strs[Music.NextStage], True);
    ProgressBar1.Position:=0;
    i := gettickcount;
    while (i+10000) > gettickcount do
    begin
      ProgressBar1.Position:=trunc(((i+10000) - gettickcount)/100);
      //if (GetKeyState(VK_SPACE) < 0) then i:=0;
      application.ProcessMessages;
    end;
    if SoundON then BASS_ChannelStop(strs[Music.NextStage]);
    if GameRunning=false then
      exit;
    ProgressBar1.Visible:=false;
    Background.Visible:=true;
    Label5.Visible:=false;
    Background1.Visible:=false;
  end else
  begin
    Background.Visible:=true;
    Label5.Visible:=false;
    Background1.Visible:=false;
  end;



  AlienAnim:=10;
  AlienAnimCount:=0;
  AlienPicNo:=1;
  GameLevel[LevelPos].CountHitGun:=0;
  GameLevel[LevelPos].Count_Ammunition:=0;


  left_Bound:=PlayGround.left + 30;// Fire from this position


  if GUN = NIL then
  begin
    GUN:=TImage.Create(nil);
    GUN.Parent:=Form1;
    GUN.Picture.Assign( PicGun.Picture);
    GUN.Width:=PicGun.Width;
    GUN.Height:=PicGun.Height;
    GUN.Stretch:=true;
    GUN.Proportional:=true;
    GUN.top:=PlayGround.top + PlayGround.Height  -10 -GUN.Picture.Height;
    GUN.Transparent:=true;
  end;
  GUN.Visible:=true;
  GUN.left:=PlayGround.left + 20;

  if AlienMothership = NIL then
  begin
    AlienMothership:=TImage.Create(nil);
    AlienMothership.Parent:=Form1;
    AlienMothership.Picture.Assign( PicAlienMotherShip.Picture);
    AlienMothership.Width:=PicAlienMotherShip.Width;
    AlienMothership.Height:=PicAlienMotherShip.Height;
    AlienMothership.Stretch:=true;
    AlienMothership.Proportional:=true;
    AlienMothership.Transparent:=true;
    AlienMothership.top:=PlayGround.top + 40 + (GameLevel[LevelPos].Anzahl_Alien_Reihen * 40);
  end;
  AlienMothership.left:=PlayGround.left + (-1*AlienMothership.Picture.Width);
  AlienMothership.Visible:=true;
  AlienMothership.Tag:=0;

  setlength( Aliens, GameLevel[LevelPos].Anzahl_Alien_Reihen);
  setlength( AliensPos, GameLevel[LevelPos].Anzahl_Alien_Reihen);
  for y := 0 to high(Aliens) do
  begin
    setlength( Aliens[y], GameLevel[LevelPos].Anzahl_Alien_pro_Reihen);
    if y > 2 then i := 2 else i := y;
    a:= trunc(left_Bound - ((Findcomponent('PicAlien'+inttostr(i+1)+'_1')as TImage).Picture.Width/2));
    b:= trunc((PlayGround.width-(2*a)-( GameLevel[LevelPos].Anzahl_Alien_pro_Reihen * (Findcomponent('PicAlien'+inttostr(i+1)+'_1')as TImage).Picture.Width)));
    if GameLevel[LevelPos].Anzahl_Alien_pro_Reihen > 1 then
      b:= left_Bound+trunc(b/(GameLevel[LevelPos].Anzahl_Alien_pro_Reihen-1));
    for x := 0 to high(Aliens[y]) do
    begin
      if Aliens[y][x] = NIL then
      begin
        Aliens[y][x]:=TImage.Create(nil);
        Aliens[y][x].Parent:=Form1;
        Aliens[y][x].Top:=PlayGround.top +40+(y*40);
        Aliens[y][x].Picture.Assign( (Findcomponent('PicAlien'+inttostr(i+1)+'_1')as TImage).Picture);
        Aliens[y][x].Width:=(Findcomponent('PicAlien'+inttostr(i+1)+'_1')as TImage).Width;
        Aliens[y][x].Height:=(Findcomponent('PicAlien'+inttostr(i+1)+'_1')as TImage).Height;
        Aliens[y][x].Stretch:=true;
        Aliens[y][x].Proportional:=true;
      end;
      Aliens[y][x].Left:=PlayGround.left + a + (x*b);
      Aliens[y][x].visible:=true;
      Aliens[y][x].tag:=0;
    end;
    AliensPos[y].pos:=random(40)-20;
    AliensPos[y].direction:=random(1)=0;
    AliensPos[y].speed:=random(3)+1;
  end;


  setlength( Defense, GameLevel[LevelPos].Anzahl_Defense);
  a:=  PlayGround.width - (GameLevel[LevelPos].Anzahl_Defense*PicDefense.Picture.Width);
  a:= trunc( a/(GameLevel[LevelPos].Anzahl_Defense+1));
  for y := 0 to high(Defense) do
  begin
    if Defense[y] = NIL then
    begin
      Defense[y]:=TImage.Create(nil);
      Defense[y].Parent:=Form1;
      Defense[y].Picture.Assign(PicDefense.Picture);
      Defense[y].Width:=PicDefense.Width;
      Defense[y].Height:=PicDefense.Height;
      Defense[y].Stretch:=true;
      Defense[y].Proportional:=true;
      Defense[y].Top:=GUN.top - Defense[y].Height ;
    end;
    Defense[y].Picture.Assign(PicDefense.Picture);
    Defense[y].Left:=PlayGround.left +((y+1)*a)+(y*+PicDefense.Picture.Width);
    Defense[y].Picture.Assign(PicDefense.Picture);
    Defense[y].Visible:=true;
    Defense[y].tag:=0;
  end;

  Change_Speed_Count:=0;
  setlength( HitDefense, GameLevel[LevelPos].Anzahl_Defense);
  for y := 0 to high(HitDefense) do
     HitDefense[y]:=0;

  ImageArcadeMachine.BringToFront;
  TimerGame.Enabled:=true;
end;

procedure TForm1.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState
  );
var
  UserString:string;
begin
  if (Shift = [SSCtrl]) then
  begin
    // Cheat Mode
    if (key = ord('C')) then
    begin
      UserString := InputBox('Cheat State',
      'Type in Level you want to start (1-'+inttostr( high(GameLevel)+1)+')', '');
      if strtointdef(UserString,-1) <> -1 then
      begin
        if (high(GameLevel) >= (strtointdef(UserString,-1)-1)) then
        begin
          levelPos:=strtointdef(UserString,-1)-1;
          Points_Total:=0;
          RemoveItems;
          GameRunning:=true;
          StartGame(levelPos);
        end;
      end;
    end;
    // Pause Game
    if (key = ord('P')) then
      TimerGame.Enabled:=not TimerGame.Enabled;
    // switch Sound on/off
    if (key = ord('S')) then
    begin
      SoundON:=not SoundON;
      if not SoundON then
        BASS_ChannelStop(strs[Music.Opening2])
      else
        if GameRunning=false then
          BASS_ChannelPlay(strs[Music.Opening2], true)
    end;
  end else
  begin
    if Key = VK_ESCAPE then
    begin
      TimerGame.enabled:=false;
      if SoundON then BASS_ChannelStop(strs[Music.NextStage]);
      if GameRunning=true then
         ShowGameMain
      else
         close;
      exit;
    end;
    if GameRunning=false then
    begin
      levelPos:=0;
      Points_Total:=0;
      StartGame(levelPos);
      GameRunning:=true;
    end;
    if (GameLevel[LevelPos].FireSpeed < 0) then
      if (key=VK_Space)or(key=VK_UP) then
        Fire:=true;
  end;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
var
  l,p:integer;
begin
  if GameRunning=false then
  begin
    if SoundON then
    begin
     l:=BASS_ChannelGetLength(strs[Music.Opening2], 0);
     p:=BASS_ChannelGetPosition(strs[Music.Opening2], 0);
     if p >= (l-10) then
        BASS_ChannelPlay(strs[Music.Opening2], True);
    end;
  end;

end;

Function TForm1.CollisionDetection(Bullet, Target:TRect; {0=down, 1=up}Direction:integer):boolean;
var
  HotPointBullet, BulletTop, BulletBottom : integer;
  TargetAreaLeft, TargetAreaRight, TargetAreaStart, TargetAreaEnd : integer;
begin
  HotPointBullet:=Bullet.Left+trunc((Bullet.Right-Bullet.Left)/2);
  TargetAreaLeft:=Target.Left;
  TargetAreaRight:=Target.Right;
  if Direction=1 then
  begin
    // Bullet direction up
    BulletTop:=Bullet.Top;
    BulletBottom:=Bullet.Bottom;
    TargetAreaStart:=Target.Bottom;
    TargetAreaEnd:=Target.Top;
    Result:=(HotPointBullet >= TargetAreaLeft)and(HotPointBullet <= TargetAreaRight)
             and
            (BulletTop <= TargetAreaStart)and(BulletTop >= TargetAreaEnd);
  end else
  begin
    // Bullet direction down
    BulletBottom:=Bullet.Top;
    BulletTop:=Bullet.Bottom;
    TargetAreaEnd:=Target.Bottom;
    TargetAreaStart:=Target.Top;
    Result:=(HotPointBullet >= TargetAreaLeft)and(HotPointBullet <= TargetAreaRight)
             and
            (BulletTop >= TargetAreaStart)and(BulletTop <= TargetAreaEnd);
  end;
end;

procedure TForm1.TimerGameTimer(Sender: TObject);
var
  x,y,z,i:integer;
  Count_Aliens:integer;
  AlienChange:boolean;
begin
  if (GetKeyState(VK_LEFT) < 0)and(GUN.left>(PlayGround.left +20)) then GUN.left := GUN.left - GameLevel[LevelPos].SpeedGun;
  if (GetKeyState(VK_RIGHT) < 0)and(GUN.left<(PlayGround.left +PlayGround.width-20-GUN.Picture.Width)) then GUN.left := GUN.left + GameLevel[LevelPos].SpeedGun;

  // variable Alien Speed
  inc(Change_Speed_Count,1);
  if Change_Speed_Count >= Change_Speed then
  begin
    for i:= 0 to high(AliensPos) do
      AliensPos[i].speed:=random(3)+1; // Alien pixel move
    Change_Speed_Count:=0;
    Change_Speed:=Random(40)+20; // next Speed Change
  end;

  // anything left to destroy? :-)
  Count_Aliens:=0;
  for y := 0 to high(Aliens) do
    for x := 0 to high(Aliens[y]) do
      if Aliens[y][x].Visible=true then
        inc(Count_Aliens);
  Label1.caption:='Points '+inttostr(Points_Total);
  if (Count_Aliens = 0)and(AlienMothership.tag=0) then
  begin
    // Next level? All Aliens are dead...
    TimerGame.enabled:=false;
    GameRunning:=true;
    // calculate Points...
    Points_Total:=Points_Total-GameLevel[LevelPos].Count_Ammunition;
    inc(levelPos);
    TimerStage.Enabled:=true;
    exit;
  end;


//**************************
//  MOVE Items
//**************************
// Alien Mothership
   if (AlienMothership.tag=0) then
     GameLevel[LevelPos].AlienMothershipStart:=GameLevel[LevelPos].AlienMothershipStart-1;
   if (AlienMothership.tag=0)and(GameLevel[LevelPos].AlienMothershipStart <= 0) then
   begin
     AlienMothership.tag:=1;
     GameLevel[LevelPos].AlienMothershipStart:=random(100)+60;
     if SoundON then BASS_ChannelPlay(strs[Music.UfoLowPitch],true);
   end else
   begin
     if (AlienMothership.tag=1) then
     begin
       AlienMothership.Left:=AlienMothership.Left+GameLevel[LevelPos].AlienMothershipSpeed;
       if (AlienMothership.Left > (PlayGround.left +PlayGround.width)) then
       begin
         AlienMothership.left:=PlayGround.left + (-1*AlienMothership.Picture.Width);
         GameLevel[LevelPos].AlienMothershipCountHit:=0;
          AlienMothership.tag:=0;
       end else
       begin
         // AlienMothership Gun
         inc(GameLevel[LevelPos].AlienMothershipGunCount, random(5));
         if GameLevel[LevelPos].AlienMothershipGunCount >= GameLevel[LevelPos].AlienMothershipGunSpeed then
         begin
            // Alien Fire!
            GameLevel[LevelPos].AlienMothershipGunCount:=0;
            setlength(AlienShoot,high(AlienShoot)+2);
            AlienShoot[high(AlienShoot)].pic:=TImage.Create(nil);
            AlienShoot[high(AlienShoot)].pic.Parent:=Form1;
            AlienShoot[high(AlienShoot)].pic.Picture.Assign(PicAlienBullet1.Picture);
            AlienShoot[high(AlienShoot)].pic.Width:=PicAlienBullet1.Width;
            AlienShoot[high(AlienShoot)].pic.Height:=PicAlienBullet1.Height;
            AlienShoot[high(AlienShoot)].pic.Stretch:=true;
            AlienShoot[high(AlienShoot)].pic.Proportional:=true;
            x:=AlienMothership.Left+trunc(AlienMothership.Picture.Width/2)-trunc(AlienShoot[high(AlienShoot)].pic.Width/2);
            AlienShoot[high(AlienShoot)].pic.Left:=x;
            AlienShoot[high(AlienShoot)].pic.Top:=AlienMothership.Top+AlienMothership.Picture.Height;
         end;
       end;
     end;
   end;

   // move Aliens
   if Count_Aliens > 0 then
   begin
    for i := 0 to GameLevel[LevelPos].Anzahl_Alien_Reihen-1 do
    begin
      if AliensPos[i].direction = false then
      begin
        inc(AliensPos[i].pos,AliensPos[i].speed);
        if AliensPos[i].pos >30 then
        begin
          AliensPos[i].direction:= not AliensPos[i].direction;
        end;
      end else
      begin
        dec(AliensPos[i].pos,AliensPos[i].speed);
        if AliensPos[i].pos < -30 then
        begin
          AliensPos[i].direction:= not AliensPos[i].direction;
        end;
      end;
      for x := 0 to GameLevel[LevelPos].Anzahl_Alien_pro_Reihen-1 do
      begin
        Aliens[i][x].Left:=PlayGround.left +40+AliensPos[i].pos +  trunc(Aliens[i][x].Picture.Width/2)+(trunc((PlayGround.width-80)/(high(Aliens[i])+1))*x);
      end;
    end;
   end;


//**************************
//  check hit objects
//**************************
  for x := 0 to high(AlienShoot) do
  begin
    if (AlienShoot[x].pic.Top)>=((PlayGround.top+PlayGround.Height)-(AlienShoot[x].pic.Height+20)) then
    begin
      AlienShoot[x].pic.Visible:=false;
    end;
  end;

   // Alien Fire on Defense
   for i := 0 to high(Defense) do
   begin
     for x := 0 to high(AlienShoot) do
     begin
       y:=AlienShoot[x].pic.Top+AlienShoot[x].pic.Height;
       if (AlienShoot[x].pic.Visible=true) and
          (Defense[i].Visible=true) and
          CollisionDetection(AlienShoot[x].pic.BoundsRect, Defense[i].BoundsRect, 0)
       then
       begin

          AlienShoot[x].pic.Visible:=false;
          HitDefense[i]:=HitDefense[i]+1;
          Defense[i].Picture.Assign(PicExplosion2.Picture);
          if SoundON then BASS_ChannelPlay(strs[Music.Explosion], True);
          if HitDefense[i] >= GameLevel[LevelPos].MaxHitDefense then
          begin
            Defense[i].tag:=1;
          end else
          begin
            Defense[i].tag:=-2;
          end;
       end;
     end;
   end;
   // Destroyed Defense
   for i := 0 to high(Defense) do
   begin
     if ((Defense[i].Visible=true)and(Defense[i].tag > 0)) then
     begin
       if Defense[i].tag = 4 then
       begin
         Defense[i].Picture.Assign(PicExplosion2.Picture);
         Defense[i].tag:=Defense[i].tag+1;
       end else
       if Defense[i].tag >= 10 then
       begin
         Defense[i].Visible:=false;
       end else
       begin
         Defense[i].tag:=Defense[i].tag+1;
       end;
     end else
     if ((Defense[i].Visible=true)and(Defense[i].tag < 0)) then
     begin
       Defense[i].tag:=Defense[i].tag+1;
       if Defense[i].tag = 0 then
          Defense[i].Picture.Assign(PicDefense1.Picture);
     end;
   end;

   // Alien Fire on Gun
   for x := 0 to high(AlienShoot) do
   begin
     if (AlienShoot[x].pic.Visible=true) and
        (GUN.tag=0) and
        CollisionDetection(AlienShoot[x].pic.BoundsRect, GUN.BoundsRect, 0)
     then
     begin
        AlienShoot[x].pic.Visible:=false;
        GameLevel[LevelPos].CountHitGun:=GameLevel[LevelPos].CountHitGun+1;
        GUN.Tag:=-3; // Treffer auf Gun! Kurz ausblenden...
        GUN.Picture.Assign(PicGunHit.Picture);
        if SoundON then BASS_ChannelPlay(strs[Music.Explosion], True);
        if GameLevel[LevelPos].CountHitGun >= GameLevel[LevelPos].MaxHitGun then
        begin
          // Game over!
          TimerGame.enabled:=false;
          Points_Total:=Points_Total-GameLevel[LevelPos].Count_Ammunition;
          TimerGameEnd.Enabled:=true;
          exit;
        end;
     end;
   end;
   Label2.caption:='Lifes left '+inttostr(GameLevel[LevelPos].MaxHitGun-GameLevel[LevelPos].CountHitGun);
   // Hit on Gun? flicker one moment
   if (GUN.tag < 0) then
   begin
     GUN.tag:=GUN.tag+1;
     if GUN.tag=0 then
       GUN.Picture.Assign(PicGun.Picture);
   end;

   // Remove Alien Fire
   for i := high(AlienShoot) downto 0 do
   begin
      if AlienShoot[i].pic.Visible = false then
      begin
        AlienShoot[i].pic.Free;
        Delete(AlienShoot,i,1);
      end;
   end;

   // Check Alien destroyed
    for x := 0 to high(Shoot) do
    begin
      Shoot[x].pic.Top:=Shoot[x].pic.Top-GameLevel[LevelPos].BulletSpeed;
      // Shoot out of Bounds
      if (Shoot[x].pic.Top <= PlayGround.top + 20) then
      begin
        Shoot[x].pic.Visible:=false;
      end;
      if Shoot[x].pic.Visible=true then
      begin
        // Alien hit?
        for i := 0 to high(Aliens) do
        begin
          for y := 0 to high(Aliens[i]) do
          begin
            if (Shoot[x].pic.Visible=true)and(Aliens[i][y].Tag=0) then
            begin
              if CollisionDetection(Shoot[x].pic.BoundsRect, Aliens[i][y].BoundsRect,1)  then
              begin
                if Count_Aliens=1 then
                  z:=z+1;
                if SoundON then BASS_ChannelPlay(strs[Music.Explosion], True);
                Aliens[i][y].Tag:=1;
                Aliens[i][y].Picture.Assign(PicExplosion.Picture);
                Shoot[x].pic.Visible:=false;
                if i=0 then
                  Points_Total:=Points_Total+Points_Alien_1
                else if i=1 then
                  Points_Total:=Points_Total+Points_Alien_2
                else if i=2 then
                  Points_Total:=Points_Total+Points_Alien_3;
              end;
            end;
          end;
        end;
        // Check Alien Mothership hit
        if (Shoot[x].pic.Visible=true) and CollisionDetection(Shoot[x].pic.BoundsRect, AlienMothership.BoundsRect, 1 ) then
        begin
           // Fire on Mothership!
           Shoot[x].pic.Visible:=false;
           inc(GameLevel[LevelPos].AlienMothershipCountHit);
           Points_Total:=Points_Total+1;
           if GameLevel[LevelPos].AlienMothershipCountHit >= GameLevel[LevelPos].AlienMothershipMaxHit then
           begin
             // Mothership destroyed!
             if SoundON then BASS_ChannelStop(strs[Music.UfoLowPitch]);
             if SoundON then BASS_ChannelPlay(strs[Music.Explosion], True);
             AlienMothership.left:=-1*AlienMothership.Picture.Width;
             GameLevel[LevelPos].AlienMothershipStart:=random(200)+200;
             AlienMothership.tag:=0;
             Points_Total:=Points_Total+Points_Alien_Mothership;
             GameLevel[LevelPos].AlienMothershipCountHit:=0;
           end;
        end;
      end;
    end;

  // Remove Player Fire
  for x := high(Shoot) downto 0 do
  begin
     if Shoot[x].pic.Visible=false then
     begin
        Shoot[x].pic.Free;
        Delete(Shoot, x, 1);
     end;
  end;


  if Count_Aliens > 0 then
  begin
    // Animate Alien?
    inc(AlienAnimCount);
    AlienChange:=false;
    if AlienAnimCount >= AlienAnim then
    begin
       AlienChange:=true;
       AlienAnimCount:=0;
       if AlienPicNo = 1 then
       begin
         AlienPicNo:=2;
         if SoundON then BASS_ChannelPlay(strs[Music.InvaderMove1],true);
       end else
       begin
         AlienPicNo:=1;
         if SoundON then BASS_ChannelPlay(strs[Music.InvaderMove2],true);
       end;
    end;

    for i := 0 to GameLevel[LevelPos].Anzahl_Alien_Reihen-1 do
    begin
      for y := 0 to GameLevel[LevelPos].Anzahl_Alien_pro_Reihen-1 do
      begin
        // Animate Alien
        if AlienChange=true then
        begin
           if Aliens[i][y].Visible=true then
           begin
             if i > 2 then x:=2 else x:=i;
             Aliens[i][y].Picture.Assign( (Findcomponent('PicAlien'+inttostr(x+1)+'_'+inttostr(AlienPicNo)) as TImage).Picture);
           end;
        end;

        // Destroy Alien
        if Aliens[i][y].Visible=true then
        begin
          if Aliens[i][y].Tag=1 then
          begin
            Aliens[i][y].Tag:=2;
          end else
          if Aliens[i][y].Tag>=2 then
          begin
            if Aliens[i][y].Tag>=10 then
              Aliens[i][y].Visible:=false
            else
              Aliens[i][y].Tag:=Aliens[i][y].Tag+1;
          end;
        end;
      end;
    end;
  end;


//******************************
//  Player & Alien Bullet-Fire
//******************************
  // Player Fire
  TimerGame.tag:=TimerGame.tag+1;
  if (GameLevel[LevelPos].FireSpeed > 0) then
    Fire:=(GetKeyState(VK_SPACE) < 0)or(GetKeyState(VK_UP) < 0);
  if (
      ((GameLevel[LevelPos].Max_Ammunition<0)or(GameLevel[LevelPos].Count_Ammunition<=GameLevel[LevelPos].Max_Ammunition))and(Fire=true)and
       (TimerGame.tag=GameLevel[LevelPos].FireSpeed)
      )or
      (
       Fire and (GameLevel[LevelPos].FireSpeed < 0)and( (high(Shoot)+1)<(abs(GameLevel[LevelPos].FireSpeed)))
      )
  then
  begin
   inc(GameLevel[LevelPos].Count_Ammunition);
   fire:=false;
   setlength(Shoot,high(Shoot)+2);
   Shoot[high(Shoot)].pic:=TImage.Create(nil);
   Shoot[high(Shoot)].pic.Parent:=Form1;
   Shoot[high(Shoot)].pic.Picture.Assign(PicPlayerBullet.Picture);
   Shoot[high(Shoot)].pic.Width:=PicPlayerBullet.Width;
   Shoot[high(Shoot)].pic.Height:=PicPlayerBullet.Height;
   Shoot[high(Shoot)].pic.Stretch:=true;
   Shoot[high(Shoot)].pic.Proportional:=true;
   Shoot[high(Shoot)].pic.Left:=GUN.Left+trunc((GUN.ClientRect.Right-GUN.ClientRect.Left)/2)-trunc(Shoot[high(Shoot)].pic.Width/2);
   Shoot[high(Shoot)].pic.Top:=GUN.Top-Shoot[high(Shoot)].pic.Picture.Height;
   if SoundON then BASS_ChannelPlay(strs[Music.Shoot], True);
  end;
  if (GameLevel[LevelPos].Max_Ammunition<0) then
    Label3.caption:='Shoots '+inttostr(GameLevel[LevelPos].Count_Ammunition)
  else
    Label3.caption:='Shoots '+inttostr(GameLevel[LevelPos].Count_Ammunition)+'/'+inttostr(GameLevel[LevelPos].Max_Ammunition);
  if ((GameLevel[LevelPos].Max_Ammunition>0)and(GameLevel[LevelPos].Count_Ammunition>=GameLevel[LevelPos].Max_Ammunition)) then
  begin
   // out of Ammunition, Game over!
    TimerGame.enabled:=false;
    Points_Total:=Points_Total-GameLevel[LevelPos].Count_Ammunition;
    TimerGameEnd.Enabled:=true;
    exit;
  end;
  // Set Autofire Pause (speed)
  if TimerGame.tag >= GameLevel[LevelPos].FireSpeed then
   TimerGame.tag:=0;

  // Recalculate after Fire processing... anything left to destroy? :-)
  Count_Aliens:=0;
  for y := 0 to high(Aliens) do
    for x := 0 to high(Aliens[y]) do
      if Aliens[y][x].Visible=true then
        inc(Count_Aliens);

  // Alien Fire
   GameLevel[LevelPos].AlienFireCount:=GameLevel[LevelPos].AlienFireCount+1;
   if ( Count_Aliens > 0)and(GameLevel[LevelPos].AlienFireCount >= GameLevel[LevelPos].AlienFire) then
   begin
     GameLevel[LevelPos].AlienFireCount:=0;
     GameLevel[LevelPos].AlienFire:=Random(80)+10;
     i:=Random(GameLevel[LevelPos].Anzahl_Alien_Reihen*GameLevel[LevelPos].Anzahl_Alien_pro_Reihen);
     x:=trunc(i/(GameLevel[LevelPos].Anzahl_Alien_pro_Reihen));
     y:=i mod GameLevel[LevelPos].Anzahl_Alien_pro_Reihen;
     while Aliens[x][y].Visible=false do
     begin
       i:=Random(GameLevel[LevelPos].Anzahl_Alien_Reihen*GameLevel[LevelPos].Anzahl_Alien_pro_Reihen);
       x:=trunc(i/(GameLevel[LevelPos].Anzahl_Alien_pro_Reihen));
       y:=i mod GameLevel[LevelPos].Anzahl_Alien_pro_Reihen;
     end;
     setlength(AlienShoot,high(AlienShoot)+2);
     AlienShoot[high(AlienShoot)].pic:=TImage.Create(nil);
     AlienShoot[high(AlienShoot)].pic.Parent:=Form1;
     AlienShoot[high(AlienShoot)].pic.Picture.Assign(PicAlienBullet2.Picture);
     if GameLevel[LevelPos].AlienFireSideways = true then
     begin
       AlienShoot[high(AlienShoot)].sidewaysDirection:=random(6);// 0=links 1-4=gerade 5=rechts
       AlienShoot[high(AlienShoot)].sidewaysAngle:=1+random(3);
     end;
     AlienShoot[high(AlienShoot)].pic.Width:=PicAlienBullet1.Width;
     AlienShoot[high(AlienShoot)].pic.Height:=PicAlienBullet1.Height;
     AlienShoot[high(AlienShoot)].pic.Stretch:=true;
     AlienShoot[high(AlienShoot)].pic.Proportional:=true;
     AlienShoot[high(AlienShoot)].pic.Left:=Aliens[x][y].Left+trunc(Aliens[x][y].Width/2);
     AlienShoot[high(AlienShoot)].pic.Top:=Aliens[x][y].Top+Aliens[x][y].Height;
     AlienShoot[high(AlienShoot)].pic.Invalidate;
   end;

   for x := 0 to high(AlienShoot) do
   begin
     AlienShoot[x].pic.Top:=AlienShoot[x].pic.Top + 5;
     if GameLevel[LevelPos].AlienFireSideways = true then
     begin
       if AlienShoot[x].sidewaysDirection=0 then
       begin
         AlienShoot[x].pic.Left:=AlienShoot[x].pic.Left-AlienShoot[x].sidewaysAngle;
       end else
       if AlienShoot[x].sidewaysDirection=5 then
       begin
         AlienShoot[x].pic.Left:=AlienShoot[x].pic.Left+AlienShoot[x].sidewaysAngle;
       end;
     end;

     if AlienShoot[x].pic.Top < 10 then
        AlienShoot[x].pic.Visible:=false;
     if AlienShoot[x].pic.Left < PlayGround.Left then
        AlienShoot[x].pic.Visible:=false;
     if (AlienShoot[x].pic.Left+AlienShoot[x].pic.Width) > (PlayGround.Left+PlayGround.Width) then
        AlienShoot[x].pic.Visible:=false;
   end;


end;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
var
  x, y:integer;
begin
  TimerGame.Enabled:=false;
  BASS_Stop;
  RemoveItems;
  GUN.Free;
  AlienMothership.Free;
end;

end.

