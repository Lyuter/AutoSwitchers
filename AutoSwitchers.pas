{~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

           AutoSwitchers - AIMP3 plugin
            Version: 1.2 (29.06.2015)
              Copyright (c) Lyuter
           Mail : pro100lyuter@mail.ru

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}
unit AutoSwitchers;

interface

uses  Windows,
      AIMPCustomPlugin,
      apiWrappers, apiPlaylists, apiCore,
      apiMenu, apiActions, apiObjects, apiPlugin,
      apiMessages, apiPlayer;

const
    PLUGIN_NAME              = 'AutoSwitchers v1.2 for AIMP 3';
    PLUGIN_AUTHOR            = 'Author: Lyuter';
    PLUGIN_SHORT_DESCRIPTION = '';
    PLUGIN_FULL_DESCRIPTION  = 'The plugin automatically switch off the tracks in the playlist after playing them. Use Playlist\Misc menu to activate the plugin.';
    //
    AS_CAPTION               = 'AutoSwitchers';
    //
    AS_CONTEXTMENU_CAPTION   = 'AutoSwitchers';
    AS_CONTEXTMENU_ID        = 'AutoSwitchers.Menu';
    //
    AS_CONFIG_KEYPATH        = 'AutoSwitchers\HandledPlaylistsID';

type

  TASMessageHook = class(TInterfacedObject, IAIMPMessageHook)
  public
    procedure CoreMessage(Message: DWORD; Param1: Integer; Param2: Pointer; var Result: HRESULT); stdcall;
  end;

  TPlugin = class(TAIMPCustomPlugin)
  private
    ASMessageHook: TASMessageHook;
    procedure CreateContextMenu;
    function GetBuiltInMenu(ID: Integer): IAIMPMenuItem;
  protected
    function InfoGet(Index: Integer): PWideChar; override; stdcall;
    function InfoGetCategories: Cardinal; override; stdcall;
    function Initialize(Core: IAIMPCore): HRESULT; override; stdcall;
    procedure Finalize; override; stdcall;
  end;

  TASExecuteHandler = class(TInterfacedObject, IAIMPActionEvent)
  public
    procedure OnExecute(Data: IInterface); stdcall;
  end;

  TASMenuOnShowHandler = class(TInterfacedObject, IAIMPActionEvent)
  public
    procedure OnExecute(Data: IInterface); stdcall;
  end;


implementation

{--------------------------------------------------------------------}
procedure ShowErrorMessage(ErrorMessage: String);
var
  DLLName: array[0..MAX_PATH - 1] of Char;
  FullMessage: String;
