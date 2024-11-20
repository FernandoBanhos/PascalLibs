unit CRUDBase.SQLDB;

interface

uses
  fpJSON, SysUtils, Classes, DB,
  SQLDB, SQLDBLib;

type
  TQuery = TSQLQuery;

  { TCRUDBase }

  TCRUDBase = class
  private
    FPK: string;
    FTableName: string;
    FSchema: string;
    function Atualizar(aJSON: TJSONObject): string; overload;
    procedure ErrorHandler(ASender, AInitiator: TObject; var AException: Exception);
    procedure SetPK(const Value: string);
    procedure SetTableName(const Value: string);
    procedure SetSchema(const Value: string);
    function Create(aQuery: string): string;
    function Read(aQuery: string): string;
    function Update(aQuery: string): string;
    function Delete(aQuery: string): string;
  public
    FDataSet: TQuery;
    constructor Create(DataSet: TQuery; aTableName: string = ''; aPK: string = '');

    function Atualizar(aJSON: TJSONObject; out StatusCode: integer;
      ValidaConcorrente: boolean): string; overload;
    function Atualizar(aQuery: string; out StatusCode: integer): string; overload;
    function Excluir(aJSON: TJSONObject; out StatusCode: integer): string; overload;
    function Excluir(aQuery: string; out StatusCode: integer): string; overload;
    function getDados(aJSON: TJSONObject; out StatusCode: integer): string; overload;
    function getDados(aQuery: string; out StatusCode: integer): string; overload;
    function getDados(aQuery: string; aFilterParams: TJSONObject;
      out StatusCode: integer): string; overload;
    function getDados(out StatusCode: integer): string; overload;
    function getValue(aQuery: string; out StatusCode: integer): string;
  published
    property TableName: string read FTableName write SetTableName;
    property PK: string read FPK write SetPK;
    property Schema: string read FSchema write SetSchema;
  end;

  TDataSetJSONHelper = class helper for TDataSet
  public
    function ToJSON: string;
  end;

implementation

{ TCRUDBase }

function TCRUDBase.Atualizar(aJSON: TJSONObject): string;
var
  I: integer;
  pkv: string;
  retorno: TJSONObject;
begin
  Result := '';

  retorno := TJSONObject.Create;
  try
    if not (aJSON.Find(PK) = nil) then
      pkv := StringReplace(aJSON.Get(PK, ''), '"', '', [rfReplaceAll]);

    try
      with FDataSet do
      begin
        Close;
        SQL.Clear;
        if not Schema.IsEmpty then
          SQL.Add('SET search_path = ''%s'';', [FSchema]);
        SQL.Add('SELECT *');
        SQL.Add('  FROM "%s"', [TableName]);
        SQL.Add(' WHERE "%s" = :pkv', [PK]);
        ParamByName('pkv').Value := pkv;
        Open;
        if not IsEmpty then
          Edit
        else
          Append;
        for I := 0 to aJSON.Count - 1 do
        begin
          if not (FindField(aJSON.Names[I]) = nil) then
            FieldByName(aJSON.Names[I]).Value := aJSON.Items[I].AsString;
        end;
        Post;
        //if CachedUpdates then
          ApplyUpdates;
        retorno.Add('status', '1');
        Close;

        if pkv = '' then
        begin
          SQL.Clear;
          SQL.Text := Format('SELECT MAX("%s") FROM "%s"', [PK, TableName]);
          Open;
          retorno.Add(PK, Fields.Fields[0].AsString);
          Close;
        end
        else
          retorno.Add(PK, pkv);
      end;
    except
      on e: Exception do
      begin
        retorno.Add('status', '0');
        retorno.Add('error', e.Message);
      end;
    end;
    Result := retorno.AsString;
  finally
    retorno.Free;
  end;
end;

function TCRUDBase.Atualizar(aJSON: TJSONObject; out StatusCode: integer;
  ValidaConcorrente: boolean): string;
var
  JSONFields, retorno: TJSONObject;
  I: integer;
begin
  Result := '';

  if not ValidaConcorrente then
    Result := Atualizar(aJSON)
  else
  begin
    try
      JSONFields := TJSONObject.Create;
      retorno := TJSONObject.Create;
      with FDataSet do
      begin
        SQL.Clear;
        if not Schema.IsEmpty then
          SQL.Add('SET search_path = ''%s'';', [FSchema]);
        SQL.Add('SELECT * FROM "%s" WHERE "%s" is null', [TableName, PK]);
        Open;
        for I := 0 to pred(aJSON.Count) do
        begin
          if not (FindField(aJSON.Names[I]) = nil) then
            JSONFields.Add(FindField(aJSON.Names[I]).FieldName, aJSON.Items[I].AsString);
        end;
        Close;

        SQL.Clear;
        if not Schema.IsEmpty then
          SQL.Add('SET search_path = ''%s'';', [FSchema]);
        SQL.Add('SELECT *');
        SQL.Add('  FROM "%s"', [TableName]);
        SQL.Add(' WHERE 1=1');
        for I := 0 to pred(JSONFields.Count) do
          SQL.Add(' AND CAST("%s" AS varchar) ILIKE CAST(''%s'' AS varchar)',
            [JSONFields.Names[I], JSONFields.Items[I].AsString]);
        Open;
        if not IsEmpty then
        begin
          StatusCode := 201;
          retorno.Add(PK, FieldByName(PK).AsString);
          Result := retorno.AsString;
        end
        else
          Result := Atualizar(JSONFields);
      end;
    finally
      JSONFields.Free;
      retorno.Free;
      FDataSet.Close;
    end;
  end;
