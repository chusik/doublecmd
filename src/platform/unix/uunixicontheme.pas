{
    Double Commander
    -------------------------------------------------------------------------
    Some useful functions for Icon Theme implementation

    Copyright (C) 2009-2014  Alexander Koblov (alexx2000@mail.ru)

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}

unit uUnixIconTheme;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uIconTheme;

const
  DEFAULT_THEME_NAME: String = 'hicolor';
  DEFAULT_THEME_KDE4: String = 'default.kde4';

type

  { TUnixIconTheme }

  TUnixIconTheme = class(TIconTheme)
  protected
    function CreateParentTheme(const sThemeName: String): TIconTheme; override;
  public
    constructor Create; reintroduce;
    constructor Create(sThemeName: String; BaseDirList: array of String); override;
    function Load: Boolean; override;
  end;

implementation

uses
  DOM, XMLRead, DCClassesUtf8, uMyUnix, DCOSUtils, uOSUtils;

function GetKdeIconTheme: String;
const
  kde3Config = '/.kde/share/config/kdeglobals';
  kde4Config = '/.kde4/share/config/kdeglobals';
var
  kdeConfig: array[1..2] of String = (kde4Config, kde3Config);
  I: Integer;
  iniCfg: TIniFileEx = nil;
begin
  Result:= EmptyStr;
  for I:= Low(kdeConfig) to High(kdeConfig) do
  begin
    if (Length(Result) = 0) and mbFileExists(GetHomeDir + kdeConfig[I]) then
    try
      iniCfg:= TIniFileEx.Create(GetHomeDir + kdeConfig[I]);
      try
        Result:= iniCfg.ReadString('Icons', 'Theme', EmptyStr);
      finally
        iniCfg.Free;
      end;
    except
      // Skip
    end;
  end;
  if (Length(Result) = 0) and mbDirectoryExists('/usr/share/icons/default.kde4') then
    Result:= 'default.kde4'
  else if (Length(Result) = 0) and mbDirectoryExists('/usr/share/icons/default.kde') then
    Result:= 'default.kde';
end;

function GetGnomeIconTheme: String;
const
  gnomeConfig = '/.gconf/desktop/gnome/interface/%gconf.xml';
var
  I: Integer;
  ChildNode: TDOMNode;
  xmlCfg: TXMLDocument = nil;
begin
  Result:= EmptyStr;
  if mbFileExists(GetHomeDir + gnomeConfig) then
  try
    ReadXMLFile(xmlCfg, GetHomeDir + gnomeConfig);
    try
      for I := 0 to xmlCfg.DocumentElement.ChildNodes.Count -1 do
        begin
          ChildNode := xmlCfg.DocumentElement.ChildNodes.Item[I];
          if (ChildNode.NodeName = 'entry') then
            if (ChildNode.Attributes.Length > 0) and (ChildNode.Attributes[0].NodeValue = 'icon_theme') then
              begin
                Result:= ChildNode.FirstChild.FirstChild.NodeValue;
                Break;
              end;
        end;
    finally
      xmlCfg.Free;
    end;
  except
    // Skip
  end;
  if Length(Result) = 0 then
    Result:= 'gnome';
end;

function GetXfceIconTheme: String;
const
  xfceConfig = '/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml';
var
  J, I: Integer;
  ChildNode1,
  ChildNode2: TDOMNode;
  xmlCfg: TXMLDocument = nil;
begin
  Result:= EmptyStr;
  if mbFileExists(GetHomeDir + xfceConfig) then
  try
    ReadXMLFile(xmlCfg, GetHomeDir + xfceConfig);
    try
      for J := 0 to xmlCfg.DocumentElement.ChildNodes.Count -1 do
        begin
          ChildNode1:= xmlCfg.DocumentElement.ChildNodes.Item[J];
          if (ChildNode1.NodeName = 'property') then
            if (ChildNode1.Attributes.Length > 0) and (ChildNode1.Attributes[0].NodeValue = 'Net') then
              for I:= 0 to ChildNode1.ChildNodes.Count - 1 do
                begin
                  ChildNode2 := ChildNode1.ChildNodes.Item[I];
                  if (ChildNode2.NodeName = 'property') then
                    if (ChildNode2.Attributes.Length > 2) and (ChildNode2.Attributes[0].NodeValue = 'IconThemeName') then
                      begin
                        Result:= ChildNode2.Attributes[2].NodeValue;
                        Exit;
                      end;
                end;
        end;
    finally
      xmlCfg.Free;
    end;
  except
    // Skip
  end;
