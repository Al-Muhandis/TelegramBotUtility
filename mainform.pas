unit MainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls, ComCtrls, JSONPropStorage, Spin, ValEdit,
  tgtypes, SynEdit, SpinEx, tgsendertypes
  ;

type

  { TFrmMain }

  TFrmMain = class(TForm)
    BtnSendRequest: TButton;
    BtnClear: TButton;
    CmbBxCommandScope: TComboBox;
    EdtSpecificUserID: TSpinEditEx;
    EdtToken: TLabeledEdit;
    JSONPrpStrg: TJSONPropStorage;
    EdtWebhookUrl: TLabeledEdit;
    EdtBotUsername: TLabeledEdit;
    Label1: TLabel;
    MmResponse: TMemo;
    PgCntrl: TPageControl;
    EdtOffset: TSpinEdit;
    EdtSpecificChatID: TSpinEditEx;
    TbShtSetMyCommands: TTabSheet;
    TbShtGetMyCommands: TTabSheet;
    TbShtGetUpdates: TTabSheet;
    TbShtSetWebhook: TTabSheet;
    TbShtGetWebhookInfo: TTabSheet;
    TbShtGetMe: TTabSheet;
    TlBrsetMyCommands: TToolBar;
    VlLstEdtrCommands: TValueListEditor;
    procedure BtnClearClick(Sender: TObject);
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

procedure TFrmMain.BtnClearClick(Sender: TObject);
begin
  VlLstEdtrCommands.Clear;
end;

procedure TFrmMain.SetMyCommands(aBot: TTelegramSender);
var
  aBotCommands: TBotCommandArray;
  i, aIndex: Integer;
  aScope: TBotCommandScope;
begin
  aBotCommands:=TBotCommandArray.Create();
  aScope:=TBotCommandScope.Create;
  try
    for i:=1 to VlLstEdtrCommands.Strings.Count do
      with VlLstEdtrCommands do
        aBotCommands.AddCommand(Keys[i], Values[Keys[i]]);
    aIndex:=CmbBxCommandScope.ItemIndex;
    if CmbBxCommandScope.ItemIndex=-1 then
      aIndex:=0;
    aScope.ScopeType:=TCommandScopeType(aIndex);
    if aScope.ScopeType>=stSpecificChat then
      aScope.ChatID:=EdtSpecificChatID.Value;
    if aScope.ScopeType=stChatMember then
      aScope.UserID:=EdtSpecificUserID.Value;
    aBot.setMyCommands(aBotCommands, aScope);
  finally
    aScope.Free;
    aBotCommands.Free;
  end;
end;

end.

