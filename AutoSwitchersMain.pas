{~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

           AutoSwitchers - AIMP3 plugin
                 Version: 1.2.1
              Copyright (c) Lyuter
           Mail : pro100lyuter@mail.ru

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}
unit AutoSwitchersMain;

interface

uses  Windows, SysUtils,
      AIMPCustomPlugin,
      apiWrappers, apiPlaylists, apiCore,
      apiMenu, apiActions, apiObjects, apiPlugin,
      apiMessages, apiPlayer, apiFileManager,
      apiMUI;

const
    PLUGIN_NAME              = 'AutoSwitchers v1.2.1 for AIMP 3';
    PLUGIN_AUTHOR            = 'Author: Lyuter';
    PLUGIN_SHORT_DESCRIPTION = '';
    PLUGIN_FULL_DESCRIPTION  = '* The plugin automatically switch off the tracks ' +
                               'in the playlist after playing them.'#13 +
                               '* Use Playlist\Misc menu to activate the plugin.';
    //
    AS_CAPTION               = 'AutoSwitchers';
    //
    AS_CONTEXTMENU_CAPTION             = 'AutoSwitchers';
    AS_CONTEXTMENU_ID_PARENT           = 'AutoSwitchers.Menu.Parent';
    AS_CONTEXTMENU_ID_ENABLE           = 'AutoSwitchers.Menu.Enable';
    AS_CONTEXTMENU_ID_SKIPFAVORITE     = 'AutoSwitchers.Menu.SkipFavorite';
    AS_CONTEXTMENU_ID_WAITFORLIBANSWER = 'AutoSwitchers.Menu.WaitForLibAnswer';
    //
    AS_CONTEXTMENU_KEYPATH_ENABLE           = 'AutoSwitchers\EnablePlugin';
    AS_CONTEXTMENU_KEYPATH_SKIPFAVORITE     = 'AutoSwitchers\SkipFavorite';
    AS_CONTEXTMENU_KEYPATH_WAITFORLIBANSWER = 'AutoSwitchers\WaitForLibAnswer';
    //
    AS_CONFIG_KEYPATH_HANDLEDLIST      = 'AutoSwitchers\HandledPlaylistsID';
    AS_CONFIG_KEYPATH_SKIPFAVORITE     = 'AutoSwitchers\SkipFavorite';
    AS_CONFIG_KEYPATH_WAITFORLIBANSWER = 'AutoSwitchers\WaitForLibAnswer';

type

  TASMessageHook = class(TInterfacedObject, IAIMPMessageHook)
    LastPlaylistItem: IAIMPPlaylistItem;
  public
    procedure CoreMessage(Message: DWORD; Param1: Integer; Param2: Pointer;
                                                  var Result: HRESULT); stdcall;
  end;

  TASPlugin = class(TAIMPCustomPlugin)
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

  TASMenuEnableHandler = class(TInterfacedObject, IAIMPActionEvent)
  public
    procedure OnExecute(Data: IInterface); stdcall;
  end;

  TASMenuEnableOnShowHandler = class(TInterfacedObject, IAIMPActionEvent)
  public
    procedure OnExecute(Data: IInterface); stdcall;
  end;

  TASMenuSkipFavoriteHandler = class(TInterfacedObject, IAIMPActionEvent)
  public
    procedure OnExecute(Data: IInterface); stdcall;
  end;

  TASMenuSkipFavoriteOnShowHandler = class(TInterfacedObject, IAIMPActionEvent)
  public
    procedure OnExecute(Data: IInterface); stdcall;
  end;

  TASMenuWaitForLibAnswerHandler = class(TInterfacedObject, IAIMPActionEvent)
  public
    procedure OnExecute(Data: IInterface); stdcall;
  end;

  TASMenuWaitForLibAnswerOnShowHandler = class(TInterfacedObject, IAIMPActionEvent)
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
  if not Failed(ServiceConfig.GetValueAsString(MakeString(AS_CONFIG_KEYPATH_HANDLEDLIST),
                                                    PLIDList))
    and (FindSubString(PLIDList, PlaylistID) > -1)
  then Result := True;
end;
{--------------------------------------------------------------------}
function IsFavorite(PlaylistItem: IAIMPPlaylistItem): Boolean;
var
  FileInfo: IAIMPFileInfo;
  Mark: Double;
