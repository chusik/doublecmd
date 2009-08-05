{
   Seksi Commander
   ----------------------------
   Implementing of progress dialog for file operation

   Licence  : GNU GPL v 2.0
   Author   : radek.cervinka@centrum.cz

   contributors:

   Copyright (C) 2008-2009  Koblov Alexander (Alexx2000@mail.ru)
}

unit fFileOpDlg;

{$mode objfpc}{$H+}

interface

uses
  LResources,
  SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, Buttons, ExtCtrls,
  uOperationsManager, uFileSourceOperation, uFileSourceOperationUI;

type

  TFileOpDlgLook = set of (fodl_from_lbl, fodl_to_lbl, fodl_first_pb, fodl_second_pb);


  { TfrmFileOp }

  TfrmFileOp = class(TForm)
    btnPauseStart: TBitBtn;
    btnWorkInBackground: TButton;
    lblFrom: TLabel;
    lblTo: TLabel;
    lblFileNameTo: TLabel;
    pbSecond: TProgressBar;
    pbFirst: TProgressBar;
    lblFileNameFrom: TLabel;
    lblEstimated: TLabel;
    btnCancel: TBitBtn;
    procedure btnCancelClick(Sender: TObject);
    procedure btnPauseStartClick(Sender: TObject);
    procedure btnWorkInBackgroundClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);

  private
    { Private declarations }
    FOperationHandle: TOperationHandle;
    FUpdateTimer: TTimer;  //<en Timer for updating statistics.
    FUserInterface: TFileSourceOperationUI;
    FStopOperationOnClose: Boolean;

    procedure OnUpdateTimer(Sender: TObject);

    procedure InitializeControls(FileOpDlgLook: TFileOpDlgLook);
    procedure SetPauseGlyph;
    procedure SetPlayGlyph;
    procedure UpdatePauseStartButton(OperationState: TFileSourceOperationState);
    procedure SetProgress(ProgressBar: TProgressBar; CurrentValue: Int64; MaxValue: Int64);
    procedure SetSpeedAndTime(Operation: TFileSourceOperation; RemainingTime: TDateTime; Speed: String);

    procedure InitializeCopyOperation(Operation: TFileSourceOperation);
    procedure InitializeDeleteOperation(Operation: TFileSourceOperation);
    procedure InitializeWipeOperation(Operation: TFileSourceOperation);
    procedure InitializeCalcChecksumOperation(Operation: TFileSourceOperation);
    procedure UpdateCopyOperation(Operation: TFileSourceOperation);
    procedure UpdateDeleteOperation(Operation: TFileSourceOperation);
    procedure UpdateWipeOperation(Operation: TFileSourceOperation);
    procedure UpdateCalcChecksumOperation(Operation: TFileSourceOperation);

  public
    iProgress1Max: Integer;
    iProgress1Pos: Integer;
    iProgress2Max: Integer;
    iProgress2Pos: Integer;
    sEstimated: ShortString;  // bugbug, must be short string
    sFileNameFrom,
    sFileNameTo: String;
    Thread: TThread;

    // Change to override later.
    constructor Create(OperationHandle: TOperationHandle); overload;
    destructor Destroy; override;

    function CloseQuery: Boolean; override;

    procedure ToggleProgressBarStyle;
    procedure UpdateDlg;
  end;

implementation

uses
   fMain, dmCommonData, uFileOpThread, LCLProc, uLng, uDCUtils,
   uFileSourceOperationTypes,
   uFileSourceCopyOperation,
   uFileSourceDeleteOperation,
   uFileSourceWipeOperation,
   uFileSourceCalcChecksumOperation,
   uFileSourceOperationMessageBoxesUI;

procedure TfrmFileOp.btnCancelClick(Sender: TObject);
var
  Operation: TFileSourceOperation;
begin
  Operation := OperationsManager.GetOperationByHandle(FOperationHandle);
  if Assigned(Operation) then
  begin
    Operation.Stop;
  end;

  ModalResult:= mrCancel;
end;

procedure TfrmFileOp.btnPauseStartClick(Sender: TObject);
var
  Operation: TFileSourceOperation;
begin
  Operation := OperationsManager.GetOperationByHandle(FOperationHandle);
  if Assigned(Operation) then
  begin
    if Operation.State in [fsosNotStarted, fsosPaused] then
    begin
      Operation.Start;
      SetPauseGlyph;
    end
    else if Operation.State = fsosRunning then
    begin
      Operation.Pause;
      SetPlayGlyph;
    end;
  end;
