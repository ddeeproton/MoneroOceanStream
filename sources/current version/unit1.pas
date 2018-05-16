unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Menus,
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
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    MenuItem1: TMenuItem;
    MenuItemExit: TMenuItem;
    MenuItemHide: TMenuItem;
    MenuItemShow: TMenuItem;
    PopupMenu1: TPopupMenu;
    Timer1: TTimer;
    TimerAfterLoad: TTimer;
    TrayIcon1: TTrayIcon;
    procedure ConfigLoad;
    procedure ConfigSave;
    procedure Button3Click(Sender: TObject);
    procedure ComboBoxCurrencyChange(Sender: TObject);
    procedure EditWalletChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    function getPool():TPooData;
    function getPrice():Double;
    procedure MenuItemExitClick(Sender: TObject);
    procedure MenuItemHideClick(Sender: TObject);
    procedure MenuItemShowClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure TimerAfterLoadTimer(Sender: TObject);
  private

  public

  end;

var
  Form1: TForm1;
  price: Double = -1;
  isApplicationLoading: Boolean = True;
  countRefresh: Integer = 0;
implementation

{$R *.lfm}

{ TForm1 }

function TForm1.getPrice():Double;
var
  url, res, splitchar: String;
  i: Integer;
begin
  //https://www.hulacoins.com/monero/xmr-to-euro/c-8
  url := 'https://www.hulacoins.com/monero/xmr-to-'+LowerCase(ComboBoxCurrency.Text)+'/c-8';
  res :=  internetaccess.httpRequest(url);
  splitchar := '<span itemprop="price" content="';
  i := res.IndexOf(splitchar) + Length(splitchar) + 1;
  res := Copy(res, i);
  res := Copy(res, 1, Pos('"', res) - 1);
  result := -1;
  Double.TryParse(res, result);
end;

procedure TForm1.MenuItemExitClick(Sender: TObject);
begin
  Application.Terminate;
end;

procedure TForm1.MenuItemHideClick(Sender: TObject);
begin
  Application.ShowMainForm:=False;
  Hide;
  Timer1.Enabled:=False;
end;

procedure TForm1.MenuItemShowClick(Sender: TObject);
begin
  if Application.ShowMainForm then Exit;
  Application.ShowMainForm:=True;
  Show;
  Unit1.TQuery.Create(False);
  Timer1.Enabled:=True;
end;



function TForm1.getPool():TPooData;
var
  url, json_string: String;
  jData : TJSONData;
  jObject : TJSONObject;
  v: Double;
begin
  url := 'https://api.moneroocean.stream/miner/'+EditWallet.Text+'/stats';
  json_string :=  internetaccess.httpRequest(url);
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
end;

procedure TForm1.Button3Click(Sender: TObject);
var
  poolData: TPooData;
  currency: String;
begin
  Inc(countRefresh);
  if EditWallet.Text = '' then Exit;    
  Label15.Caption:=PChar('Refreshing...');
  poolData := getPool();
  Label3.Caption:= PChar(Double.ToString(poolData.hash)+' H/s');
  Label4.Caption:= PChar(Double.ToString(poolData.due)+' XMR');
  Label7.Caption:= PChar(Double.ToString(poolData.paid)+' XMR');
  currency:=ComboBoxCurrency.Text;
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
end;

procedure TForm1.ComboBoxCurrencyChange(Sender: TObject);
begin
  price := -1;
  ConfigSave;
end;

procedure TForm1.EditWalletChange(Sender: TObject);
begin
  ConfigSave;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Label15.Caption:=PChar('Loading...');
  EditWallet.Clear;
  Form1.ComboBoxCurrency.ItemIndex:=0;
  ConfigLoad;
  isApplicationLoading := False;
  Unit1.TQuery.Create(False);
  Timer1.Enabled:=True;
  TimerAfterLoad.Enabled:=True;
end;

procedure TForm1.ConfigLoad;
var  Setup: TIniFile;
begin
  Setup := TIniFile.Create(ExtractFileDir(Application.ExeName) + '\Setup.ini');
  EditWallet.Text := Setup.ReadString('Setup', 'Wallet', '');
  ComboBoxCurrency.ItemIndex := Setup.ReadInteger('Setup', 'Currency', 0);
  Setup.Free;
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

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  Unit1.TQuery.Create(False);
end;

procedure TForm1.TimerAfterLoadTimer(Sender: TObject);
begin
  TTimer(Sender).Enabled := False;
  ComboBoxCurrency.SetFocus;
end;

procedure TQuery.Execute;
begin
  Form1.Button3Click(nil);
end;

end.