begin
  Result := False;
  CheckResult(PlaylistItem.GetValueAsObject(AIMP_PLAYLISTITEM_PROPID_FILEINFO,
                                                 IID_IAIMPFileInfo, FileInfo));
  FileInfo.GetValueAsFloat(AIMP_FILEINFO_PROPID_MARK, Mark);
  if Mark >= 4.5
  then
    Result := True;
end;
{--------------------------------------------------------------------}
function IsSkipFavorite: Boolean;
var
  ServiceConfig: IAIMPServiceConfig;
  SkipFavorite: Integer;
begin
  // Disable by default
  Result := False;
  CheckResult(CoreIntf.QueryInterface(IID_IAIMPServiceConfig, ServiceConfig));
  if not Failed(ServiceConfig.GetValueAsInt32(MakeString(AS_CONFIG_KEYPATH_SKIPFAVORITE),
                                                    SkipFavorite))
    and (SkipFavorite <> 0)
  then Result := True;
end;
{--------------------------------------------------------------------}
function IsWaitForLibAnswer: Boolean;
var
  ServiceConfig: IAIMPServiceConfig;
  WaitForLibAnswer: Integer;
begin
  // Disable by default
  Result := False;
  CheckResult(CoreIntf.QueryInterface(IID_IAIMPServiceConfig, ServiceConfig));
  if not Failed(ServiceConfig.GetValueAsInt32(MakeString(AS_CONFIG_KEYPATH_WAITFORLIBANSWER),
                                                    WaitForLibAnswer))
    and (WaitForLibAnswer <> 0)
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
  if Failed(ServiceConfig.GetValueAsString(MakeString(AS_CONFIG_KEYPATH_HANDLEDLIST),
                                                    PLIDList))
  then  // If nothing found add new ID to config
    CheckResult(ServiceConfig.SetValueAsString(MakeString(AS_CONFIG_KEYPATH_HANDLEDLIST),
                                                             PlaylistID))
  else
    begin
      // If something found searching for the PlaylistID
      SearchIndex :=  FindSubString(PLIDList, PlaylistID);
      if  SearchIndex > -1
      then  PLIDList.Delete(SearchIndex, PlaylistID.GetLength)
      else  PLIDList.Add(PlaylistID);
      // Updating config
      CheckResult(ServiceConfig.SetValueAsString(MakeString(AS_CONFIG_KEYPATH_HANDLEDLIST),
                                                    PLIDList));
    end
end;
{--------------------------------------------------------------------}
procedure ToggleSkipFavoriteStatus;
var
  ServiceConfig: IAIMPServiceConfig;
  SkipFavoriteStatus: Integer;
begin
  CheckResult(CoreIntf.QueryInterface(IID_IAIMPServiceConfig, ServiceConfig));
  if Failed(ServiceConfig.GetValueAsInt32(MakeString(AS_CONFIG_KEYPATH_SKIPFAVORITE),
                                                    SkipFavoriteStatus))
  then
    CheckResult(ServiceConfig.SetValueAsInt32(MakeString(AS_CONFIG_KEYPATH_SKIPFAVORITE),
                                   Integer(True)))
  else
    CheckResult(ServiceConfig.SetValueAsInt32(MakeString(AS_CONFIG_KEYPATH_SKIPFAVORITE),
                                   Integer(not Boolean(SkipFavoriteStatus))))
end;
{--------------------------------------------------------------------}
procedure ToggleWaitForLibAnswerStatus;
var
  ServiceConfig: IAIMPServiceConfig;
  WaitForLibAnswerStatus: Integer;
begin
  CheckResult(CoreIntf.QueryInterface(IID_IAIMPServiceConfig, ServiceConfig));
  if Failed(ServiceConfig.GetValueAsInt32(MakeString(AS_CONFIG_KEYPATH_WAITFORLIBANSWER),
                                                    WaitForLibAnswerStatus))
  then
    CheckResult(ServiceConfig.SetValueAsInt32(MakeString(AS_CONFIG_KEYPATH_WAITFORLIBANSWER),
                                   Integer(True)))
  else
    CheckResult(ServiceConfig.SetValueAsInt32(MakeString(AS_CONFIG_KEYPATH_WAITFORLIBANSWER),
                                   Integer(not Boolean(WaitForLibAnswerStatus))))
end;
{--------------------------------------------------------------------}
procedure DisableActivePlaylistItem;
var
  PLManager: IAIMPServicePlaylistManager;
  PlayablePL: IAIMPPlaylist;
  PlayablePLPropertyList: IAIMPPropertyList;
  PlayablePLID: IAIMPString;

  ServicePlayer: IAIMPServicePlayer;
  ActiveItem: IAIMPPlaylistItem;