end;

procedure TfrmFileOp.btnWorkInBackgroundClick(Sender: TObject);
begin
  FStopOperationOnClose := False;
  Close;
end;

procedure TfrmFileOp.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  CloseAction:= caFree;
end;

procedure TfrmFileOp.FormCreate(Sender: TObject);
var
  Operation: TFileSourceOperation;
begin
  Thread:= nil;

  pbFirst.DoubleBuffered:= True;
  pbSecond.DoubleBuffered:= True;
  Self.DoubleBuffered:= True;

  Operation := OperationsManager.GetOperationByHandle(FOperationHandle);
  if Assigned(Operation) then
  begin
    case Operation.ID of

      fsoCopyIn, fsoCopyOut:
        InitializeCopyOperation(Operation);
      fsoDelete:
        InitializeDeleteOperation(Operation);
      fsoWipe:
        InitializeWipeOperation(Operation);
      fsoCalcChecksum:
        InitializeCalcChecksumOperation(Operation);

      else
        begin
          Caption := 'Unknown operation';
          InitializeControls([fodl_first_pb]);
        end;
    end;

    UpdatePauseStartButton(Operation.State);
  end
  else
  begin
    Caption := 'Invalid operation';
  end;

  FUpdateTimer := TTimer.Create(Self);
  FUpdateTimer.Interval := 100;
  FUpdateTimer.OnTimer := @OnUpdateTimer;
  FUpdateTimer.Enabled := True;
end;

procedure TfrmFileOp.FormShow(Sender: TObject);
begin
  sEstimated:= '';
  sFileNameFrom:= '';
  sFileNameTo:= '';
end;

constructor TfrmFileOp.Create(OperationHandle: TOperationHandle);
var
  Operation: TFileSourceOperation;
begin
  FOperationHandle := OperationHandle;
  inherited Create(Application);

  AutoSize := True;

  FStopOperationOnClose := True;

  Operation := OperationsManager.GetOperationByHandle(FOperationHandle);
  if Assigned(Operation) then
  begin
    FUserInterface := TFileSourceOperationMessageBoxesUI.Create;
    Operation.AddUserInterface(FUserInterface);
  end
  else
    FUserInterface := nil;
end;

destructor TfrmFileOp.Destroy;
var
  Operation: TFileSourceOperation;
begin
  inherited Destroy;

  if Assigned(FUserInterface) then
  begin
    Operation := OperationsManager.GetOperationByHandle(FOperationHandle);
    if Assigned(Operation) then
      Operation.RemoveUserInterface(FUserInterface);

    FreeAndNil(FUserInterface);
  end;
end;

function TfrmFileOp.CloseQuery: Boolean;
var
  Operation: TFileSourceOperation;
begin
  Result := True;

  if FStopOperationOnClose then
  begin
    Operation := OperationsManager.GetOperationByHandle(FOperationHandle);
    if Assigned(Operation) and (Operation.State <> fsosStopped) then
    begin
      Result := False;
      Operation.Stop;
    end
  end;
end;

procedure TfrmFileOp.OnUpdateTimer(Sender: TObject);
var
  Operation: TFileSourceOperation;
  NewCaption: String;
begin
  Operation := OperationsManager.GetOperationByHandle(FOperationHandle);
  if Assigned(Operation) and (Operation.State <> fsosStopped) then
  begin
    case Operation.ID of

      fsoCopyOut:
        UpdateCopyOperation(Operation);
      fsoDelete:
        UpdateDeleteOperation(Operation);
      fsoWipe:
        UpdateWipeOperation(Operation);
      fsoCalcChecksum:
        UpdateCalcChecksumOperation(Operation);

      else
      begin
        // Operation not currently supported for display.
        // Only show general progress.
        pbFirst.Position := Operation.Progress;
      end;
    end;

    UpdatePauseStartButton(Operation.State);

    NewCaption := IntToStr(Operation.Progress) + '% ' + Hint;
    if Operation.State <> fsosRunning then
      NewCaption := NewCaption + ' [' + FileSourceOperationStateText[Operation.State] + ']';
    Caption := NewCaption;
  end
  else
  begin
    // Operation has finished.
    // if CloseOnFinish then
    Close;
    // if BeepOnFinish then Beep;
  end;
end;

