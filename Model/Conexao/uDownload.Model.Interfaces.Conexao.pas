unit uDownload.Model.Interfaces.Conexao;

interface

uses
  FireDAC.Comp.Client;
 type
 iModel_Conexao = interface
   ['{CF49C075-D24F-411F-A2C4-AF7569EABBE8}']
  function Fn_GetConnectionFD:TFDConnection;
 end;
implementation

end.