begin
  CheckResult(CoreIntf.QueryInterface(IID_IAIMPServicePlaylistManager, PLManager));
  if PLManager.GetPlayablePlaylist(PlayablePL) <> S_OK
  then  // If the playable playlist don't exists then we don't need to disable the ActiveItem
    exit;
  CheckResult(PlayablePL.QueryInterface(IID_IAIMPPropertyList, PlayablePLPropertyList));
  CheckResult(PlayablePLPropertyList.GetValueAsObject(AIMP_PLAYLIST_PROPID_ID,
                                          IID_IAIMPString, PlayablePLID));
  if IsPlaylistHandled(PlayablePLID)
  then
    begin
      // Turning off the active track
      CheckResult(CoreIntf.QueryInterface(IID_IAIMPServicePlayer, ServicePlayer));
      if ServicePlayer.GetPlaylistItem(ActiveItem) <> S_OK
      then  // If the ActiveItem don't exists then we don't need to disable it
        exit;

      if IsSkipFavorite
      then
        if not (IsFavorite(ActiveItem))
          then
            ActiveItem.SetValueAsInt32(AIMP_PLAYLISTITEM_PROPID_PLAYINGSWITCH, 0)
          else
      else
        ActiveItem.SetValueAsInt32(AIMP_PLAYLISTITEM_PROPID_PLAYINGSWITCH, 0);
    end;
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
  if Failed(ServiceConfig.GetValueAsString(MakeString(AS_CONFIG_KEYPATH_HANDLEDLIST), PLIDList))
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
  CheckResult(ServiceConfig.SetValueAsString(MakeString(AS_CONFIG_KEYPATH_HANDLEDLIST),
                                                                NewPLIDList));
except
  ShowErrorMessage('"Cleaning" failure!');
end;
end;

{=========================================================================)
                                 TASPlugin
(=========================================================================}
function TASPlugin.InfoGet(Index: Integer): PWideChar;
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

function TASPlugin.InfoGetCategories: Cardinal;
begin
  Result := AIMP_PLUGIN_CATEGORY_ADDONS;
end;
{--------------------------------------------------------------------
Initialize}
function TASPlugin.Initialize(Core: IAIMPCore): HRESULT;
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
        try
          CreateContextMenu;
          // Creating the message hook
          CheckResult(CoreIntf.QueryInterface(IID_IAIMPServiceMessageDispatcher,
                                                ServiceMessageDispatcher));
          ASMessageHook := TASMessageHook.Create;
          CheckResult(ServiceMessageDispatcher.Hook(ASMessageHook));
        except
          Result := E_UNEXPECTED;
        end;
    end;
end;
{--------------------------------------------------------------------
Finalize}
procedure TASPlugin.Finalize;
var
  ServiceMessageDispatcher: IAIMPServiceMessageDispatcher;
begin
 try
  CleanListOfHandledPlaylists;
  // Removing the message hook
  CheckResult(CoreIntf.QueryInterface(IID_IAIMPServiceMessageDispatcher,
                                                ServiceMessageDispatcher));
  CheckResult(ServiceMessageDispatcher.Unhook(ASMessageHook));
 except
  ShowErrorMessage('"Plugin.Finalize" failure!');
 end;
  inherited;
end;
{--------------------------------------------------------------------}
function TASPlugin.GetBuiltInMenu(ID: Integer): IAIMPMenuItem;
var
  AMenuService: IAIMPServiceMenuManager;
begin
  CheckResult(CoreIntf.QueryInterface(IAIMPServiceMenuManager, AMenuService));
  CheckResult(AMenuService.GetBuiltIn(ID, Result));
end;
{--------------------------------------------------------------------}
procedure TASPlugin.CreateContextMenu;
var
  ASContextMenuParent: IAIMPMenuItem;
  ASContextMenu: IAIMPMenuItem;
