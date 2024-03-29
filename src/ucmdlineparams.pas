unit uCmdLineParams;

{$mode objfpc}{$H+}

interface

type
  TCommandLineParams = packed record
    NewTab: Boolean;
    ActivePanelSpecified: Boolean;
    ActiveRight: Boolean;
    LeftPath: array[0..1023] of AnsiChar;
    RightPath: array[0..1023] of AnsiChar;
    ActivePanelPath: array[0..1023] of AnsiChar;
    Client: Boolean;
    Servername: array[0..1023] of AnsiChar;
  end;

procedure ProcessCommandLineParams;

var
  CommandLineParams: TCommandLineParams;

implementation

uses
  Forms, Dialogs, SysUtils, uOSUtils, uDCUtils, uGlobsPaths, getopts, uDebug, uLng;

procedure ProcessCommandLineParams;
var
  Option: AnsiChar = #0;
  OptionIndex: LongInt = 0;
  Options: array[1..4] of TOption;
  OptionUnknown: UTF8String;
begin
  CommandLineParams.Servername := '';
  with Options[1] do
  begin
    Name:= 'no-console';
    Has_arg:= 0;
    Flag:= nil;
    Value:= #0;
  end;
  with Options[2] do
  begin
    Name:= 'config-dir';
    Has_arg:= 1;
    Flag:= nil;
    Value:= #0;
  end;
  with Options[3] do
  begin
    Name:= 'client';
    Has_arg:= 0;
    Flag:= nil;
    Value:= #0;
  end;
  with Options[4] do
  begin
    Name:= 'servername';
    Has_arg:= 1;
    Flag:= nil;
    Value:= #0;
  end;
  FillChar(CommandLineParams, SizeOf(TCommandLineParams), #0);
  repeat
    try
      Option:= GetLongOpts('L:l:R:r:P:p:TtCc', @Options[1], OptionIndex);
    except
      MessageDlg(Application.Title, rsMsgInvalidCommandLine, mtError, [mbOK], 0, mbOK);
      Exit;
    end;
    case Option of
      #0:
        begin
          case OptionIndex of
            1:
              begin
                {$IF DEFINED(NIGHTLY_BUILD)}
                HideConsoleWindow;
                {$ENDIF}
              end;
            2:
              begin
                gpCmdLineCfgDir:= ParamStrU(TrimQuotes(OptArg));
              end;
            3:
              begin
                CommandLineParams.Client:= True;
              end;
            4:
              begin
                CommandLineParams.Servername:= ParamStrU(TrimQuotes(OptArg));
              end;
          end;
        end;
      'L', 'l': CommandLineParams.LeftPath:= ParamStrU(TrimQuotes(OptArg));
      'R', 'r': CommandLineParams.RightPath:= ParamStrU(TrimQuotes(OptArg));
      'P', 'p': begin
        CommandLineParams.ActivePanelSpecified:= True;
        CommandLineParams.ActiveRight:= (UpperCase(OptArg) = 'R');
      end;
      'T', 't': CommandLineParams.NewTab:= True;
      'C', 'c': CommandLineParams.Client:= True;
      '?', ':': DCDebug ('Error with opt : ', OptOpt);
    end; { case }
  until Option = EndOfOptions;

  if OptInd <= ParamCount then
  begin
    // If also found one parameter then use it as path of active panel
    if ParamCount - OptInd = 0 then
      begin
        CommandLineParams.ActivePanelPath:= ParamStrU(OptInd);
        Inc(OptInd, 1);
      end
    // If also found two parameters then use it as paths in panels
    else if ParamCount - OptInd = 1 then
      begin
        CommandLineParams.LeftPath:= ParamStrU(OptInd);
        CommandLineParams.RightPath:= ParamStrU(OptInd + 1);
        Inc(OptInd, 2);
      end;
    // Unknown options, print to console
    if OptInd <= ParamCount then
    begin
      while OptInd <= ParamCount do
      begin
        OptionUnknown:= ParamStrU(OptInd) + ' ';
        Inc(OptInd)
      end;
      DCDebug ('Non options : ', OptionUnknown);
    end;
  end;
end;

end.
