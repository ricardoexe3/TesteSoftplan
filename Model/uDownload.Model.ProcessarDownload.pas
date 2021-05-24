unit uDownload.Model.ProcessarDownload;

interface

uses
  uDownload.Model.Interfaces,
  uDownload.Model.Interfaces.Conexao,
  uDownload.Model.Conexao,
  Data.DB,
  IdBaseComponent,
  IdComponent,
  IdTCPConnection,
  IdTCPClient,
  IdHTTP,
  IdSSLOpenSSL,
  IdAntiFreeze,
  FireDAC.Comp.Client,
  System.Classes,
  System.Threading;
type
TMensagem = (tpAlert, tpQuestion);

TModel_ProcessarDownload = class(TInterfacedObject,iModel_ProcessarDownload)
private
 FParentConexao:iModel_Conexao;
 FQueryHistorico:TFDQuery;
 FIdHTTP:TIdHTTP;
 FIdSSLIOHandlerSocketOpenSSL: TIdSSLIOHandlerSocketOpenSSL;
 FArquivoDown : TFileStream;
 FLocalArquivo:string;
 FURL:string;
 FDataIni:TDateTime;
 FDataFim:TDate;
 FdAntiFreeze: TIdAntiFreeze;
 FAtualizaProgressoEvent:TAtualizaProgressoEvent;
 FMaxValue:int64;
 FPosition:int64;
 FThreadIniciaDownload : TThread;
 procedure Proc_AtualizaDadosBanco;
 procedure Proc_CriarMecanismoGet;
 procedure Proc_CriarQuery;
 procedure Proc_LimparObjetos;
 function Fn_MensagemAlerta(value:string; tipoMensagem:TMensagem):Boolean;
 procedure Proc_ProcessarDownload;
 function Fn_RetornaPercentual:Double;
 function Fn_Validacoes:Boolean;
 // Eventos do componente TIdHTTP
 procedure IdHTTP1Work(ASender: TObject; AWorkMode: TWorkMode;
  AWorkCount: Int64);
 procedure IdHTTP1WorkBegin(ASender: TObject; AWorkMode: TWorkMode;
  AWorkCountMax: Int64);
 procedure IdHTTP1WorkEnd(ASender: TObject; AWorkMode: TWorkMode);
public
 function Fn_ExibirMensagemProgresso:iModel_ProcessarDownload;
 function Fn_GetDataSet:TDataSet;
 function Fn_IniciarDownload:iModel_ProcessarDownload;
 function Fn_PararDownload:Boolean;
 function Fn_SetLocalArquivo(LocalArquivo:string):iModel_ProcessarDownload;
 function Fn_SetProgresso(Progresso:TAtualizaProgressoEvent):iModel_ProcessarDownload;
 function Fn_SetURL(URL:string):iModel_ProcessarDownload;
 class function New:iModel_ProcessarDownload;
 constructor Create;
 destructor Destroy; override;
end;

implementation

uses
  System.SysUtils,
  Vcl.Dialogs,
  System.UITypes,
  Winapi.Windows;

{ TModel_ProcessarDownload }

constructor TModel_ProcessarDownload.Create;
begin
 FParentConexao := TModel_Conexao.New;
end;

destructor TModel_ProcessarDownload.Destroy;
begin
 FreeAndNil(FQueryHistorico);
 Proc_LimparObjetos;
 if Assigned(FdAntiFreeze) then FreeAndNil(FdAntiFreeze);

 if Assigned(FThreadIniciaDownload) then
  begin
  // FThreadIniciaDownload.Free;
   TerminateThread(FThreadIniciaDownload.Handle, 0);
  end;
  inherited;
end;

procedure TModel_ProcessarDownload.Proc_LimparObjetos;
begin
  // if Assigned(FArquivoDown) then FreeAndNil(FArquivoDown);
  if Assigned(FIdHTTP) then
   begin
   FIdHTTP.Disconnect;
   FreeAndNil(FIdHTTP);
  end;
  if Assigned(FIdSSLIOHandlerSocketOpenSSL) then FreeAndNil(FIdSSLIOHandlerSocketOpenSSL);
end;