begin
try
  // Create parent menu
  CheckResult(CoreIntf.CreateObject(IID_IAIMPMenuItem, ASContextMenuParent));
  CheckResult(ASContextMenuParent.SetValueAsObject(AIMP_MENUITEM_PROPID_ID,
                                          MakeString(AS_CONTEXTMENU_ID_PARENT)));
  CheckResult(ASContextMenuParent.SetValueAsObject(AIMP_MENUITEM_PROPID_NAME,
                                          MakeString(AS_CONTEXTMENU_CAPTION)));
  CheckResult(ASContextMenuParent.SetValueAsInt32(AIMP_MENUITEM_PROPID_STYLE,
                                          AIMP_MENUITEM_STYLE_NORMAL));
  CheckResult(ASContextMenuParent.SetValueAsObject(AIMP_MENUITEM_PROPID_PARENT,
                    GetBuiltInMenu(AIMP_MENUID_PLAYER_PLAYLIST_MISCELLANEOUS)));
  // Register the menu item in manager
  CheckResult(CoreIntf.RegisterExtension(IID_IAIMPServiceMenuManager, ASContextMenuParent));

  // Create menu "Enable"
  CheckResult(CoreIntf.CreateObject(IID_IAIMPMenuItem, ASContextMenu));
  CheckResult(ASContextMenu.SetValueAsObject(AIMP_MENUITEM_PROPID_ID,
                                          MakeString(AS_CONTEXTMENU_ID_ENABLE)));
  CheckResult(ASContextMenu.SetValueAsObject(AIMP_MENUITEM_PROPID_NAME,
                       MakeString(LangLoadString(AS_CONTEXTMENU_KEYPATH_ENABLE))));
  CheckResult(ASContextMenu.SetValueAsInt32(AIMP_MENUITEM_PROPID_STYLE,
                                          AIMP_MENUITEM_STYLE_CHECKBOX));
  CheckResult(ASContextMenu.SetValueAsObject(AIMP_MENUITEM_PROPID_PARENT,
                                          ASContextMenuParent));
  CheckResult(ASContextMenu.SetValueAsObject(AIMP_MENUITEM_PROPID_EVENT,
                                          TASMenuEnableHandler.Create));
  CheckResult(ASContextMenu.SetValueAsObject(AIMP_MENUITEM_PROPID_EVENT_ONSHOW,
                                          TASMenuEnableOnShowHandler.Create));
  // Register the menu item in manager
  CheckResult(CoreIntf.RegisterExtension(IID_IAIMPServiceMenuManager, ASContextMenu));

  // Creatind the menu delimiter
  CheckResult(CoreIntf.CreateObject(IID_IAIMPMenuItem, ASContextMenu));
  CheckResult(ASContextMenu.SetValueAsObject(AIMP_MENUITEM_PROPID_NAME,
                                          MakeString('-')));
  CheckResult(ASContextMenu.SetValueAsObject(AIMP_MENUITEM_PROPID_PARENT,
                                          ASContextMenuParent));
  // Register the menu item in manager
  CheckResult(CoreIntf.RegisterExtension(IID_IAIMPServiceMenuManager, ASContextMenu));

  // Create menu "SkipFavorite"
  CheckResult(CoreIntf.CreateObject(IID_IAIMPMenuItem, ASContextMenu));
  CheckResult(ASContextMenu.SetValueAsObject(AIMP_MENUITEM_PROPID_ID,
                              MakeString(AS_CONTEXTMENU_ID_SKIPFAVORITE)));
  CheckResult(ASContextMenu.SetValueAsObject(AIMP_MENUITEM_PROPID_NAME,
                MakeString(LangLoadString(AS_CONTEXTMENU_KEYPATH_SKIPFAVORITE))));
  CheckResult(ASContextMenu.SetValueAsInt32(AIMP_MENUITEM_PROPID_STYLE,
                                          AIMP_MENUITEM_STYLE_CHECKBOX));
  CheckResult(ASContextMenu.SetValueAsObject(AIMP_MENUITEM_PROPID_PARENT,
                                          ASContextMenuParent));
  CheckResult(ASContextMenu.SetValueAsObject(AIMP_MENUITEM_PROPID_EVENT,
                                  TASMenuSkipFavoriteHandler.Create));
  CheckResult(ASContextMenu.SetValueAsObject(AIMP_MENUITEM_PROPID_EVENT_ONSHOW,
                                  TASMenuSkipFavoriteOnShowHandler.Create));
  // Register the menu item in manager
  CheckResult(CoreIntf.RegisterExtension(IID_IAIMPServiceMenuManager, ASContextMenu));

  // Create menu "WaitForLibAnswer"
  CheckResult(CoreIntf.CreateObject(IID_IAIMPMenuItem, ASContextMenu));
  CheckResult(ASContextMenu.SetValueAsObject(AIMP_MENUITEM_PROPID_ID,
                              MakeString(AS_CONTEXTMENU_ID_WAITFORLIBANSWER)));
  CheckResult(ASContextMenu.SetValueAsObject(AIMP_MENUITEM_PROPID_NAME,
                MakeString(LangLoadString(AS_CONTEXTMENU_KEYPATH_WAITFORLIBANSWER))));
  CheckResult(ASContextMenu.SetValueAsInt32(AIMP_MENUITEM_PROPID_STYLE,
                                          AIMP_MENUITEM_STYLE_CHECKBOX));
  CheckResult(ASContextMenu.SetValueAsObject(AIMP_MENUITEM_PROPID_PARENT,
                                          ASContextMenuParent));
  CheckResult(ASContextMenu.SetValueAsObject(AIMP_MENUITEM_PROPID_EVENT,
                                  TASMenuWaitForLibAnswerHandler.Create));
  CheckResult(ASContextMenu.SetValueAsObject(AIMP_MENUITEM_PROPID_EVENT_ONSHOW,
                                  TASMenuWaitForLibAnswerOnShowHandler.Create));
  // Register the menu item in manager
  CheckResult(CoreIntf.RegisterExtension(IID_IAIMPServiceMenuManager, ASContextMenu));
