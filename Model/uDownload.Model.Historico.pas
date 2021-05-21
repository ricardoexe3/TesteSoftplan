unit uDownload.Model.Historico;

interface

uses
  uDownload.Model.Interfaces,
  Data.DB,
  uDownload.Model.Interfaces.Conexao,
  uDownload.Model.Conexao,
  FireDAC.Comp.Client;
 type
 TModel_Historico = class(TInterfacedObject,iModel_Historico)
  private
   FParentConexao:iModel_Conexao;
   FQueryHistorico:TFDQuery;
  public
   function Fn_CarregarHistorico:iModel_Historico;
   function Fn_GetDataSet:TDataSet;
   class function New:iModel_Historico;
   constructor Create;
   destructor Destroy; override;
 end;
implementation

uses
  System.SysUtils;
{ TModel_Historico }

constructor TModel_Historico.Create;
begin
  if not Assigned(FQueryHistorico) then
  begin
   if not Assigned(FParentConexao) then
      FParentConexao := TModel_Conexao.New;

    FQueryHistorico := TFDQuery.Create(nil);
    FQueryHistorico.Connection := FParentConexao.Fn_GetConnectionFD;
  end;
end;

destructor TModel_Historico.Destroy;
begin
 FreeAndNil(FQueryHistorico);
  inherited;
end;

function TModel_Historico.Fn_CarregarHistorico: iModel_Historico;
begin
 Result := Self;
 if Assigned(FQueryHistorico) and not (FQueryHistorico.Connection.LoginPrompt) then
  begin
   FQueryHistorico.Close;
   FQueryHistorico.SQL.Text := ' Select' + #13 +
                               ' CODIGO,' + #13 +
                               ' URL,' + #13 +
                               ' DATAINICIO,' + #13 +
                               ' DATAFIM' + #13 +
                               ' From LOGDOWNLOAD' + #13 +
                               ' ORDER BY DATAINICIO';
   FQueryHistorico.Open;
  end;
end;

function TModel_Historico.Fn_GetDataSet: TDataSet;
begin
 Result := FQueryHistorico;
end;

class function TModel_Historico.New: iModel_Historico;
begin
 Result := Self.Create;
end;

end.