function TModel_ProcessarDownload.Fn_MensagemAlerta(value:string; tipoMensagem:TMensagem):Boolean;
begin
 Result := False;

 case tipoMensagem of

  tpAlert: begin
   if Assigned(FThreadIniciaDownload) then
    begin
     FThreadIniciaDownload.Synchronize(FThreadIniciaDownload.CurrentThread,
      procedure
      begin
       MessageDlg(value,mtInformation,[mbOk], 0, mbOk);
      end);
     Exit;
    end;
    MessageDlg(value,mtInformation, [mbOk], 0, mbOk);
  end;

  tpQuestion: begin
       if Assigned(FThreadIniciaDownload) then
        begin
         FThreadIniciaDownload.Synchronize(FThreadIniciaDownload.CurrentThread,
          procedure
          begin
           FThreadIniciaDownload.Suspended:= MessageDlg(value, mtConfirmation,
                                                       [mbYes, mbNo], 0, mbYes) = mrYes
          end);
          Result := FThreadIniciaDownload.Suspended;
         Exit;
        end;

       Result := MessageDlg(value, mtConfirmation,
                           [mbYes, mbNo], 0, mbYes) = mrYes
      end;
 end;
end;

procedure TModel_ProcessarDownload.Proc_CriarQuery;
begin
  if not Assigned(FQueryHistorico) then
  begin
   if not Assigned(FParentConexao) then
      FParentConexao := TModel_Conexao.New;

    FQueryHistorico            := TFDQuery.Create(nil);
    FQueryHistorico.Connection := FParentConexao.Fn_GetConnectionFD;
  end;
end;

function TModel_ProcessarDownload.Fn_ExibirMensagemProgresso: iModel_ProcessarDownload;
 var
 Percent:Double;
begin
 Result  := Self;

 if FMaxValue = 0 then
  begin
   Fn_MensagemAlerta('N�o h� nenhum Download em andamento !',tpAlert);
   Exit;
  end;

 Percent := Fn_RetornaPercentual;
 Fn_MensagemAlerta('Aten��o: Download em andamento '+FormatFloat('##',Percent)+'% conclu�do!',tpAlert);
end;

function TModel_ProcessarDownload.Fn_GetDataSet: TDataSet;
begin
 Proc_CriarQuery;
 Result := FQueryHistorico;
end;

function TModel_ProcessarDownload.Fn_IniciarDownload: iModel_ProcessarDownload;
begin
 Result := Self;
 if Fn_Validacoes then Exit;
 FThreadIniciaDownload := TThread.CreateAnonymousThread(procedure
                                                        begin
                                                         Proc_ProcessarDownload;
                                                        end);
 FThreadIniciaDownload.FreeOnTerminate := True;
 FThreadIniciaDownload.Start;
end;

function TModel_ProcessarDownload.Fn_PararDownload: Boolean;
 var
 Percent:Double;
begin
 Result := False;
 if Assigned(FThreadIniciaDownload) and Assigned(FIdHTTP) then
  begin

    Percent := Fn_RetornaPercentual;
    FThreadIniciaDownload.Suspended := true;

   if not Fn_MensagemAlerta('Aten��o Download em andamento '+FormatFloat('##',Percent)+'% conclu�do' + #13 +
                            'Deseja cancelar?',tpQuestion)
    then
    begin
     FThreadIniciaDownload.Suspended := False;
     Exit;
    end;

   Result := FThreadIniciaDownload.Suspended;
   if Result then
    begin
     FThreadIniciaDownload.Suspended := False;
     FThreadIniciaDownload.FreeOnTerminate := True;
     TerminateThread(FThreadIniciaDownload.Handle, 0);
     FAtualizaProgressoEvent(0, 0);
     FMaxValue := 0;
     FPosition := 0;
    end;
    Exit;
  end;

  Fn_MensagemAlerta('N�o h� nenhum Download em andamento !',tpAlert);
end;

function TModel_ProcessarDownload.Fn_RetornaPercentual: Double;
begin
 Result := (FPosition/FMaxValue*100);
end;

function TModel_ProcessarDownload.Fn_SetLocalArquivo(
  LocalArquivo: string): iModel_ProcessarDownload;
begin
 Result        := Self;
 FLocalArquivo := LocalArquivo;
end;

function TModel_ProcessarDownload.Fn_SetProgresso(
  Progresso: TAtualizaProgressoEvent): iModel_ProcessarDownload;
begin
 Result                  := Self;
 FAtualizaProgressoEvent := Progresso;
end;

function TModel_ProcessarDownload.Fn_SetURL(
  URL: string): iModel_ProcessarDownload;
begin
 Result := Self;
 FURL   := URL;
end;

function TModel_ProcessarDownload.Fn_Validacoes: Boolean;
begin
 Result := False;

 if FURL = EmptyStr then
  begin
   Result := True;
   Fn_MensagemAlerta('N�o foi informado link para download!',tpAlert);
   Exit;
  end;

 if Assigned(FThreadIniciaDownload) and Assigned(FIdHTTP)
  and (FMaxValue>0)
  then
  begin
   Result := True;
   Fn_MensagemAlerta('H� um download em andamento!',tpAlert);
   Exit;
  end;