end;

function TCRUDBase.Atualizar(aQuery: string; out StatusCode: integer): string;
begin
  Result := '';

  try
    with FDataSet do
    begin
      Close;
      SQL.Clear;
      if not Schema.IsEmpty then
        SQL.Add('SET search_path = ''%s'';', [FSchema]);
      SQL.Add(aQuery);
      ExecSQL;
      StatusCode := 200;
      Result := '{"status": 1}';
      Close;
    end;
  except
    on e: Exception do
    begin
      StatusCode := 500;
      Result := Format('{"erro":"%s"}', [e.Message]);
    end;
  end;
end;

constructor TCRUDBase.Create(DataSet: TQuery; aTableName: string; aPK: string);
begin
  FSchema := '';
  FDataSet := DataSet;
  // FDataSet.OnError := ErrorHandler;
  TableName := aTableName;
  PK := aPK;
end;

procedure TCRUDBase.ErrorHandler(ASender, AInitiator: TObject;
  var AException: Exception);
begin
  // if AException is EFDDBEngineException then
  // begin
  // if (AException as EFDDBEngineException).Kind = ekFKViolated then
  // raise Exception.Create
  // (escape_chars
  // ('Esse registro não pode ser excluído porque está referenciado em outra tabela')
  // );
  // end
  // else
  // raise Exception.Create(AException.Message);
end;

function TCRUDBase.Excluir(aQuery: string; out StatusCode: integer): string;
begin
  Result := '';

  try
    with FDataSet do
    begin
      Close;
      SQL.Clear;
      if not Schema.IsEmpty then
        SQL.Add('SET search_path = ''%s'';', [FSchema]);
      SQL.Add(aQuery);
      ExecSQL;
      StatusCode := 200;
      Result := Fields.Fields[0].Value;
      Close;
    end;
  except
    on e: Exception do
    begin
      StatusCode := 500;
      Result := Format('{"erro":"%s"}', [e.Message]);
    end;
  end;
end;

function TCRUDBase.Excluir(aJSON: TJSONObject; out StatusCode: integer): string;
var
  I: integer;
begin
  Result := '';

  try
    with FDataSet do
    begin
      Close;
      SQL.Clear;
      if not Schema.IsEmpty then
        SQL.Add('SET search_path = ''%s'';', [FSchema]);
      SQL.Add('DELETE ');
      SQL.Add('  FROM "%s"', [TableName]);
      SQL.Add(' WHERE 1=1');
      for I := 0 to pred(aJSON.Count) do
        SQL.Add(' AND CAST("%s" AS varchar) ILIKE CAST(''%s'' AS varchar)',
          [aJSON.Names[I], aJSON.Items[I].AsString]);

      ExecSQL;
      StatusCode := 200;
      Result := Fields.Fields[0].Value;
      Close;
    end;
  except
    on e: Exception do
    begin
      StatusCode := 500;
      Result := Format('{"erro":"%s"}', [e.Message]);
    end;
  end;

end;

function TCRUDBase.getDados(aQuery: string; out StatusCode: integer): string;
begin
  Result := '';
  try
    with FDataSet do
    begin
      Close;
      SQL.Clear;
      if not Schema.IsEmpty then
        SQL.Add('SET search_path = ''%s'';', [FSchema]);
      SQL.Add(aQuery);
      Open;

      StatusCode := 200;
      Result := FDataSet.ToJSON;

      Close;
    end;
  except
    on e: Exception do
    begin
      StatusCode := 500;
      Result := Format('{"erro":"%s"}', [e.Message]);
    end;
  end;
end;

function TCRUDBase.getDados(aJSON: TJSONObject; out StatusCode: integer): string;
var
  I: integer;
  JSONFields: TJSONObject;
begin
  Result := '';

  JSONFields := TJSONObject.Create;
  try
    with FDataSet do
    begin
      SQL.Clear;
      if not Schema.IsEmpty then
        SQL.Add('SET search_path = ''%s'';', [FSchema]);
      SQL.Add('SELECT * FROM "%s" LIMIT 1', [TableName]);
      Open;
      for I := 0 to pred(aJSON.Count) do
        if not (FindField(aJSON.Names[I]) = nil) then
          JSONFields.Add(FindField(aJSON.Names[I]).FieldName,
            StringReplace(aJSON.Items[I].AsString, '"', '', [rfReplaceAll]));

      Close;
      SQL.Clear;
      if not Schema.IsEmpty then
        SQL.Add('SET search_path = ''%s'';', [FSchema]);
      SQL.Add('SELECT *');
      SQL.Add('  FROM "%s"', [TableName]);
      SQL.Add(' WHERE 1=1');
      for I := 0 to pred(JSONFields.Count) do
        SQL.Add(' AND CAST(%s AS varchar) ILIKE CAST(%s AS varchar)',
          [JSONFields.Names[I], QuotedStr('%' + JSONFields.Items[I].AsString + '%')]);
      Open;

      StatusCode := 200;
      Result := FDataSet.ToJSON;

      Close;
    end;
  finally
    JSONFields.Free;
  end;
