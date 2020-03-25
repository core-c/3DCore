object fOpenGL: TfOpenGL
  Left = 624
  Top = 170
  HorzScrollBar.Visible = False
  VertScrollBar.Visible = False
  AutoScroll = False
  BorderIcons = [biMinimize, biMaximize]
  Caption = 'OpenGL'
  ClientHeight = 273
  ClientWidth = 392
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  FormStyle = fsStayOnTop
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
  OldCreateOrder = False
  PrintScale = poNone
  Scaled = False
  OnCanResize = FormCanResize
  OnClose = FormClose
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnKeyDown = FormKeyDown
  OnKeyUp = FormKeyUp
  OnMouseDown = FormMouseDown
  OnMouseMove = FormMouseMove
  OnPaint = FormPaint
  OnResize = FormResize
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object TimerFPS: TTimer
    OnTimer = TimerFPSTimer
    Left = 8
    Top = 8
  end
  object popupView: TPopupMenu
    Left = 40
    Top = 8
    object viewHelp: TMenuItem
      Caption = 'Help'
      GroupIndex = 1
      ShortCut = 112
    end
    object viewResetCamera: TMenuItem
      Caption = 'Reset Camera   (R)'
      GroupIndex = 1
    end
    object N3: TMenuItem
      Break = mbBreak
      Caption = '-'
      GroupIndex = 2
    end
    object viewFullScreen: TMenuItem
      Caption = 'Full Screen   (F)'
      GroupIndex = 2
      RadioItem = True
    end
    object viewWindowed: TMenuItem
      Caption = 'Windowed'
      Checked = True
      Default = True
      GroupIndex = 2
      RadioItem = True
    end
    object view800x600: TMenuItem
      Caption = '800x600'
      GroupIndex = 2
      RadioItem = True
    end
    object view1024x768: TMenuItem
      Caption = '1024x768'
      GroupIndex = 2
      RadioItem = True
    end
    object view1280x1024: TMenuItem
      Caption = '1280x1024'
      GroupIndex = 2
      RadioItem = True
    end
    object N1: TMenuItem
      Break = mbBreak
      Caption = '-'
      GroupIndex = 3
    end
    object viewMouseLook: TMenuItem
      Caption = 'Mouse Look   (M)'
      GroupIndex = 3
    end
    object viewTextures: TMenuItem
      Caption = 'Textures   (T)'
      Checked = True
      GroupIndex = 3
    end
    object viewLightMaps: TMenuItem
      Caption = 'Lightmaps   (L)'
      Checked = True
      GroupIndex = 3
    end
    object viewGravity: TMenuItem
      Caption = 'Gravity'
      GroupIndex = 3
      ShortCut = 117
    end
    object viewCollisions: TMenuItem
      Caption = 'Collisions   (C)'
      Checked = True
      GroupIndex = 3
      ShortCut = 118
    end
    object viewFog: TMenuItem
      Caption = 'Fog'
      Checked = True
      GroupIndex = 3
      ShortCut = 119
    end
    object viewSkyBox: TMenuItem
      Caption = 'Sky Box   (B)'
      Checked = True
      GroupIndex = 3
      ShortCut = 120
    end
    object viewHiddenLineRemoval: TMenuItem
      Caption = 'Hidden Lines Removal   (H)'
      GroupIndex = 3
      ShortCut = 121
    end
    object viewWireFrame: TMenuItem
      Caption = 'WireFrame'
      GroupIndex = 3
      ShortCut = 122
    end
    object viewPointFrame: TMenuItem
      Caption = 'PointFrame'
      GroupIndex = 3
      ShortCut = 123
    end
    object view1TU: TMenuItem
      Caption = 'Use 1 Texture Unit   (1)'
      GroupIndex = 3
    end
    object view2TU: TMenuItem
      Caption = 'Use 2 Texture Units   (2)'
      GroupIndex = 3
    end
    object N2: TMenuItem
      Break = mbBreak
      Caption = '-'
      GroupIndex = 4
    end
    object Stayontop1: TMenuItem
      Caption = 'Stay on top'
      Checked = True
      GroupIndex = 4
      Hint = 'viewStayOnTop'
    end
  end
end