except
  ShowErrorMessage('"CreateContextMenu" failure!');
end;
end;

{=========================================================================)
                              TASMessageHook
(=========================================================================}
procedure TASMessageHook.CoreMessage(Message: DWORD; Param1: Integer;
  Param2: Pointer; var Result: HRESULT);
var
  ServicePlayer: IAIMPServicePlayer;
  ActiveItem: IAIMPPlaylistItem;
  ActiveItemName: IAIMPString;

  ServiceMenuManager: IAIMPServiceMenuManager;
  MenuItem: IAIMPMenuItem;
begin
try
  case Message  of
    AIMP_MSG_EVENT_STREAM_START:
      begin
        if not IsWaitForLibAnswer
        then
          DisableActivePlaylistItem;

        CheckResult(CoreIntf.QueryInterface(IID_IAIMPServicePlayer, ServicePlayer));
        if ServicePlayer.GetPlaylistItem(ActiveItem) = S_OK
        then
          LastPlaylistItem := ActiveItem;
      end;
    AIMP_MSG_EVENT_LANGUAGE:
      begin
        // Update menu names
        CheckResult(CoreIntf.QueryInterface(IID_IAIMPServiceMenuManager,
                                          ServiceMenuManager));

        CheckResult(ServiceMenuManager.GetByID(MakeString(AS_CONTEXTMENU_ID_ENABLE),
                                          MenuItem));
        CheckResult(MenuItem.SetValueAsObject(AIMP_MENUITEM_PROPID_NAME,
                      MakeString(LangLoadString(AS_CONTEXTMENU_KEYPATH_ENABLE))));

        CheckResult(ServiceMenuManager.GetByID(MakeString(AS_CONTEXTMENU_ID_SKIPFAVORITE),
                                          MenuItem));
        CheckResult(MenuItem.SetValueAsObject(AIMP_MENUITEM_PROPID_NAME,
                      MakeString(LangLoadString(AS_CONTEXTMENU_KEYPATH_SKIPFAVORITE))));

        CheckResult(ServiceMenuManager.GetByID(MakeString(AS_CONTEXTMENU_ID_WAITFORLIBANSWER),
                                          MenuItem));
        CheckResult(MenuItem.SetValueAsObject(AIMP_MENUITEM_PROPID_NAME,
                      MakeString(LangLoadString(AS_CONTEXTMENU_KEYPATH_WAITFORLIBANSWER))));
      end;
    AIMP_MSG_EVENT_STATISTICS_CHANGED:
      begin
        if  IsWaitForLibAnswer
        then
          try
            // Checking if we got message from right source
            CheckResult(CoreIntf.QueryInterface(IID_IAIMPServicePlayer, ServicePlayer));
            if ServicePlayer.GetPlaylistItem(ActiveItem) <> S_OK
            then
              exit; // If the ActiveItem don't exists then we got message from wrong source
            CheckResult(ActiveItem.GetValueAsObject(AIMP_PLAYLISTITEM_PROPID_FILENAME, IID_IAIMPString, ActiveItemName));

            if PWideChar(Param2) = IAIMPStringToString(ActiveItemName)
            then  // If the Param2 <> ActiveItemName then we got message from wrong source
              DisableActivePlaylistItem;
          except
            ShowErrorMessage('"EVENT_STATISTICS_CHANGED" failure!');
          end;
      end
  end;