end;

function TCRUDBase.getDados(out StatusCode: integer): string;
begin
  Result := '';

  with FDataSet do
  begin
    Close;
    SQL.Clear;
    if not Schema.IsEmpty then
      SQL.Add('SET search_path = ''%s'';', [FSchema]);
    SQL.Add('SELECT * FROM "%s"', [FTableName]);
    Open;

    StatusCode := 200;
    Result := FDataSet.ToJSON;
    Close;
  end;
end;

function TCRUDBase.getValue(aQuery: string; out StatusCode: integer): string;
begin
  Result := '';
  try
    with FDataSet do
    begin
      Close;
      SQL.Clear;
      if not Schema.IsEmpty then
        SQL.Add('SET search_path = ''%s'';', [FSchema]);
      SQL.Add(aQuery);
      Open;

      StatusCode := 200;
      Result := Fields.Fields[0].AsString;

      Close;
    end;
  except
    on e: Exception do
      Result := e.Message;
  end;
end;

function TCRUDBase.getDados(aQuery: string; aFilterParams: TJSONObject;
  out StatusCode: integer): string;
var
  I, J: integer;
  JSONFields: TJSONObject;
  SQLInput: TStringList;
  param: string;
begin
  Result := '';

  JSONFields := TJSONObject.Create;
  SQLInput := TStringList.Create;
  try
    with FDataSet do
    begin
      Close;
      SQL.Clear;
      if not Schema.IsEmpty then
        SQL.Add('SET search_path = ''%s'';', [FSchema]);
      SQL.Add('SELECT * FROM (%s) as r LIMIT 1', [aQuery]);
      Open;

      for I := 0 to pred(aFilterParams.Count) do
      begin
        if pos('.', aFilterParams.Names[I]) > 0 then
          param := Copy(aFilterParams.Names[I],
            pos('.', aFilterParams.Names[I]) + 1, Length(aFilterParams.Names[I]))
        else
          param := aFilterParams.Names[I];

        if not (FindField(param) = nil) then
          JSONFields.Add(aFilterParams.Names[I],
            StringReplace(aFilterParams.Items[I].AsString, '"', '',
            [rfReplaceAll]));
      end;

      Close;
      SQLInput.Text := aQuery;
      SQLInput.Find('ORDER BY', J);
      SQLInput.Insert(J, 'WHERE 1=1');
      J := J + 1;
      for I := 0 to pred(JSONFields.Count) do
      begin
        SQLInput.Insert(J, Format(' AND CAST(%s AS varchar) ILIKE CAST(%s AS varchar)',
          [JSONFields.Names[I], QuotedStr('%' + JSONFields.Items[I].AsString + '%')]));
        J := J + 1;
      end;
      SQL.Text := SQLInput.Text;
      Open;

      StatusCode := 200;
      Result := FDataSet.ToJSON;

      Close;
    end;
  finally
    JSONFields.Free;
  end;
end;

procedure TCRUDBase.SetPK(const Value: string);
begin
  FPK := Value;
end;

procedure TCRUDBase.SetSchema(const Value: string);
begin
  FSchema := Value;
end;

function TCRUDBase.Create(aQuery: string): string;
begin

end;

function TCRUDBase.Read(aQuery: string): string;
begin
  with FDataSet do
  begin
    Close;
    SQL.Clear;
    if not Schema.IsEmpty then
      SQL.Add('SET search_path = ''%s'';', [FSchema]);
    SQL.Add(aQuery);
    Open;

    Result := FDataSet.ToJSON;

    Close;
  end;
end;

function TCRUDBase.Update(aQuery: string): string;
begin

end;

function TCRUDBase.Delete(aQuery: string): string;
begin

end;

procedure TCRUDBase.SetTableName(const Value: string);
begin
  FTableName := Value;
end;

{ TDataSetJSONHelper }

function TDataSetJSONHelper.ToJSON: string;
var
  I: integer;
  JSONArr: TJSONArray;
  JSONObj: TJSONObject;
begin
  JSONArr := TJSONArray.Create;
  try
    while not EOF do
    begin
      JSONObj := TJSONObject.Create;
      for I := 0 to pred(FieldCount) do
        if not Fields.Fields[I].AsString.IsEmpty then
          JSONObj.Add(Fields.Fields[I].FieldName, Fields.Fields[I].AsString);
      JSONArr.Add(JSONObj);
      Next;
    end;
    Result := JSONArr.AsJSON;
  finally
    JSONArr.Free;
  end;
end;

end.
