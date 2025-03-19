unit MainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, ExtCtrls, StdCtrls, ComCtrls, JSONPropStorage, Spin, ValEdit,
  EditBtn, tgtypes, SpinEx, tgsendertypes
  ;

type

  { TFrmMain }

  TFrmMain = class(TForm)
    BtnSendRequest: TButton;
    BtnClear: TButton;
    ChckGrpAllowedUpdates: TCheckGroup;
    CmbBxCommandScope: TComboBox;
    CmbbxMarkdown: TComboBox;
    EdtSpecificUserID: TSpinEditEx;
    EdtToken: TLabeledEdit;
    FlNmEdtDocument: TFileNameEdit;
    GrpBx: TGroupBox;
    JSONPrpStrg: TJSONPropStorage;
    EdtWebhookUrl: TLabeledEdit;
    EdtBotUsername: TLabeledEdit;
    Label1: TLabel;
    LblSendParseMode: TLabel;
    LblReceiverChatID: TLabel;
    MmMessage: TMemo;
    MmResponse: TMemo;
    PgCntrlSend: TPageControl;
    PgCntrl: TPageControl;
    EdtOffset: TSpinEdit;
    EdtSpecificChatID: TSpinEditEx;
    EdtReceiverChatID: TSpinEditEx;
    Spltr: TSplitter;
    TbCntrlWebhook: TTabControl;
    TbShtSendDocument: TTabSheet;
    TbShtSendMessage: TTabSheet;
    TbShtSend: TTabSheet;
    TbCntrlMyCommands: TTabControl;
    TbShtMyCommands: TTabSheet;
    TbShtGetUpdates: TTabSheet;
    TbShtWebhook: TTabSheet;
    TbShtGetMe: TTabSheet;
    TlBrsetMyCommands: TToolBar;
    VlLstEdtrCommands: TValueListEditor;
    procedure BtnClearClick({%H-}Sender: TObject);
    procedure BtnSendRequestClick({%H-}Sender: TObject);
    procedure ExtractScopeFromControls(aScope: TBotCommandScope);
    procedure FormCreate({%H-}Sender: TObject);
    procedure GetMyCommands(aBot: TTelegramSender);
    procedure GetWebhookInfo(aBot: TTelegramSender);
    procedure SetMyCommands(aBot: TTelegramSender);
  private
    function GetAllowedUpdates: TUpdateSet;
    procedure SetAllowedUpdates(AValue: TUpdateSet);
  protected
    property AllowedUpdates: TUpdateSet read GetAllowedUpdates write SetAllowedUpdates;
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
  aWebHookInfo: TTelegramWebhookInfo;
  aParseMode: TParseMode;
  aBot: TTelegramSender;
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
      if PgCntrl.ActivePage=TbShtWebhook then
      begin
        if TbCntrlWebhook.TabIndex=1 then
          aBot.setWebhook(EdtWebhookUrl.Text, 0, AllowedUpdates)
        else
          GetWebhookInfo(aBot);
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
      if PgCntrl.ActivePage=TbShtSend then
      begin
        if PgCntrlSend.ActivePage=TbShtSendMessage then
        begin
          aParseMode:=TParseMode(CmbbxMarkdown.ItemIndex);
          aBot.sendMessage(EdtReceiverChatID.Value, MmMessage.Text, aParseMode);
          Exit;
        end;
        if PgCntrlSend.ActivePage=TbShtSendDocument then
        begin
          aBot.sendDocumentByFileName(EdtReceiverChatID.Value, FlNmEdtDocument.FileName, MmMessage.Text);
          Exit;
        end;
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

procedure TFrmMain.FormCreate(Sender: TObject);
var
  i: TUpdateType;
begin
  for i in TUpdateType do
    ChckGrpAllowedUpdates.Items.Add(UpdateTypeAliases[i]);
end;

procedure TFrmMain.GetMyCommands(aBot: TTelegramSender);
var
  aScope: TBotCommandScope;
  aCommandEnum: TJSONEnum;
begin
  aScope:=TBotCommandScope.Create;
  try
    ExtractScopeFromControls(aScope);
    if aBot.getMyCommands(aScope) then
    begin
      VlLstEdtrCommands.Clear;
      for aCommandEnum in (aBot.JSONResponse as TJSONArray) do
        with (aCommandEnum.Value as TJSONObject) do
          VlLstEdtrCommands.InsertRow(Strings['command'], Strings['description'], True);
    end;
  finally
    aScope.Free;
  end;
end;

procedure TFrmMain.GetWebhookInfo(aBot: TTelegramSender);
var
  aWebHookInfo: TTelegramWebhookInfo;
begin
  if aBot.getWebhookInfo(aWebHookInfo) then
  begin
    try
      EdtWebhookUrl.Text:=aWebHookInfo.Url;
      AllowedUpdates:=aWebHookInfo.AllowedUpdates;
    finally
      aWebHookInfo.Free;
    end;
  end;
end;

procedure TFrmMain.BtnClearClick(Sender: TObject);
begin
  VlLstEdtrCommands.Clear;
end;

procedure TFrmMain.SetMyCommands(aBot: TTelegramSender);
var
  FBotCommands: TBotCommandArray;
  i: Integer;
  aScope: TBotCommandScope;
begin
  FBotCommands:=TBotCommandArray.Create();
  aScope:=TBotCommandScope.Create;
  try
    for i:=1 to VlLstEdtrCommands.Strings.Count do
      with VlLstEdtrCommands do
        FBotCommands.AddCommand(Keys[i], Values[Keys[i]]);
    ExtractScopeFromControls(aScope);
    aBot.setMyCommands(FBotCommands, aScope);
  finally
    aScope.Free;
    FBotCommands.Free;
  end;
end;

function TFrmMain.GetAllowedUpdates: TUpdateSet;
var
  i: TUpdateType;
begin
  Result:=[];
  for i in TUpdateType do
    if ChckGrpAllowedUpdates.Checked[Ord(i)] then
      Include(Result, i);
end;

procedure TFrmMain.SetAllowedUpdates(AValue: TUpdateSet);
var
  i: TUpdateType;
begin
  for i in TUpdateType do
    ChckGrpAllowedUpdates.Checked[Ord(i)]:=i in AValue;
end;

end.

