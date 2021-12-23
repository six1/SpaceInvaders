unit uInputQueryPos;

{$mode objfpc}{$H+}

interface

uses
  Forms, Controls, Dialogs, StdCtrls, ButtonPanel, ExtCtrls;

type

  { TBoxForm }

  TBoxForm = class(TForm)
    ButtonPanel: TButtonPanel;
    EInput: TEdit;
    Image1: TImage;
    LPrompt: TLabel;
  end;

  function InputBoxPos(const aCaption, aPrompt, aDefaultInput: string; X, Y: integer): string;

implementation

function InputBoxPos(const aCaption, aPrompt, aDefaultInput: string; X, Y: integer): string;
var
  boxForm: TBoxForm;
begin
  boxForm:=TBoxForm.Create(nil);
  try
    Result:=aDefaultInput;
    boxForm.Caption:=aCaption;
    boxForm.BorderStyle:=bsDialog;
    boxForm.Position:=poDefaultSizeOnly;
    boxForm.Top:=Y;
    boxForm.Left:=X;
    boxForm.LPrompt.Caption:=aPrompt;
    boxForm.EInput.Text:=aDefaultInput;
    if (boxForm.ShowModal = mrOK) and (boxForm.EInput.Text <> '') then
      Result:=boxForm.EInput.Text;
  finally
    boxForm.Free;
  end;
end;

{$R *.lfm}

end.
