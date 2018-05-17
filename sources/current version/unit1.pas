unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Menus, ComCtrls,
  inifiles,
  fpjson, jsonparser,
  simpleinternet,
  internetaccess;  // Documentation: http://www.benibela.de/documentation/internettools/

type
  TPooData = record
    hash: Double;
    paid: Double;
    due: Double;
  end;

  TQuery = class(TThread)
  protected
    procedure Execute; override;
  end;

  { TForm1 }
  TForm1 = class(TForm)
    ComboBoxCurrency: TComboBox;
    EditWallet: TEdit;
    Image1: TImage;
    Label1: TLabel;
    Label10: TLabel;
    Label11: TLabel;
    Label12: TLabel;
    Label13: TLabel;
    Label14: TLabel;
    Label15: TLabel;
    Label16: TLabel;
    Label17: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    MenuItem1: TMenuItem;
    MenuItemExit: TMenuItem;
    MenuItemHide: TMenuItem;
    MenuItemShow: TMenuItem;
    Panel1: TPanel;
    PopupMenu1: TPopupMenu;
    ProgressBar1: TProgressBar;
    TimerAfterLoad: TTimer;
    TrayIcon1: TTrayIcon;
    procedure ComboBoxCurrencySelect(Sender: TObject);
    procedure ConfigLoad;
    procedure ConfigSave;
    procedure Button3Click(Sender: TObject);
    procedure EditWalletChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    function getPool():TPooData;
    function getPrice():Double;
    function getPriceFromHulacoins():Double;
    function getPriceFromBittrex():Double;     
    function getPriceFromInvesting():Double;
    function getTextBetween(content, searchStart, searchEnd: String):String;
    procedure MenuItemExitClick(Sender: TObject);
    procedure MenuItemHideClick(Sender: TObject);
    procedure MenuItemShowClick(Sender: TObject);
    procedure TimerAfterLoadTimer(Sender: TObject);
  private

  public

  end;

var
  Form1: TForm1;
  price: Double = -1;
  isApplicationLoading: Boolean = True;
  countRefresh: Integer = 0;
  TimeWaiting: Integer = 20000;
implementation

{$R *.lfm}

{ TForm1 }



function TForm1.getTextBetween(content, searchStart, searchEnd: String):String;
var
  i: Integer;
begin
  i := content.IndexOf(searchStart) + Length(searchStart) + 1;
  result := Copy(content, i);
  result := Copy(result, 1, Pos(searchEnd, result) - 1);
end;

procedure TForm1.MenuItemExitClick(Sender: TObject);
begin
  Application.Terminate;
end;

procedure TForm1.MenuItemHideClick(Sender: TObject);
begin
  Application.ShowMainForm:=False;
  Hide;
end;

procedure TForm1.MenuItemShowClick(Sender: TObject);
begin
  if Application.ShowMainForm then Exit;
  Application.ShowMainForm:=True;
  Show;
end;



procedure TForm1.EditWalletChange(Sender: TObject);
begin
  ConfigSave;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin   
  TimerAfterLoad.Enabled:=True;
end;
     
procedure TForm1.TimerAfterLoadTimer(Sender: TObject);
begin
  TTimer(Sender).Enabled := False;

  ComboBoxCurrency.SetFocus;
  Label15.Caption:=PChar('Loading...');
  EditWallet.Clear;
  Form1.ComboBoxCurrency.ItemIndex:=0;
  ConfigLoad;
  isApplicationLoading := False;
  Unit1.TQuery.Create(False);

end;



procedure TForm1.ConfigLoad;
var  Setup: TIniFile;
begin
  Setup := TIniFile.Create(ExtractFileDir(Application.ExeName) + '\Setup.ini');
  EditWallet.Text := Setup.ReadString('Setup', 'Wallet', '');
  ComboBoxCurrency.ItemIndex := Setup.ReadInteger('Setup', 'Currency', 0);
  Setup.Free;
end;

procedure TForm1.ComboBoxCurrencySelect(Sender: TObject);
begin
  if isApplicationLoading then Exit;
  price := -1;
  ConfigSave;
  Label14.Caption := PChar('Waiting next refresh...');
end;

procedure TForm1.ConfigSave;
var
  Setup: TIniFile;
begin
  if isApplicationLoading then Exit;
  Setup := TIniFile.Create(ExtractFileDir(Application.ExeName) + '\Setup.ini');
  Setup.WriteString('Setup', 'Wallet', EditWallet.Text);
  Setup.WriteInteger('Setup', 'Currency', ComboBoxCurrency.ItemIndex);
  Setup.Free;
  Label15.Caption:=PChar('Modification saved');
end;




procedure TQuery.Execute;
begin

  while True do
  begin
    Form1.Button3Click(nil);
    TimeWaiting := 20000;
    Form1.ProgressBar1.Max:=TimeWaiting;
    while TimeWaiting > 0 do
    begin
      Form1.Label15.Caption:=PChar('Refresh in '+IntToStr(TimeWaiting div 1000)+'s');
      Sleep(1000);
      TimeWaiting := TimeWaiting - 1000;
      Form1.ProgressBar1.Position:=Form1.ProgressBar1.Max - TimeWaiting;
    end;
  end;
