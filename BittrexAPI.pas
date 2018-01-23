unit BittrexAPI;

interface

uses
  Classes, System.generics.collections,
  REST.Client;

type
  TTicker = class(TObject)
  public
    datetime: TDateTime;
    Bid, Ask, Last, Ant: double;
  end;

  TOrderHistory = record
    OrderUuid: string;
    Exchange: string;
    TimeStamp: TDateTime;
    OrderType: string;
    Limit: double;
    Quantity: double;
    QuantityRemaining: double;
    Commision: double;
    Price: double;
    PricePerUnit: double;
    Cost: double;
    IsConditional: boolean;
    Condition: string;
    ConditionTarget: string;
    InmediateOrCancel: boolean;
  end;

  TOrdersHistory = class(Tlist<TOrderHistory>)
  public
    // procedure Exchanges(const aExchanges: TStringList);
    // function GetProfit(const aMarket: string): double;
    // function GetLastOrderCost(const aMarket: string): double;
  end;

  TBalance = record
    Currency: string;
    Balance: double;
    Available: double;
    Pending: double;
    CryptoAddress: string;
    Requested: boolean;
  end;

  TBalances = class(Tlist<TBalance>)
  public
    function Balance(const aCurrency: string): TBalance;
  end;

  TMarket = class(TObject)
  private
    fTicker: TTicker;
    function GetLastValue: double;
    function GetBump: double;
    function GetAsk: double;
    function GetBid: double;
    function GetAntValue: double;
    function GetTimer: TDateTime;
  public
    MarketCurrency: string;
    BaseCurrency: string;
    MarketCurrencyLong: string;
    BaseCurrencyLong: string;
    MinTradeSize: string; // cambiar;
    MarketName: string;
    IsActive: boolean;
    Created: TDateTime;
    Notice: string;
    IsSponsored: string;
    LogoUrl: string;

    // Refresh Ticker information
    // function RefreshTicker: boolean;

    constructor Create;
    destructor Destroy; override;

    property Timer: TDateTime read GetTimer;
    property LastValue: double read GetLastValue;
    property Bid: double read GetBid;
    property Ask: double read GetAsk;
    property Bump: double read GetBump;
    property AntValue: double read GetAntValue;
  end;

  TMarkets = class(Tlist<TMarket>)
    function GetMarket(const aMarket: string): TMarket;
  end;

  TBittrexApi = class(TComponent)
  private
    fapikey: string;
    fsecret: string;

    aRESTClient: TRESTClient;
    aRESTRequest: TRESTRequest;
    aRESTResponse: TRESTResponse;
  public
    constructor Create(Owner: TComponent); override;

    function GetMarkets(var aMarkets: TMarkets): boolean;
    function GetTicker(const aMarket: string; aTicker: TTicker): boolean;
    function GetBalances(var aBalances: TBalances): boolean;
    function GetOrderHistory(var aOrdersHistory: TOrdersHistory;
      aMarket: string = ''): boolean;

    property APIKEY: string read fapikey write fapikey;
    property SECRET: string read fsecret write fsecret;
  end;

implementation

uses
  IPPeerClient,
  System.SysUtils,
  REST.Types,
  System.Json,
  REST.Json,
  flcHash;

constructor TBittrexApi.Create(Owner: TComponent);
begin
  aRESTClient := TRESTClient.Create('https://bittrex.com/api/v1.1/public/');
  aRESTClient.Accept := 'application/json, text/plain; q=0.9, text/html;q=0.8,';
  aRESTClient.AcceptCharset := 'UTF-8, *;q=0.8';

  aRESTResponse := TRESTResponse.Create(self);
  aRESTResponse.ContentType := 'application/json';

  aRESTRequest := TRESTRequest.Create(self);
  aRESTRequest.Client := aRESTClient;
  aRESTRequest.Response := aRESTResponse;
end;

constructor TMarket.Create;
begin
  fTicker := TTicker.Create;
end;

destructor TMarket.Destroy;
begin
  fTicker.Free;
  inherited;
end;

function TMarket.GetAntValue: double;
begin
  result := fTicker.Ant;
end;

function TMarket.GetAsk: double;
begin
  result := fTicker.Ask;
end;

function TMarket.GetBid: double;
begin
  result := fTicker.Bid;
end;

function TMarket.GetBump: double;
begin
  result := ((LastValue * 100) / fTicker.Ant) - 100;
end;

function TMarket.GetLastValue: double;
begin
  result := fTicker.Last;
end;

function TMarket.GetTimer: TDateTime;
begin
  result := fTicker.datetime;
end;

