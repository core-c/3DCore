object f3DS: Tf3DS
  Left = 134
  Top = 160
  BorderStyle = bsSingle
  Caption = 'Core'
  ClientHeight = 534
  ClientWidth = 666
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  Icon.Data = {
    0000010002002020100000000000E80200002600000010101000000000002801
    00000E0300002800000020000000400000000100040000000000800200000000
    0000000000000000000000000000000000000000800000800000008080008000
    0000800080008080000080808000C0C0C0000000FF0000FF000000FFFF00FF00
    0000FF00FF00FFFF0000FFFFFF00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
    FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
    FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
    FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
    FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
    FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
    FFFFFFFF88877778888FFFFFFFFFFFFFFFFFF87766666666666778FFFFFFFFFF
    FF87666666666777766666678FFFFFFFF76666667788FFFFFFFF887667FFFFF8
    66666678FFFFFFFFFFFFFFFF8778FF866666678FFFFFFFFFFFFFFFFFFF88FF66
    66666FFFFFFFFFFFFFFFFFFFFFFFF76666668FFFFFFFFFFFFFFFFFFFFFFFF666
    6668FFFFFFFFFFFFFFFFFFFFFFFF86666668FFFFFFFFFFFFFFFFFFFFFFFF8666
    6668FFFFFFFFFFFFFFFFFFFFFFFFF7666667FFFFFFFFFFFFFFFFFFFFFFFFF866
    66668FFFFFFFFFFFFFFFFFFFFFFFFF7666666FFFFFFFFFFFFFFFFFFFFFFFFFF7
    6666678FFFFFFFFFFFFFFFFFFF88FFFF766666788FFFFFFFFFFFFFFF877FFFFF
    F8766666777888FFFFF8887678FFFFFFFFF876666666666766666678FFFFFFFF
    FFFFF88776666666667788FFFFFFFFFFFFFFFFFFFF8888888FFFFFFFFFFFFFFF
    FFFFFFFFFFFFFFFFFFFFFFFFFFFF000000000000000000000000000000000000
    0000000000000000000000000000000000000000000000000000000000000000
    0000000000000000000000000000000000000000000000000000000000000000
    0000000000000000000000000000000000000000000000000000000000000000
    0000000000000000000000000000280000001000000020000000010004000000
    0000C00000000000000000000000000000000000000000000000000080000080
    00000080800080000000800080008080000080808000C0C0C0000000FF0000FF
    000000FFFF00FF000000FF00FF00FFFF0000FFFFFF00FFFFFFFFFFFFFFFFFFFF
    FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
    887777778FFFFF8766678887778FF86668FFFFFFF88886668FFFFFFFFFFF7667
    FFFFFFFFFFFF8667FFFFFFFFFFFFF6667FFFFFFFFFFFF86668FFFFFFFF88FFF8
    66677777778FFFFFF88777788FFFFFFFFFFFFFFFFFFF00000000000000000000
    0000000000000000000000000000000000000000000000000000000000000000
    00000000000000000000000000000000000000000000}
  Menu = MainMenu
  OldCreateOrder = False
  OnCreate = FormCreate
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 8
    Top = 112
    Width = 22
    Height = 13
    Caption = 'Tree'
  end
  object Memo: TMemo
    Left = 0
    Top = 8
    Width = 577
    Height = 97
    ScrollBars = ssVertical
    TabOrder = 0
    WordWrap = False
    OnDblClick = MemoDblClick
  end
  object bImport3DS: TButton
    Left = 584
    Top = 56
    Width = 75
    Height = 25
    Action = ActionImport3DS
    TabOrder = 1
  end
  object Tree3DS: TTreeView
    Left = 0
    Top = 128
    Width = 577
    Height = 385
    Indent = 19
    ReadOnly = True
    TabOrder = 2
    OnDblClick = Tree3DSDblClick
  end
  object StatusBar: TStatusBar
    Left = 0
    Top = 515
    Width = 666
    Height = 19
    Panels = <>
  end
  object bOpenGL: TButton
    Left = 584
    Top = 8
    Width = 75
    Height = 25
    Action = ActionDisplay
    TabOrder = 4
    OnMouseMove = bOpenGLMouseMove
  end
  object bSaveAsGM: TButton
    Left = 584
    Top = 80
    Width = 75
    Height = 25
    Action = ActionSaveAsGM
    Enabled = False
    TabOrder = 5
    Visible = False
  end
  object eFPS: TEdit
    Left = 584
    Top = 488
    Width = 73
    Height = 21
    Color = clBtnFace
    ReadOnly = True
    TabOrder = 6
  end
  object bLoadBSP: TButton
    Left = 584
    Top = 200
    Width = 75
    Height = 25
    Action = ActionLoadBSP
    TabOrder = 7
  end
  object bLoadMap: TButton
    Left = 584
    Top = 136
    Width = 75
    Height = 25
    Action = ActionLoadMap
    TabOrder = 8
  end
  object bClearMap: TButton
    Left = 584
    Top = 160
    Width = 75
    Height = 25
    Caption = 'Clear Map'
    TabOrder = 9
    OnClick = bClearMapClick
  end
  object bClearBSP: TButton
    Left = 584
    Top = 224
    Width = 75
    Height = 25
    Caption = 'Clear BSP'
    TabOrder = 10
    OnClick = bClearBSPClick
  end
  object bGenerateTerrain: TButton
    Left = 584
    Top = 264
    Width = 75
    Height = 25
    Action = ActionGenerateTerrain
    TabOrder = 11
  end
  object bClearTerrain: TButton
    Left = 584
    Top = 288
    Width = 75
    Height = 25
    Caption = 'Clear Terrain'
    TabOrder = 12
    OnClick = bClearTerrainClick
  end
  object ProgressBarClass: TProgressBar
    Left = 224
    Top = 519
    Width = 433
    Height = 6
    Hint = 'Class'
    ParentShowHint = False
    Smooth = True
    Step = 1
    ShowHint = True
    TabOrder = 13
  end
  object ProgressBarTotal: TProgressBar
    Left = 224
    Top = 526
    Width = 433
    Height = 6
    Hint = 'Total'
    ParentShowHint = False
    Smooth = True
    Step = 1
    ShowHint = True
    TabOrder = 14
  end
  object OpenDialog3DS: TOpenDialog
    DefaultExt = '.3ds'
    Filter = '3D-Studio file (*.3DS)|*.3ds'
    Options = [ofHideReadOnly, ofPathMustExist, ofFileMustExist, ofEnableSizing]
    Title = 'Import 3DS file'
    Left = 584
    Top = 416
  end
  object ActionList: TActionList
    Left = 616
    Top = 384
    object ActionImport3DS: TAction
      Caption = 'Import 3DS'
      OnExecute = ActionImport3DSExecute
    end
    object ActionSaveAsGM: TAction
      Caption = 'Save As GM'
      OnExecute = ActionSaveAsGMExecute
    end
    object ActionDisplay: TAction
      Caption = 'Display'
      OnExecute = ActionDisplayExecute
    end
    object ActionCloseGL: TAction
      Caption = 'CloseGL'
      OnExecute = ActionCloseGLExecute
    end
    object ActionDefaultCam: TAction
      Caption = 'Default Cam'
      OnExecute = ActionDefaultCamExecute
    end
    object ActionExit: TAction
      Caption = 'Exit'
      OnExecute = ActionExitExecute
    end
    object ActionLoadBSP: TAction
      Caption = 'Load BSP'
      OnExecute = ActionLoadBSPExecute
    end
    object ActionLoadMap: TAction
      Caption = 'Load Map'
      OnExecute = ActionLoadMapExecute
    end
    object ActionGenerateTerrain: TAction
      Caption = 'Gen. Terrain'
      OnExecute = ActionGenerateTerrainExecute
    end
  end
  object MainMenu: TMainMenu
    Left = 584
    Top = 384
    object MenuFile: TMenuItem
      Caption = '&File'
      object MenuExit: TMenuItem
        Action = ActionExit
      end
    end
  end
  object OpenDialogBSP: TOpenDialog
    DefaultExt = '.bsp'
    Filter = 'Quake3 BSP file (*.BSP)|*.bsp'
    Options = [ofReadOnly, ofFileMustExist, ofEnableSizing]
    Title = 'Load .BSP file'
    Left = 616
    Top = 416
  end
  object OpenDialogMAP: TOpenDialog
    DefaultExt = '.map'
    Filter = 'Level MAP file (*.MAP)|*.map'
    Options = [ofReadOnly, ofFileMustExist, ofEnableSizing]
    Title = 'Load .MAP file'
    Left = 616
    Top = 448
  end
end
