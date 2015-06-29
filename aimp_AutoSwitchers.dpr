library aimp_AutoSwitchers;

uses
  Windows,
  apiPlugin,
  AutoSwitchers in 'AutoSwitchers.pas';

function AIMPPluginGetHeader(out Header: IAIMPPlugin): HRESULT; stdcall;
begin
  try
    Header := TPlugin.Create;
    Result := S_OK;
  except
    Result := E_UNEXPECTED;
  end;
end;

exports
  AIMPPluginGetHeader;

begin
  //
end.
