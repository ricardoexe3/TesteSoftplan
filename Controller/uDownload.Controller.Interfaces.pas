unit uDownload.Controller.Interfaces;

interface

uses
  uDownload.Model.Interfaces;
type
iController_ProcessarDownload = interface
 ['{6584446A-1BBD-4483-B401-1E3F9FFACE59}']
 function Fn_Processar:iModel_ProcessarDownload;
end;

iController_Historico = interface
 ['{DBA44CBD-F536-421F-BFFF-38AEFC5B3067}']
 function Fn_Historico:iModel_Historico;
end;


implementation

end.
