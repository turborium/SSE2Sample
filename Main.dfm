object FormMain: TFormMain
  Left = 0
  Top = 0
  Caption = 'Fade SSE2 Demo'
  ClientHeight = 761
  ClientWidth = 784
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 15
  object PaintBox: TPaintBox
    Left = 0
    Top = 40
    Width = 784
    Height = 721
    Align = alClient
    OnPaint = PaintBoxPaint
    ExplicitLeft = 24
    ExplicitTop = 89
    ExplicitWidth = 178
    ExplicitHeight = 141
  end
  object RadioGroupFadeMethod: TRadioGroup
    Left = 0
    Top = 0
    Width = 784
    Height = 40
    Align = alTop
    Caption = 'Fade Method'
    Columns = 4
    ItemIndex = 3
    Items.Strings = (
      'Simple'
      'LoopUnroll'
      'LoopUnrollPtr'
      'SSE2')
    TabOrder = 0
    OnClick = RadioGroupFadeMethodClick
    ExplicitWidth = 172
  end
end