except
  ShowErrorMessage('"MessageHook.CoreMessage" failure!');
end;
end;

{=========================================================================)
                         TASMenuEnableOnShowHandler
(=========================================================================}
procedure TASMenuEnableOnShowHandler.OnExecute(Data: IInterface);
var
  ServiceMenuManager: IAIMPServiceMenuManager;
  MenuItem: IAIMPMenuItem;
begin
try
  // Update the Menu status for active playlist
  CheckResult(CoreIntf.QueryInterface(IID_IAIMPServiceMenuManager,
                                          ServiceMenuManager));
  CheckResult(ServiceMenuManager.GetByID(MakeString(AS_CONTEXTMENU_ID_ENABLE),
                                          MenuItem));
  CheckResult(MenuItem.SetValueAsInt32(AIMP_MENUITEM_PROPID_CHECKED,
                          Integer(IsPlaylistHandled(GetActivePlaylistID))));
except
  ShowErrorMessage('"MenuEnableOnShowHandler.Execute" failure!');
end;
end;

{=========================================================================)
                     TASMenuSkipFavoriteOnShowHandler
(=========================================================================}
procedure TASMenuSkipFavoriteOnShowHandler.OnExecute(Data: IInterface);
var
  ServiceMenuManager: IAIMPServiceMenuManager;
  MenuItem: IAIMPMenuItem;
begin
try
  // Update the Menu status
  CheckResult(CoreIntf.QueryInterface(IID_IAIMPServiceMenuManager,
                                          ServiceMenuManager));
  CheckResult(ServiceMenuManager.GetByID(MakeString(AS_CONTEXTMENU_ID_SKIPFAVORITE),
                                          MenuItem));
  CheckResult(MenuItem.SetValueAsInt32(AIMP_MENUITEM_PROPID_CHECKED,
                                          Integer(IsSkipFavorite)));
  CheckResult(MenuItem.SetValueAsInt32(AIMP_MENUITEM_PROPID_ENABLED,
                              Integer(IsPlaylistHandled(GetActivePlaylistID))));
except
  ShowErrorMessage('"SkipFavoriteOnShowHandler.OnExecute" failure!');
end;
end;

{=========================================================================)
                    TASMenuWaitForLibAnswerOnShowHandler
(=========================================================================}
procedure TASMenuWaitForLibAnswerOnShowHandler.OnExecute(Data: IInterface);
var
  ServiceMenuManager: IAIMPServiceMenuManager;
  MenuItem: IAIMPMenuItem;
begin
try
  // Update the Menu status
  CheckResult(CoreIntf.QueryInterface(IID_IAIMPServiceMenuManager,
                                          ServiceMenuManager));
  CheckResult(ServiceMenuManager.GetByID(MakeString(AS_CONTEXTMENU_ID_WAITFORLIBANSWER),
                                          MenuItem));
  CheckResult(MenuItem.SetValueAsInt32(AIMP_MENUITEM_PROPID_CHECKED,
                                          Integer(IsWaitForLibAnswer)));
  CheckResult(MenuItem.SetValueAsInt32(AIMP_MENUITEM_PROPID_ENABLED,
                              Integer(IsPlaylistHandled(GetActivePlaylistID))));
except
  ShowErrorMessage('"WaitForLibAnswerOnShowHandler.OnExecute" failure!');
end;
end;

{=========================================================================)
                             TASMenuEnableHandler
(=========================================================================}
procedure TASMenuEnableHandler.OnExecute(Data: IInterface);
begin
try
  TogglePlaylistStatus(GetActivePlaylistID);
except
  ShowErrorMessage('"MenuEnableHandler.OnExecute" failure!');
end;
end;

{=========================================================================)
                         TASMenuSkipFavoriteHandler
(=========================================================================}
procedure TASMenuSkipFavoriteHandler.OnExecute(Data: IInterface);
begin
try
  ToggleSkipFavoriteStatus;
except
  ShowErrorMessage('"SkipFavoriteHandler.OnExecute" failure!');
end;
end;

{=========================================================================)
                       TASMenuWaitForLibAnswerHandler
(=========================================================================}
procedure TASMenuWaitForLibAnswerHandler.OnExecute(Data: IInterface);
begin
try
  ToggleWaitForLibAnswerStatus;
except
  ShowErrorMessage('"WaitForLibAnswerHandler.OnExecute" failure!');
end;
end;

{=========================================================================)
                                  THE END
(=========================================================================}

end.