procedure TfrmFileOp.InitializeControls(FileOpDlgLook: TFileOpDlgLook);
begin
  lblFrom.Visible         := fodl_from_lbl in FileOpDlgLook;
  lblFileNameFrom.Visible := fodl_from_lbl in FileOpDlgLook;
  lblTo.Visible           := fodl_to_lbl in FileOpDlgLook;
  lblFileNameTo.Visible   := fodl_to_lbl in FileOpDlgLook;
  pbFirst.Visible         := fodl_first_pb in FileOpDlgLook;
  pbSecond.Visible        := fodl_second_pb in FileOpDlgLook;

  lblFileNameFrom.Caption := '';
  lblFileNameTo.Caption := '';
  lblEstimated.Caption := '';

  Hint := Caption;
end;

procedure TfrmFileOp.SetPauseGlyph;
begin
  dmComData.ImageList.GetBitmap(1, btnPauseStart.Glyph);
end;

procedure TfrmFileOp.SetPlayGlyph;
begin
  dmComData.ImageList.GetBitmap(0, btnPauseStart.Glyph);
end;

procedure TfrmFileOp.UpdatePauseStartButton(OperationState: TFileSourceOperationState);
begin
  case OperationState of
    fsosNotStarted, fsosStopped, fsosPaused:
      begin
        btnPauseStart.Enabled := True;
        SetPlayGlyph;
      end;

    fsosStarting, fsosStopping, fsosPausing, fsosWaitingForFeedback:
      begin
        btnPauseStart.Enabled := False;
      end;

    fsosRunning:
      begin
        btnPauseStart.Enabled := True;
        SetPauseGlyph;
      end;

    else
      btnPauseStart.Enabled := False;
  end;
end;

procedure TfrmFileOp.SetProgress(ProgressBar: TProgressBar; CurrentValue: Int64; MaxValue: Int64);
begin
  if MaxValue <> 0 then
    ProgressBar.Position := (CurrentValue * 100) div MaxValue
  else
    ProgressBar.Position := 0;
end;

procedure TfrmFileOp.SetSpeedAndTime(Operation: TFileSourceOperation; RemainingTime: TDateTime; Speed: String);
begin
  if Operation.State <> fsosRunning then
    sEstimated := ''
  else
  begin
    sEstimated := FormatDateTime('HH:MM:SS', RemainingTime);
    sEstimated := Format(rsDlgSpeedTime, [Speed, sEstimated]);
  end;

  lblEstimated.Caption := sEstimated;
end;

procedure TfrmFileOp.InitializeCopyOperation(Operation: TFileSourceOperation);
var
  CopyOperation: TFileSourceCopyOperation;
begin
  //CopyOperation := Operation as TFileSourceCopyOperation;
  Caption := rsDlgCp;
  InitializeControls([fodl_from_lbl, fodl_to_lbl, fodl_first_pb, fodl_second_pb]);
end;

procedure TfrmFileOp.InitializeDeleteOperation(Operation: TFileSourceOperation);
begin
  Caption := rsDlgDel;
  InitializeControls([fodl_from_lbl, fodl_first_pb]);
  lblFrom.Caption := rsDlgDeleting;
end;

procedure TfrmFileOp.InitializeWipeOperation(Operation: TFileSourceOperation);
begin
  Caption := rsDlgWipe;
  InitializeControls([fodl_from_lbl, fodl_first_pb, fodl_second_pb]);
  lblFrom.Caption := rsDlgDeleting;
end;

procedure TfrmFileOp.InitializeCalcChecksumOperation(Operation: TFileSourceOperation);
begin
  Caption := rsDlgCheckSumCalc;
  InitializeControls([fodl_from_lbl, fodl_first_pb, fodl_second_pb]);
  lblFrom.Visible := False;
end;

procedure TfrmFileOp.UpdateCopyOperation(Operation: TFileSourceOperation);
var
  CopyOperation: TFileSourceCopyOperation;
  CopyStatistics: TFileSourceCopyOperationStatistics;
begin
  CopyOperation := Operation as TFileSourceCopyOperation;
  CopyStatistics := CopyOperation.RetrieveStatistics;

  with CopyStatistics do
  begin
    lblFileNameFrom.Caption := CurrentFileFrom;
    lblFileNameTo.Caption := CurrentFileTo;

    SetProgress(pbFirst, CurrentFileDoneBytes, CurrentFileTotalBytes);
    SetProgress(pbSecond, DoneBytes, TotalBytes);
    SetSpeedAndTime(Operation, RemainingTime, cnvFormatFileSize(BytesPerSecond));
  end;
end;