end;


procedure TForm1.Button3Click(Sender: TObject);
var
  poolData: TPooData;
  currency: String;
begin

  if not Application.ShowMainForm then Exit;
  Inc(countRefresh);
  if EditWallet.Text = '' then Exit;
  Label15.Caption:=PChar('Refreshing...');
  poolData := getPool();                  

  Label3.Caption:= PChar(Double.ToString(poolData.hash)+' H/s');
  //Label4.Caption:= PChar(Double.ToString(poolData.due)+' XMR');
  //Label7.Caption:= PChar(Double.ToString(poolData.paid)+' XMR');
  currency := getTextBetween(ComboBoxCurrency.Text, '[', ']');
  if (price = -1) or (countRefresh > 9) then
  begin
    price := getPrice();
    countRefresh := 0;
  end;
  if price = -1 then Exit;
  Label14.Caption:= PChar(Double.ToString(price)+' '+currency);
  Label10.Caption:= PChar(Double.ToString(price*poolData.due)+' '+currency);
  Label11.Caption:= PChar(Double.ToString(price*poolData.paid)+' '+currency);
  Label15.Caption:=PChar('');
  FreeMemAndNil(poolData);
end;



function TForm1.getPool():TPooData;
var
  url, json_string: String;
  jData : TJSONData;
  jObject : TJSONObject;
  v: Double;
begin
  result.hash:=0;
  result.due:=0;
  result.paid:=0;
  url := 'https://api.moneroocean.stream/miner/'+EditWallet.Text+'/stats';
  try
    json_string :=  internetaccess.httpRequest(url);
  except
    On E : EInternetException do exit;
  end;

  internetaccess.freeThreadVars;
  jData := GetJSON(json_string);
  jObject := TJSONObject(jData);
  v := 0;
  Double.TryParse(jObject.Get('amtDue'), v);
  result.due:= v /1000000000000;
  v := 0;
  Double.TryParse(jObject.Get('hash'), v);
  result.hash:= v;
  v := 0;
  Double.TryParse(jObject.Get('amtPaid'), v);
  result.paid:= v /1000000000000;
  json_string := '';
end;

function TForm1.getPrice():Double;
var
  currency: String;
begin
  result := 0;
  currency := getTextBetween(ComboBoxCurrency.Text, '[', ']');
  if (currency = 'USD')
  or (currency = 'EURO')
  or (currency = 'CAD')
  or (currency = 'CHF')
  or (currency = 'CNY')
  or (currency = 'GBP')
  or (currency = 'JPY') then
    result := getPriceFromHulacoins();
  if (currency = 'BTC')
  or (currency = 'ETH') then
    result := getPriceFromBittrex();
  if (currency = 'LTC')
  or (currency = 'KRW')
  or (currency = 'SEK')
  or (currency = 'ILS')
  or (currency = 'SAR')
  or (currency = 'TRY')
  or (currency = 'INR')
  or (currency = 'MXN')
  or (currency = 'PLN')
  or (currency = 'CNY')
  or (currency = 'HKD')
  or (currency = 'AUD')
  or (currency = 'MYR')
  or (currency = 'VND')
  or (currency = 'RUB')
  or (currency = 'ZAR')
  or (currency = 'DOGE') then
    result := getPriceFromInvesting();
  if (currency = 'XMR') then
    result := 1;
end;


function TForm1.getPriceFromInvesting():Double;
var
  url, res, currency: String;
  i: Integer;
begin
  Label15.Caption:=PChar('Get price from investing.com');
  currency := getTextBetween(ComboBoxCurrency.Text, '[', ']');
  url := 'https://www.investing.com/crypto/monero/xmr-'+LowerCase(currency);
  res :=  internetaccess.httpRequest(url);
  res := getTextBetween(res, '<input type="text" class="newInput inputTextBox alertValue" placeholder="', '"');
  res := res.Replace(',','');
  result := -1;
  Double.TryParse(res, result);
  res := '';
end;

function TForm1.getPriceFromHulacoins():Double;
var
  url, res, currency: String;
  i: Integer;
begin                                      
  Label15.Caption:=PChar('Get price from hulacoins.com');
  currency := getTextBetween(ComboBoxCurrency.Text, '[', ']');
  url := 'https://www.hulacoins.com/monero/xmr-to-'+LowerCase(currency)+'/c-8';
  res :=  internetaccess.httpRequest(url);
  res := getTextBetween(res, '<span itemprop="price" content="', '"');
  result := -1;
  Double.TryParse(res, result);
  res := '';
end;

function TForm1.getPriceFromBittrex():Double;
var
  url, res, currency: String;
  i: Integer;
begin                                             
  Label15.Caption:=PChar('Get price from bittrex.com');
  currency := getTextBetween(ComboBoxCurrency.Text, '[', ']');
  url := 'https://bittrex.com/Api/v2.0/pub/market/GetLatestTick?marketName='+currency+'-XMR&tickInterval=fiveMin';
  res :=  internetaccess.httpRequest(url);
  res := getTextBetween(res, '"L":', ',');
  result := -1;
  Double.TryParse(res, result);
  res := '';
end;

end.