function TBittrexApi.GetBalances(var aBalances: TBalances): boolean;
var
  aParam: TRESTRequestParameter;
  ajsonBalances: TJsonArray;
  aBalance: TBalance;
  k: integer;
begin
  aRESTClient.BaseURL := 'https://bittrex.com/api/v1.1/account/getbalances';

  aRESTRequest.Params.Clear;

  aParam := aRESTRequest.Params.AddItem;
  aParam.Kind := pkGETorPOST;
  aParam.name := 'apikey';
  aParam.Value := APIKEY;

  aParam := aRESTRequest.Params.AddItem;
  aParam.Kind := pkGETorPOST;
  aParam.name := 'nonce';
  aParam.Value := '0';

  aParam := aRESTRequest.Params.AddItem;
  aParam.Kind := pkHTTPHEADER;
  aParam.name := 'apisign';
  aParam.Value := SHA512DigestToHexW(CalcHMAC_SHA512(SECRET,
    format('%s?apikey=%s&nonce=0', [aRESTClient.BaseURL, APIKEY])));

  result := false;

  aRESTRequest.Execute;

  if aRESTRequest.Response.StatusCode = 200 then
  begin
    if aRESTResponse.JSONValue.GetValue<string>('success') = 'true' then
    begin
      ajsonBalances := aRESTResponse.JSONValue.GetValue<TJsonArray>('result');

      for k := 0 to ajsonBalances.Count - 1 do
      begin
        // Añadimos solo los balances donde tengamos monedas
        if ajsonBalances.Items[k].GetValue<string>('Available').ToDouble > 0
        then
        begin

          aBalance.Currency := ajsonBalances.Items[k].GetValue<string>
            ('Currency');
          aBalance.Balance := ajsonBalances.Items[k].GetValue<string>
            ('Balance').ToDouble;
          aBalance.Available := ajsonBalances.Items[k].GetValue<string>
            ('Available').ToDouble;
          aBalance.Pending := ajsonBalances.Items[k].GetValue<string>
            ('Pending').ToDouble;
          aBalance.CryptoAddress := ajsonBalances.Items[k].GetValue<string>
            ('CryptoAddress');
          // aBalance.Requested := ajsonBalances.Items[k].GetValue<string>          ('Requested').ToBoolean;

          aBalances.Add(aBalance);
        end;
      end;

      result := true;
    end;

  end;

end;

function TBittrexApi.GetMarkets(var aMarkets: TMarkets): boolean;
var
  r: TJsonArray;
  k: integer;
  aMarket: TMarket;
begin
  result := true;
  aMarkets.Clear;

  aRESTClient.BaseURL := 'https://bittrex.com/api/v1.1/public/getmarkets';
  aRESTRequest.Params.Clear;

  aRESTRequest.Execute;
  if aRESTRequest.Response.StatusCode = 200 then
  begin
    if aRESTResponse.JSONValue.GetValue<string>('success') = 'true' then
    begin
      result := true;

      r := aRESTResponse.JSONValue.GetValue<TJsonArray>('result');
      for k := 0 to r.Count - 1 do
      begin
        aMarket := TMarket.Create;

        aMarket.BaseCurrency := r.Items[k].GetValue<string>('BaseCurrency');

        if aMarket.BaseCurrency = 'BTC' then
        begin
          aMarket.MarketCurrency := r.Items[k].GetValue<string>
            ('MarketCurrency');

          aMarket.MarketCurrencyLong := r.Items[k].GetValue<string>
            ('MarketCurrencyLong');
          aMarket.BaseCurrencyLong := r.Items[k].GetValue<string>
            ('BaseCurrencyLong');
          aMarket.MinTradeSize := r.Items[k].GetValue<string>('MinTradeSize');
          aMarket.MarketName := r.Items[k].GetValue<string>('MarketName');

          aMarket.IsActive := r.Items[k].GetValue<boolean>('IsActive');
          // aMarket.Created := r.Items[k].GetValue<tdaatetime>('Created');
          aMarket.Notice := r.Items[k].GetValue<string>('Notice');
          aMarket.IsSponsored := r.Items[k].GetValue<string>('IsSponsored');
          aMarket.LogoUrl := r.Items[k].GetValue<string>('LogoUrl');
          aMarket.IsSponsored := r.Items[k].GetValue<string>('IsSponsored');

          aMarkets.Add(aMarket);
        end;
      end;

    end;

  end;

end;

function TBittrexApi.GetOrderHistory(var aOrdersHistory: TOrdersHistory;
  aMarket: string = ''): boolean;
