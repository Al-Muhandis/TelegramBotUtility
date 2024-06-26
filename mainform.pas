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
    GrpBx: TGroupBox;
    JSONPrpStrg: TJSONPropStorage;
    EdtWebhookUrl: TLabeledEdit;
    EdtBotUsername: TLabeledEdit;
    Label1: TLabel;
    LblReceiverChatID: TLabel;
    MmMessage: TMemo;
    MmResponse: TMemo;
    PgCntrl: TPageControl;
    EdtOffset: TSpinEdit;
    EdtSpecificChatID: TSpinEditEx;
    EdtReceiverChatID: TSpinEditEx;
    Spltr: TSplitter;
    TbShtSendMessage: TTabSheet;
    TbCntrlMyCommands: TTabControl;
    TbShtMyCommands: TTabSheet;
    TbShtGetUpdates: TTabSheet;
    TbShtSetWebhook: TTabSheet;
    TbShtGetWebhookInfo: TTabSheet;
    TbShtGetMe: TTabSheet;
    TlBrsetMyCommands: TToolBar;
    VlLstEdtrCommands: TValueListEditor;
    procedure BtnClearClick({%H-}Sender: TObject);
    procedure BtnSendRequestClick({%H-}Sender: TObject);
    procedure ExtractScopeFromControls(aScope: TBotCommandScope);
    procedure GetMyCommands(aBot: TTelegramSender);
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
      if PgCntrl.ActivePage=TbShtMyCommands then
      begin
        if TbCntrlMyCommands.TabIndex=1 then
          SetMyCommands(aBot)
        else
          GetMyCommands(aBot);
        Exit;
      end;
      if PgCntrl.ActivePage=TbShtSendMessage then
      begin
        aBot.sendMessage(EdtReceiverChatID.Value, MmMessage.Text);
        Exit;
      end;
    finally
      MmResponse.Lines.Text:=BeautifyJSONString(aBot.Response);
    end;
  finally
    aBot.Free;
  end;
end;

procedure TFrmMain.ExtractScopeFromControls(aScope: TBotCommandScope);
var
  aIndex: Integer;
begin
  aIndex:=CmbBxCommandScope.ItemIndex;
  if aIndex=-1 then
    aIndex:=0;
  aScope.ScopeType:=TCommandScopeType(aIndex);
  if aScope.ScopeType>=stSpecificChat then
    aScope.ChatID:=EdtSpecificChatID.Value;
  if aScope.ScopeType=stChatMember then
    aScope.UserID:=EdtSpecificUserID.Value;
end;

procedure TFrmMain.GetMyCommands(aBot: TTelegramSender);
var
  aScope: TBotCommandScope;
begin
  aScope:=TBotCommandScope.Create;
  try
    ExtractScopeFromControls(aScope);
    aBot.getMyCommands(aScope);
  finally
    aScope.Free;
  end;
end;

procedure TFrmMain.BtnClearClick(Sender: TObject);
begin
  VlLstEdtrCommands.Clear;
end;

procedure TFrmMain.SetMyCommands(aBot: TTelegramSender);
var
  aBotCommands: TBotCommandArray;
  i: Integer;
  aScope: TBotCommandScope;
begin
  aBotCommands:=TBotCommandArray.Create();
  aScope:=TBotCommandScope.Create;
  try
    for i:=1 to VlLstEdtrCommands.Strings.Count do
      with VlLstEdtrCommands do
        aBotCommands.AddCommand(Keys[i], Values[Keys[i]]);
    ExtractScopeFromControls(aScope);
    aBot.setMyCommands(aBotCommands, aScope);
  finally
    aScope.Free;
    aBotCommands.Free;
  end;
end;

end.