procedure TfrmFileOp.UpdateDeleteOperation(Operation: TFileSourceOperation);
var
  DeleteOperation: TFileSourceDeleteOperation;
  DeleteStatistics: TFileSourceDeleteOperationStatistics;
begin
  DeleteOperation := Operation as TFileSourceDeleteOperation;
  DeleteStatistics := DeleteOperation.RetrieveStatistics;

  with DeleteStatistics do
  begin
    lblFileNameFrom.Caption := CurrentFile;

    SetProgress(pbFirst, DoneFiles, TotalFiles);
    SetSpeedAndTime(Operation, RemainingTime, IntToStr(FilesPerSecond));
  end;
end;

procedure TfrmFileOp.UpdateWipeOperation(Operation: TFileSourceOperation);
var
  WipeOperation: TFileSourceWipeOperation;
  WipeStatistics: TFileSourceWipeOperationStatistics;
begin
  WipeOperation := Operation as TFileSourceWipeOperation;
  WipeStatistics := WipeOperation.RetrieveStatistics;

  with WipeStatistics do
  begin
    lblFileNameFrom.Caption := CurrentFile;

    SetProgress(pbFirst, CurrentFileDoneBytes, CurrentFileTotalBytes);
    SetProgress(pbSecond, DoneBytes, TotalBytes);
    SetSpeedAndTime(Operation, RemainingTime, cnvFormatFileSize(BytesPerSecond));
  end;
end;

procedure TfrmFileOp.UpdateCalcChecksumOperation(Operation: TFileSourceOperation);
var
  CalcChecksumOperation: TFileSourceCalcChecksumOperation;
  CalcChecksumStatistics: TFileSourceCalcChecksumOperationStatistics;
begin
  CalcChecksumOperation := Operation as TFileSourceCalcChecksumOperation;
  CalcChecksumStatistics := CalcChecksumOperation.RetrieveStatistics;

  with CalcChecksumStatistics do
  begin
    lblFileNameFrom.Caption := CurrentFile;

    SetProgress(pbFirst, CurrentFileDoneBytes, CurrentFileTotalBytes);
    SetProgress(pbSecond, DoneBytes, TotalBytes);
    SetSpeedAndTime(Operation, RemainingTime, cnvFormatFileSize(BytesPerSecond));
  end;
end;

procedure TfrmFileOp.ToggleProgressBarStyle;
begin
  if (pbFirst.Style = pbstMarquee) and (pbSecond.Style = pbstMarquee) then
    begin
      pbFirst.Style:= pbstNormal;
      pbSecond.Style:= pbstNormal;
    end
  else
    begin
      pbFirst.Style:= pbstMarquee;
      pbSecond.Style:= pbstMarquee;
    end;
end;

procedure TfrmFileOp.UpdateDlg;
var
  bP1, bP2: Boolean; // repaint if needed
begin
// in processor intensive task we force repaint immedially
  bP1:= False;
  bP2:= False;

  if pbFirst.Max<> iProgress1Max then
  begin
    if iProgress1Max > 0 then
      pbFirst.Max:= iProgress1Max;
    bP1:= True;
  end;
  if pbFirst.Position <> iProgress1Pos then
  begin
    if iProgress1Pos >= 0 then
      pbFirst.Position:= iProgress1Pos;
    bP1:= True;
  end;

  if pbSecond.Max <> iProgress2Max then
  begin
    if iProgress2Max > 0 then
      pbSecond.Max:= iProgress2Max;
    bP2:= True;
  end;
  if pbSecond.Position <> iProgress2Pos then
  begin
    if iProgress2Pos > 0 then
      pbSecond.Position:= iProgress2Pos;
    bP2:= True;
  end;
  
  if bp1 then
    pbFirst.Invalidate;
  if bp2 then
    pbSecond.Invalidate;

  if bp2 then
    Caption:= IntToStr(iProgress2Pos) + '% ' + Hint;

  if sEstimated <> lblEstimated.Caption then
  begin
    lblEstimated.Caption:= sEstimated;
    lblEstimated.Invalidate;
  end;
  if sFileNameFrom <> lblFileNameFrom.Caption then
  begin
    lblFileNameFrom.Caption:= sFileNameFrom;
    lblFileNameFrom.Invalidate;
  end;
  if sFileNameTo <> lblFileNameTo.Caption then
  begin
    lblFileNameTo.Caption:= sFileNameTo;
    lblFileNameTo.Invalidate;
  end;
end;

initialization
 {$I fFileOpDlg.lrs}

end.
