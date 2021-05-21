unit uDownload.Model.Conexao;

interface

uses
  uDownload.Model.Interfaces.Conexao,
  FireDAC.Comp.Client,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.VCLUI.Wait,
  FireDAC.DApt,
  FireDAC.Phys.SQLite;
 type
 TModel_Conexao = class(TInterfacedObject,iModel_Conexao)
  private
   FConexao:TFDConnection;
  public
   function Fn_GetConnectionFD:TFDConnection;
   class function New:iModel_Conexao;
   constructor Create;
   destructor Destroy; override;
 end;
implementation

uses
  System.SysUtils;

{ TModel_Conexao }

constructor TModel_Conexao.Create;
begin

end;

destructor TModel_Conexao.Destroy;
begin
 FreeandNil(FConexao);
  inherited;
end;

function TModel_Conexao.Fn_GetConnectionFD: TFDConnection;
begin
 if not Assigned(FConexao) then
  begin
   FConexao                  := TFDConnection.Create(nil);
   FConexao.LoginPrompt      := False;
   FConexao.Params.DriverID  := 'SQLite';
   FConexao.Params.Database  := 'C:\Prova SoftPlan\Prova SoftPlan\Model\Banco\BancoProva.sdb';
   FConexao.Connected;
  end;
 Result := FConexao;
end;

class function TModel_Conexao.New: iModel_Conexao;
begin
 Result := Self.Create;
end;

end.
