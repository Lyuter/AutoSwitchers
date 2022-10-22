library AutoSwitchers;

{$IFNDEF DEBUG}
  {$WEAKLINKRTTI ON}
  {$RTTI EXPLICIT METHODS([]) FIELDS([]) PROPERTIES([])}
{$ENDIF}

uses
  Windows,
  apiPlugin,
  AutoSwitchersMain in 'AutoSwitchersMain.pas';

function AIMPPluginGetHeader(out Header: IAIMPPlugin): HRESULT; stdcall;
begin
{$IFDEF DEBUG}
    ReportMemoryLeaksOnShutdown := True;
{$ENDIF}
  try
    Header := TASPlugin.Create;
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