var
  aParam: TRESTRequestParameter;
  ajsonOrdersHistory: TJsonArray;
  aOrderHistory: TOrderHistory;
  k: integer;
  temp: double;
  ass: string;

begin
  aRESTClient.BaseURL := 'https://bittrex.com/api/v1.1/account/getorderhistory';

  aRESTRequest.Params.Clear;

  aParam := aRESTRequest.Params.AddItem;
  aParam.Kind := pkGETorPOST;
  aParam.name := 'apikey';
  aParam.Value := APIKEY;

  aParam := aRESTRequest.Params.AddItem;
  aParam.Kind := pkGETorPOST;
  aParam.name := 'nonce';
  aParam.Value := '0';

  aParam := aRESTRequest.Params.AddItem;
  aParam.Kind := pkGETorPOST;
  aParam.name := 'market';
  aParam.Value := aMarket;

  aParam := aRESTRequest.Params.AddItem;
  aParam.Kind := pkHTTPHEADER;
  aParam.name := 'apisign';
  aParam.Value := SHA512DigestToHexW(CalcHMAC_SHA512(SECRET,
    format('https://bittrex.com/api/v1.1/account/getorderhistory?apikey=%s&nonce=0&market=%s',
    [APIKEY, aMarket])));

  result := false;

  aRESTRequest.Execute;
  if aRESTRequest.Response.StatusCode = 200 then
  begin
    if aRESTResponse.JSONValue.GetValue<string>('success') = 'true' then
    begin
      ajsonOrdersHistory := aRESTResponse.JSONValue.GetValue<TJsonArray>
        ('result');

      for k := 0 to ajsonOrdersHistory.Count - 1 do
      begin
        aOrderHistory.OrderUuid := ajsonOrdersHistory.Items[k].GetValue<string>
          ('OrderUuid');
        aOrderHistory.Exchange := ajsonOrdersHistory.Items[k].GetValue<string>
          ('Exchange');

        aOrderHistory.OrderType := ajsonOrdersHistory.Items[k].GetValue<string>
          ('OrderType');

        aOrderHistory.Quantity := ajsonOrdersHistory.Items[k].GetValue<string>
          ('Quantity').ToDouble;

        aOrderHistory.Commision := ajsonOrdersHistory.Items[k].GetValue<string>
          ('Commission').ToDouble;

        aOrderHistory.Price := ajsonOrdersHistory.Items[k].GetValue<string>
          ('Price').ToDouble;

        aOrderHistory.PricePerUnit := ajsonOrdersHistory.Items[k]
          .GetValue<string>('PricePerUnit').ToDouble;

        if aOrderHistory.OrderType = 'LIMIT_BUY' then
          aOrderHistory.Cost := -aOrderHistory.Price - aOrderHistory.Commision
        else
          aOrderHistory.Cost := aOrderHistory.Price - aOrderHistory.Commision;

        aOrdersHistory.Add(aOrderHistory);
      end;

      result := true;
    end;

  end;

end;

function TBittrexApi.GetTicker(const aMarket: string; aTicker: TTicker)
  : boolean;
var
  r: TJsonValue;
  aParam: TRESTRequestParameter;
begin
  aRESTClient.BaseURL := 'https://bittrex.com/api/v1.1/public/getticker';

  aRESTRequest.Params.Clear;

  aParam := aRESTRequest.Params.AddItem;
  aParam.Kind := pkGETorPOST;
  aParam.name := 'market';
  aParam.Value := aMarket;

  result := false;
  try
    aRESTRequest.Execute;
    if aRESTRequest.Response.StatusCode = 200 then
    begin
      if aRESTResponse.JSONValue.GetValue<string>('success') = 'true' then
      begin
        r := aRESTResponse.JSONValue.GetValue<TJsonValue>('result');

        aTicker.datetime := now;

        aTicker.Bid := r.GetValue<string>('Bid').ToDouble;
        aTicker.Ask := r.GetValue<string>('Ask').ToDouble;
        aTicker.Last := r.GetValue<string>('Last').ToDouble;

        result := true;
      end;

    end;

  except
    result := false;
  end;

end;

function TBalances.Balance(const aCurrency: string): TBalance;
var
  I: integer;
begin
  for I := 0 to Count - 1 do
    if Items[I].Currency = aCurrency then
      result := Items[I];
end;

{ TMarkets }

function TMarkets.GetMarket(const aMarket: string): TMarket;
var
  I: integer;
begin
  for I := 0 to Count - 1 do
    if Items[I].MarketName = aMarket then
      result := Items[I];

end;

initialization

FormatSettings.DecimalSeparator := '.';

end.
