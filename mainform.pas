unit MainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls, ComCtrls, JSONPropStorage, Spin, ValEdit,
  tgtypes, SynEdit, tgsendertypes
  ;

type

  { TFrmMain }

  TFrmMain = class(TForm)
    BtnSendRequest: TButton;
    EdtToken: TLabeledEdit;
    JSONPrpStrg: TJSONPropStorage;
    EdtWebhookUrl: TLabeledEdit;
    EdtBotUsername: TLabeledEdit;
    Label1: TLabel;
    MmResponse: TMemo;
    PgCntrl: TPageControl;
    EdtOffset: TSpinEdit;
    TbShtSetMyCommands: TTabSheet;
    TbShtGetMyCommands: TTabSheet;
    TbShtGetUpdates: TTabSheet;
    TbShtSetWebhook: TTabSheet;
    TbShtGetWebhookInfo: TTabSheet;
    TbShtGetMe: TTabSheet;
    VlLstEdtrCommands: TValueListEditor;
    procedure BtnSendRequestClick({%H-}Sender: TObject);
    procedure SetMyCommands(aBot: TTelegramSender);
  private

  public

  end;

var
  FrmMain: TFrmMain;

implementation

{$R *.lfm}

uses
  jsonparser, jsonscanner, fpjson
  ;

function BeautifyJSONString(const aSource: String): String;
var
  aParser: TJSONParser;
  aJSONData: TJSONData;
begin
  aParser:=TJSONParser.Create(aSource, [joUTF8]);
  try
    aJSONData:=aParser.Parse;
    try
    Result := aJSONData.FormatJSON([], 2);
    finally 
      aJSONData.Free;
    end;
  finally
    aParser.Free;
  end;
end;

{ TFrmMain }

procedure TFrmMain.BtnSendRequestClick(Sender: TObject);
var
  aToken: String;
  aBot: TTelegramSender;
  aWebHookInfo: TTelegramWebhookInfo;
begin
  aToken:=EdtToken.Text;
  aBot:=TTelegramSender.Create(aToken);
  try
    try
      if PgCntrl.ActivePage=TbShtGetMe then
      begin
        aBot.getMe;
        EdtBotUsername.Text:=aBot.BotUsername;
        Exit;
      end;
      if PgCntrl.ActivePage=TbShtGetWebhookInfo then
      begin
        aBot.getWebhookInfo(aWebHookInfo);
        aWebHookInfo.Free;
        Exit;
      end;
      if PgCntrl.ActivePage=TbShtSetWebhook then
      begin
        aBot.setWebhook(EdtWebhookUrl.Text);
        Exit;
      end;
      if PgCntrl.ActivePage=TbShtGetUpdates then
      begin
        aBot.getUpdates(EdtOffset.Value);
        Exit;
      end;
      if PgCntrl.ActivePage=TbShtGetMyCommands then
      begin
        aBot.getMyCommands;
        Exit;
      end;
      if PgCntrl.ActivePage=TbShtSetMyCommands then
      begin
        SetMyCommands(aBot);
        Exit;
      end;
    finally
      MmResponse.Lines.Text:=BeautifyJSONString(aBot.Response);
    end;
  finally
    aBot.Free;
  end;
end;

procedure TFrmMain.SetMyCommands(aBot: TTelegramSender);
var
  aBotCommands: TBotCommandArray;
  i: Integer;
begin
  aBotCommands:=TBotCommandArray.Create();
  try
    for i:=1 to VlLstEdtrCommands.Strings.Count do
      with VlLstEdtrCommands do
        aBotCommands.AddCommand(Keys[i], Values[Keys[i]]);
    aBot.setMyCommands(aBotCommands);
  finally
    aBotCommands.Free;
  end;
end;

end.

