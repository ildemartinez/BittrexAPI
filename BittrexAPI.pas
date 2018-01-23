unit BittrexAPI;

interface

uses
  Classes;

type
  TBittrexApi = class(TComponent)
  public
    constructor Create(Owner : TComponent); override;
    destructor Destroy;
  end;

implementation

{ TBittrexApi }

constructor TBittrexApi.Create(Owner: TComponent);
begin
  inherited;

end;

destructor TBittrexApi.Destroy;
begin

end;

end.