end;

procedure TModel_ProcessarDownload.IdHTTP1Work(ASender: TObject;
  AWorkMode: TWorkMode; AWorkCount: Int64);
begin
 FAtualizaProgressoEvent(FMaxValue, AWorkCount);
 FPosition := AWorkCount;
end;

procedure TModel_ProcessarDownload.IdHTTP1WorkBegin(ASender: TObject;
  AWorkMode: TWorkMode; AWorkCountMax: Int64);
begin
 FMaxValue := AWorkCountMax;
end;

procedure TModel_ProcessarDownload.IdHTTP1WorkEnd(ASender: TObject;
  AWorkMode: TWorkMode);
begin
 FAtualizaProgressoEvent(0, 0);
 FPosition := 0;
 FMaxValue := 0;
end;

class function TModel_ProcessarDownload.New: iModel_ProcessarDownload;
begin
 Result := Self.Create;
end;

procedure TModel_ProcessarDownload.Proc_AtualizaDadosBanco;
var
 Seq:integer;
begin
 try
   if not Assigned(FQueryHistorico) then
          Proc_CriarQuery;

   if not Assigned(FParentConexao.Fn_GetConnectionFD) then
          Exit;

   FQueryHistorico.Close;
   FQueryHistorico.SQL.Text := ' Select' + #13 +
                               ' Max(CODIGO) as Codigo' + #13 +
                               ' From LOGDOWNLOAD';
   FQueryHistorico.Open;

   if FQueryHistorico.FieldByName('Codigo').Text = EmptyStr then
      Seq := 1
   else
      Seq := FQueryHistorico.FieldByName('Codigo').AsInteger + 1;

   FQueryHistorico.Close;
   FQueryHistorico.SQL.Text := ' Select ' + #13 +
                               ' CODIGO,' + #13 +
                               ' URL,' + #13 +
                               ' DATAINICIO,' + #13 +
                               ' DATAFIM' + #13 +
                               ' From LOGDOWNLOAD' + #13 +
                               ' LIMIT 0;';
   FQueryHistorico.Open;

   FQueryHistorico.Append;
   FQueryHistorico.FieldByName('CODIGO').AsInteger      := Seq;
   FQueryHistorico.FieldByName('URL').AsString          := FURL;
   FQueryHistorico.FieldByName('DATAINICIO').AsDateTime := FDataIni;
   FQueryHistorico.FieldByName('DATAFIM').Value         := FDataFim;
   FQueryHistorico.Post;
   FQueryHistorico.Connection.Close;
 except on Erro:exception do
  raise Exception.Create('Falha ao atualizar download no banco de dados:'+Erro.Message);
 end;
end;

procedure TModel_ProcessarDownload.Proc_CriarMecanismoGet;
begin
 if Assigned(FIdHTTP) then Exit;
 // Cria��o de objetos e set's de eventos
 FIdHTTP                                             := TIdHTTP.Create(nil);
 FIdHTTP.OnWork                                      := IdHTTP1Work;
 FIdHTTP.OnWorkBegin                                 := IdHTTP1WorkBegin;
 FIdHTTP.OnWorkEnd                                   := IdHTTP1WorkEnd;
 FIdSSLIOHandlerSocketOpenSSL                        := TIdSSLIOHandlerSocketOpenSSL.Create(nil);
 FIdSSLIOHandlerSocketOpenSSL.SSLOptions.SSLVersions := [sslvTLSv1, sslvTLSv1_1, sslvTLSv1_2];
 FIdHTTP.IOHandler                                   := FIdSSLIOHandlerSocketOpenSSL;
 FdAntiFreeze                                        := TIdAntiFreeze.Create(nil);
end;

procedure TModel_ProcessarDownload.Proc_ProcessarDownload;
begin
 Proc_CriarMecanismoGet;
 FDataIni := Now;
 try
   if not DirectoryExists(FLocalArquivo) then
          CreateDir(FLocalArquivo);

   FArquivoDown := TFileStream.Create(FLocalArquivo+'\Download_'+FormatDateTime('yyyymmddhhmmsszzz',Now) +
                                      ExtractFileExt(FURL),
                                      fmCreate);
   FIdHTTP.Get(FURL,
               FArquivoDown);


   FDataFim := Date;
   Proc_AtualizaDadosBanco;
   FArquivoDown.Free;
   Proc_LimparObjetos;
 except on Erro:exception do
  begin
   Fn_MensagemAlerta('Falha ao realizar o download:'+Erro.Message,tpAlert);
  end;
  end

end;

end.