begin
  FillChar(DLLName, MAX_PATH, #0);
  GetModuleFileName(HInstance, DLLName, MAX_PATH);
  FullMessage := 'Exception in module "' + DLLName + '".'#13#13 + ErrorMessage;
  MessageBox(0, PChar(FullMessage), AS_CAPTION, MB_ICONERROR);
end;
{--------------------------------------------------------------------}
function FindSubString(AIMPString, AIMPSubString: IAIMPString): Integer;
var
  SearchIndex: Integer;
begin
  Result := -1;
  if not Failed(AIMPString.Find(AIMPSubString, SearchIndex,
                                  AIMP_STRING_FIND_WHOLEWORD
                                      and AIMP_STRING_FIND_IGNORECASE, 0))
  then  Result := SearchIndex;
end;
{--------------------------------------------------------------------}
function GetActivePlaylistID: IAIMPString;
var
  PLManager: IAIMPServicePlaylistManager;
  ActivePL: IAIMPPlaylist;
  ActivePLPropertyList: IAIMPPropertyList;
  ActivePLID: IAIMPString;
begin
  CheckResult(CoreIntf.QueryInterface(IID_IAIMPServicePlaylistManager,
                                           PLManager));
  CheckResult(PLManager.GetActivePlaylist(ActivePL));
  CheckResult(ActivePL.QueryInterface(IID_IAIMPPropertyList, ActivePLPropertyList));
  CheckResult(ActivePLPropertyList.GetValueAsObject(AIMP_PLAYLIST_PROPID_ID,
                                            IID_IAIMPString, Result));
end;
{--------------------------------------------------------------------}
function IsPlaylistHandled(PlaylistID: IAIMPString): Boolean;
var
  ServiceConfig: IAIMPServiceConfig;
  PLIDList: IAIMPString;
begin
  Result := False;
  // Getting the list of handled playlists
  CheckResult(CoreIntf.QueryInterface(IID_IAIMPServiceConfig, ServiceConfig));
  if not Failed(ServiceConfig.GetValueAsString(MakeString(AS_CONFIG_KEYPATH),
                                                    PLIDList))
    and (FindSubString(PLIDList, PlaylistID) > -1)
  then Result := True;
end;
{--------------------------------------------------------------------}
procedure TogglePlaylistStatus(PlaylistID: IAIMPString);
var
  ServiceConfig: IAIMPServiceConfig;
  PLIDList: IAIMPString;

  SearchIndex: Integer;
begin
  // Getting the list of handled playlists
  CheckResult(CoreIntf.QueryInterface(IID_IAIMPServiceConfig, ServiceConfig));
  // Checking for playlists ID list
  if Failed(ServiceConfig.GetValueAsString(MakeString(AS_CONFIG_KEYPATH),
                                                    PLIDList))
  then  // If nothing found add new ID to config
    CheckResult(ServiceConfig.SetValueAsString(MakeString(AS_CONFIG_KEYPATH),
                                                             PlaylistID))
  else
    begin
      // If something found searching for the PlaylistID
      SearchIndex :=  FindSubString(PLIDList, PlaylistID);
      if  SearchIndex > -1
      then  PLIDList.Delete(SearchIndex, PlaylistID.GetLength)
      else  PLIDList.Add(PlaylistID);
      // Updating config
      CheckResult(ServiceConfig.SetValueAsString(MakeString(AS_CONFIG_KEYPATH),
                                                    PLIDList));
    end
end;
{--------------------------------------------------------------------}
procedure CleanListOfHandledPlaylists;
var
  PLManager: IAIMPServicePlaylistManager;
  PLByIndex: IAIMPPlaylist;
  PLPropertyList: IAIMPPropertyList;
  PLID, PLIDList, NewPLIDList: IAIMPString;
  ServiceConfig: IAIMPServiceConfig;

  PLCount, Index: Integer;
begin
try
  CheckResult(CoreIntf.QueryInterface(IID_IAIMPServiceConfig, ServiceConfig));
  // Checking existence of the playlists ID list
  if Failed(ServiceConfig.GetValueAsString(MakeString(AS_CONFIG_KEYPATH), PLIDList))
  then  exit;
  CheckResult(CoreIntf.QueryInterface(IID_IAIMPServicePlaylistManager, PLManager));
  CheckResult(CoreIntf.CreateObject(IID_IAIMPString, NewPLIDList));
  PLCount := PLManager.GetLoadedPlaylistCount;

  // Checking all active playlists for handlers
  for Index := 0 to PLCount - 1
  do
    begin
      CheckResult(PLManager.GetLoadedPlaylist(Index, PLByIndex));
      CheckResult(PLByIndex.QueryInterface(IID_IAIMPPropertyList,
                                                    PLPropertyList));
      CheckResult(PLPropertyList.GetValueAsObject(AIMP_PLAYLIST_PROPID_ID,
                                                    IID_IAIMPString, PLID));
      if (FindSubString(PLIDList, PLID) > -1)
      then  NewPLIDList.Add(PLID);
    end;
  //  Write the new playlists ID list to config
  CheckResult(ServiceConfig.SetValueAsString(MakeString(AS_CONFIG_KEYPATH),
                                                                NewPLIDList));
except
  ShowErrorMessage('"Cleaning" failure!');
end;
end;

{=========================================================================)
                                 TPlugin
(=========================================================================}
function TPlugin.InfoGet(Index: Integer): PWideChar;
begin
  case Index of
    AIMP_PLUGIN_INFO_NAME               : Result := PLUGIN_NAME;
    AIMP_PLUGIN_INFO_AUTHOR             : Result := PLUGIN_AUTHOR;
    AIMP_PLUGIN_INFO_FULL_DESCRIPTION   : Result := PLUGIN_FULL_DESCRIPTION;
    AIMP_PLUGIN_INFO_SHORT_DESCRIPTION  : Result := PLUGIN_SHORT_DESCRIPTION;
  else
    Result := nil;
  end;
end;

function TPlugin.InfoGetCategories: Cardinal;
begin
  Result := AIMP_PLUGIN_CATEGORY_ADDONS;
end;
{--------------------------------------------------------------------
Initialize}
function TPlugin.Initialize(Core: IAIMPCore): HRESULT;
var
  ServiceMenuManager: IAIMPServiceMenuManager;
  ServiceMessageDispatcher: IAIMPServiceMessageDispatcher;
begin
  Result := Core.QueryInterface(IID_IAIMPServiceMenuManager, ServiceMenuManager);
  if Succeeded(Result)
  then
    begin
      Result := inherited Initialize(Core);
      if Succeeded(Result)
      then
        begin
          CreateContextMenu;
          // Creating the message hook
          CheckResult(CoreIntf.QueryInterface(IID_IAIMPServiceMessageDispatcher,
                                                ServiceMessageDispatcher));
          ASMessageHook := TASMessageHook.Create;
          CheckResult(ServiceMessageDispatcher.Hook(ASMessageHook));
        end;
    end;
end;
{--------------------------------------------------------------------
Finalize}
procedure TPlugin.Finalize;
var
  ServiceMessageDispatcher: IAIMPServiceMessageDispatcher;
begin
  CleanListOfHandledPlaylists;
  // Removing the message hook
  CheckResult(CoreIntf.QueryInterface(IID_IAIMPServiceMessageDispatcher,
                                                ServiceMessageDispatcher));
  CheckResult(ServiceMessageDispatcher.Unhook(ASMessageHook));
  inherited;
end;
{--------------------------------------------------------------------}
function TPlugin.GetBuiltInMenu(ID: Integer): IAIMPMenuItem;
var
  AMenuService: IAIMPServiceMenuManager;
begin
  CheckResult(CoreIntf.QueryInterface(IAIMPServiceMenuManager, AMenuService));
  CheckResult(AMenuService.GetBuiltIn(ID, Result));
end;
{--------------------------------------------------------------------}
procedure TPlugin.CreateContextMenu;
var
  ASContextMenu: IAIMPMenuItem;
begin
try
  // Create menu item
  CheckResult(CoreIntf.CreateObject(IID_IAIMPMenuItem, ASContextMenu));
  CheckResult(ASContextMenu.SetValueAsObject(AIMP_MENUITEM_PROPID_ID,
                                          MakeString(AS_CONTEXTMENU_ID)));
  CheckResult(ASContextMenu.SetValueAsObject(AIMP_MENUITEM_PROPID_NAME,
                                          MakeString(AS_CONTEXTMENU_CAPTION)));
  CheckResult(ASContextMenu.SetValueAsInt32(AIMP_MENUITEM_PROPID_STYLE,
                                          AIMP_MENUITEM_STYLE_CHECKBOX));
  CheckResult(ASContextMenu.SetValueAsObject(AIMP_MENUITEM_PROPID_PARENT,
                    GetBuiltInMenu(AIMP_MENUID_PLAYER_PLAYLIST_MISCELLANEOUS)));
  CheckResult(ASContextMenu.SetValueAsObject(AIMP_MENUITEM_PROPID_EVENT,
                                          TASExecuteHandler.Create));
  CheckResult(ASContextMenu.SetValueAsObject(AIMP_MENUITEM_PROPID_EVENT_ONSHOW,
                                          TASMenuOnShowHandler.Create));
  // Register the menu item in manager
  CheckResult(CoreIntf.RegisterExtension(IID_IAIMPServiceMenuManager, ASContextMenu));
except
  ShowErrorMessage('"CreateContextMenu" failure!');
end;
end;

{=========================================================================)
                                TUMMessageHook
(=========================================================================}
procedure TASMessageHook.CoreMessage(Message: DWORD; Param1: Integer;
  Param2: Pointer; var Result: HRESULT);
var
  PLManager: IAIMPServicePlaylistManager;
  PlayablePL: IAIMPPlaylist;
  PlayablePLPropertyList: IAIMPPropertyList;
  PlayablePLID: IAIMPString;

  ServicePlayer: IAIMPServicePlayer;
  ActiveItem: IAIMPPlaylistItem;
begin
try
  case Message  of
    AIMP_MSG_EVENT_STREAM_START:
      begin
        CheckResult(CoreIntf.QueryInterface(IID_IAIMPServicePlaylistManager,
                                                PLManager));
        CheckResult(PLManager.GetPlayablePlaylist(PlayablePL));
        CheckResult(PlayablePL.QueryInterface(IID_IAIMPPropertyList,
                                                PlayablePLPropertyList));
        CheckResult(PlayablePLPropertyList.GetValueAsObject(AIMP_PLAYLIST_PROPID_ID,
                                                IID_IAIMPString, PlayablePLID));
        if IsPlaylistHandled(PlayablePLID)
        then
          begin
            // Turning off the active track
            CheckResult(CoreIntf.QueryInterface(IID_IAIMPServicePlayer, ServicePlayer));
            CheckResult(ServicePlayer.GetPlaylistItem(ActiveItem));
            ActiveItem.SetValueAsInt32(AIMP_PLAYLISTITEM_PROPID_PLAYINGSWITCH, 0);
          end;
      end;
  end;
except
  ShowErrorMessage('"MessageHook.CoreMessage" failure!');
end;
end;

{=========================================================================)
                            TASMenuOnShowHandler
(=========================================================================}
procedure TASMenuOnShowHandler.OnExecute(Data: IInterface);
var
  ServiceMenuManager: IAIMPServiceMenuManager;
  MenuItem: IAIMPMenuItem;
begin
try
  // Update the Menu status for active playlist
  CheckResult(CoreIntf.QueryInterface(IID_IAIMPServiceMenuManager,
                                          ServiceMenuManager));
  CheckResult(ServiceMenuManager.GetByID(MakeString(AS_CONTEXTMENU_ID),
                                          MenuItem));
  CheckResult(MenuItem.SetValueAsInt32(AIMP_MENUITEM_PROPID_CHECKED,
                          Integer(IsPlaylistHandled(GetActivePlaylistID))));
except
  ShowErrorMessage('"MenuOnShowHandler.OnExecute" failure!');
end;
end;

{=========================================================================)
                              TASExecuteHandler
(=========================================================================}
procedure TASExecuteHandler.OnExecute(Data: IInterface);
begin
try
  TogglePlaylistStatus(GetActivePlaylistID);
except
  ShowErrorMessage('"ExecuteHandler.OnExecute" failure!');
end;
end;

{=========================================================================)
                                  THE END
(=========================================================================}

end.