end;

function GetLxdeIconTheme: String;
const
  lxdeConfig1 = '/.config/lxsession/%s/desktop.conf';
  lxdeConfig2 = '/etc/xdg/lxsession/%s/desktop.conf';
var
  I: Integer;
  DesktopSession: String;
  iniCfg: TIniFileEx = nil;
  lxdeConfig: array[1..2] of String = (lxdeConfig1, lxdeConfig2);
begin
  Result:= EmptyStr;
  DesktopSession:= mbGetEnvironmentVariable('DESKTOP_SESSION');
  if Length(DesktopSession) <> 0 then
  begin
    lxdeConfig[1]:= GetHomeDir + Format(lxdeConfig[1], [DesktopSession]);
    lxdeConfig[2]:= Format(lxdeConfig[2], [DesktopSession]);
    for I:= Low(lxdeConfig) to High(lxdeConfig) do
    begin
      if (Length(Result) = 0) and mbFileExists(lxdeConfig[I]) then
      try
        iniCfg:= TIniFileEx.Create(lxdeConfig[I]);
        try
          Result:= iniCfg.ReadString('GTK', 'sNet/IconThemeName', EmptyStr);
        finally
          iniCfg.Free;
        end;
      except
        // Skip
      end;
    end;
  end;
end;

function GetCurrentIconTheme: String;
begin
  Result:= EmptyStr;
  case DesktopEnv of
    DE_UNKNOWN:
      Result:= DEFAULT_THEME_NAME;
    DE_KDE:
      Result:= GetKdeIconTheme;
    DE_GNOME:
      Result:= GetGnomeIconTheme;
    DE_XFCE:
      Result:= GetXfceIconTheme;
    DE_LXDE:
      Result:= GetLxdeIconTheme;
  end;
  if Result = EmptyStr then
    Result:= DEFAULT_THEME_NAME;
end;

var
  UnixIconThemesBaseDirList: array of String;

procedure InitIconThemesBaseDirList;
var
  Home: String;
  I: Integer = 1;
begin
  Home := GetHomeDir;
  SetLength(UnixIconThemesBaseDirList, 6);
  UnixIconThemesBaseDirList[0] := Home + '/.icons';
  UnixIconThemesBaseDirList[1] := Home + '/.local/share/icons';
  if DesktopEnv = DE_KDE then
  begin
    I:= 3;
    SetLength(UnixIconThemesBaseDirList, 8);
    UnixIconThemesBaseDirList[2] := Home + '/.kde/share/icons';
    UnixIconThemesBaseDirList[3] := Home + '/.kde4/share/icons';
  end;
  UnixIconThemesBaseDirList[I + 1] := '/usr/local/share/icons';
  UnixIconThemesBaseDirList[I + 2] := '/usr/local/share/pixmaps';
  UnixIconThemesBaseDirList[I + 3] := '/usr/share/icons';
  UnixIconThemesBaseDirList[I + 4] := '/usr/share/pixmaps';
end;

{ TUnixIconTheme }

function TUnixIconTheme.CreateParentTheme(const sThemeName: String): TIconTheme;
begin
  Result:= TUnixIconTheme.Create(sThemeName, FBaseDirListAtCreate);
end;

constructor TUnixIconTheme.Create;
begin
  inherited Create(GetCurrentIconTheme, UnixIconThemesBaseDirList);
end;

constructor TUnixIconTheme.Create(sThemeName: String;
  BaseDirList: array of String);
begin
  inherited Create(sThemeName, BaseDirList);
end;

function TUnixIconTheme.Load: Boolean;
begin
  Result:= inherited Load;
  // add default theme if needed
  if Result and Assigned(FInherits) then
  begin
    LoadParentTheme(DEFAULT_THEME_NAME);
    if (DesktopEnv = DE_KDE) then LoadParentTheme(DEFAULT_THEME_KDE4);
  end;
end;

initialization
  InitIconThemesBaseDirList;

end.

