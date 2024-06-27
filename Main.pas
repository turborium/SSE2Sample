// 2024-2024 Turborium
unit Main;

{$POINTERMATH ON} // разрешаем работу с указателями
{$OVERFLOWCHECKS OFF} // отключаем проверку переполнения чисел
{$RANGECHECKS OFF} // отключаем проверку диапазонов
{$SCOPEDENUMS ON}// включаем скоуп для енамов

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  System.Math, System.Rtti,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TFormMain = class(TForm)
    PaintBox: TPaintBox;
    RadioGroupFadeMethod: TRadioGroup;
    procedure FormCreate(Sender: TObject);
    procedure PaintBoxPaint(Sender: TObject);
    procedure RadioGroupFadeMethodClick(Sender: TObject);
  private
    FPixels: TArray<Byte>;
    FTime: Double;
    // fps
    FNextSecond: Int64;
    FFps, FFpsCounter: Integer;
    FAllFps, FAllFpsTimes: Int64;
    procedure ApplicationIdle(Sender: TObject; var Done: Boolean);
    procedure UpdateFPSCounter();
  end;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

type
  TFadeMethod = (Simple, LoopUnroll, LoopUnrollPtr, SSE2);

procedure FadeBufferSimple(Data: PByte; Count: Integer; Level: Byte);
var
  I: Integer;
begin
  // простой фейдинг пикселов
  for I := 0 to Count - 1 do
  begin
    Data[I] := Max(0, Data[I] - Level);
  end;
end;

procedure FadeBufferLoopUnroll(Data: PByte; Count: Integer; Level: Byte);
var
  I, ChunkCount, Index: Integer;
begin
  // считаем кол-во полных 16-байтных чанков
  ChunkCount := Count div 16;

  // фейдинг чанков используя "раскрутку цикла"
  Index := 0;
  for I := 0 to ChunkCount - 1 do
  begin
    Data[Index +  0] := Max(0, Data[Index +  0] - Level);
    Data[Index +  1] := Max(0, Data[Index +  1] - Level);
    Data[Index +  2] := Max(0, Data[Index +  2] - Level);
    Data[Index +  3] := Max(0, Data[Index +  3] - Level);
    Data[Index +  4] := Max(0, Data[Index +  4] - Level);
    Data[Index +  5] := Max(0, Data[Index +  5] - Level);
    Data[Index +  6] := Max(0, Data[Index +  6] - Level);
    Data[Index +  7] := Max(0, Data[Index +  7] - Level);
    Data[Index +  8] := Max(0, Data[Index +  8] - Level);
    Data[Index +  9] := Max(0, Data[Index +  9] - Level);
    Data[Index + 10] := Max(0, Data[Index + 10] - Level);
    Data[Index + 11] := Max(0, Data[Index + 11] - Level);
    Data[Index + 12] := Max(0, Data[Index + 12] - Level);
    Data[Index + 13] := Max(0, Data[Index + 13] - Level);
    Data[Index + 14] := Max(0, Data[Index + 14] - Level);
    Data[Index + 15] := Max(0, Data[Index + 15] - Level);

    Index := Index + 16;
  end;

  // фейдинг последнего кусочка чанка
  for I := ChunkCount * 16 to Count - 1 do
    Data[I] := Max(0, Data[I] - Level);
end;

procedure FadeBufferLoopUnrollPtr(Data: PByte; Count: Integer; Level: Byte);
var
  I, ChunkCount: Integer;
begin
  // считаем кол-во полных 16-байтных чанков
  ChunkCount := Count div 16;

  // фейдинг чанков используя "раскрутку цикла" и указатели
  for I := 0 to ChunkCount - 1 do
  begin
    Data^ := Max(0, Data^ - Level); Inc(Data);
    Data^ := Max(0, Data^ - Level); Inc(Data);
    Data^ := Max(0, Data^ - Level); Inc(Data);
    Data^ := Max(0, Data^ - Level); Inc(Data);
    Data^ := Max(0, Data^ - Level); Inc(Data);
    Data^ := Max(0, Data^ - Level); Inc(Data);
    Data^ := Max(0, Data^ - Level); Inc(Data);
    Data^ := Max(0, Data^ - Level); Inc(Data);
    Data^ := Max(0, Data^ - Level); Inc(Data);
    Data^ := Max(0, Data^ - Level); Inc(Data);
    Data^ := Max(0, Data^ - Level); Inc(Data);
    Data^ := Max(0, Data^ - Level); Inc(Data);
    Data^ := Max(0, Data^ - Level); Inc(Data);
    Data^ := Max(0, Data^ - Level); Inc(Data);
    Data^ := Max(0, Data^ - Level); Inc(Data);
    Data^ := Max(0, Data^ - Level); Inc(Data);
  end;

  // фейдинг последнего кусочка чанка
  for I := ChunkCount * 16 to Count - 1 do
  begin
    Data^ := Max(0, Data^ - Level); Inc(Data);
  end;
end;

procedure Fade16BytesSSE2(SourceVector, FadeVector: Pointer);
asm
  {$IFDEF WIN64}.NOFRAME{$ENDIF}

  // Загрузка данных из SourceVector, FadeVector в xmm0 и xmm1
  movdqu xmm0, dqword ptr [SourceVector]
  movdqu xmm1, dqword ptr [FadeVector]

  // Вычитание с насыщением (saturated subtraction)
  psubusb xmm0, xmm1

  // Запись данных из xmm0 обратно в SourceVector
  movdqu dqword ptr [SourceVector], xmm0
end;

procedure FadeBufferSSE2(Data: PByte; Count: Integer; Level: Byte);
var
  FadeVector: packed array [0..15] of Byte;
  I, ChunkCount: Integer;
begin
  // создаем вектор с 16 байтами уровня фейдинга
  for I := 0 to 16 - 1 do
    FadeVector[I] := Level;

  // считаем кол-во полных 16-байтных чанков
  ChunkCount := Count div 16;

  // фейдинг чанков используя SSE2
  for I := 0 to ChunkCount - 1 do
    Fade16BytesSSE2(@Data[I * 16], @FadeVector[0]);

  // фейдинг последнего кусочка чанка
  for I := ChunkCount * 16 to Count - 1 do
    Data[I] := Max(0, Data[I] - Level);
end;

procedure DrawEffect(Pixels: Pointer; Width, Height: Integer; var Time: Double; FadeMethod: TFadeMethod);
const
  SprayCount = 100;
  PointInSprayCount = 20;
  SprayDeltaTime = 0.02;
  DeltaTime = 0.03;
  FadeLevel = 2;
var
  I, J: Integer;
  X, Y: Double;
  ScreenX, ScreenY: Integer;
  T: Double;
begin
  // фейдим фон
  case FadeMethod of
    TFadeMethod.Simple: FadeBufferSimple(Pixels, Width * Height * 4, FadeLevel);
    TFadeMethod.LoopUnroll: FadeBufferLoopUnroll(Pixels, Width * Height * 4, FadeLevel);
    TFadeMethod.LoopUnrollPtr: FadeBufferLoopUnrollPtr(Pixels, Width * Height * 4, FadeLevel);
    TFadeMethod.SSE2: FadeBufferSSE2(Pixels, Width * Height * 4, FadeLevel);
    else
      raise EAbstractError.Create('Bad FadeMethod');
  end;

  // рисуем спрей
  T := Time;
  for I := 0 to SprayCount - 1 do
  begin
    X := 0.16 * (Cos(T) + Sin(T * 0.342 + 0.33) + Sin(T * 3.523)) * Width + 0.5 * Width;
    Y := 0.16 * (Sin(T * 0.643) + Cos(T * 0.124 + 0.15) + Sin(T * 2.423)) * Height + 0.5 * Height;
    ScreenX := Trunc(X);
    ScreenY := Trunc(Y);
    for J := 0 to PointInSprayCount - 1 do
    begin
      ScreenX := ScreenX + (Random(21 + J) - 10 - J div 2);
      ScreenY := ScreenY + (Random(21 + J) - 10 - J div 2);
      if (ScreenX < 0) or (ScreenX >= Width) or (ScreenY < 0) or (ScreenY >= Height) then
        continue;

      PUInt32(Pixels)[ScreenX + ScreenY * Width] := $FFFFAAFF;
    end;
    T := T + SprayDeltaTime;
  end;

  // сдвигаем время
  Time := Time + DeltaTime;
end;

{ TFormMain }

procedure TFormMain.FormCreate(Sender: TObject);
var
  RttiType: TRttiType;
  RttiContext: TRttiContext;
begin
  // делаем контрол непрозрачным (VCL не будет очищать фон)
  PaintBox.ControlStyle := PaintBox.ControlStyle + [csOpaque];
  // назначаем обработчик "простоя" приложения
  Application.OnIdle := ApplicationIdle;

  // заполнение методов через rtti
  RttiContext := TRttiContext.Create();
  try
    RttiType := RttiContext.GetType(TypeInfo(TFadeMethod));
    RadioGroupFadeMethod.Items.AddStrings(TRttiEnumerationType(RttiType).GetNames());
  finally
    RttiContext.Free();
  end;
  RadioGroupFadeMethod.ItemIndex := RadioGroupFadeMethod.Items.Count - 1;
  RadioGroupFadeMethod.Columns := RadioGroupFadeMethod.Items.Count;
end;

procedure TFormMain.ApplicationIdle(Sender: TObject; var Done: Boolean);
begin
  // сообщаем что задача не выполнена, что уменьшает задержку
  Done := False;
  // просим систему перерисовать PaintBox
  PaintBox.Invalidate();
end;

procedure TFormMain.PaintBoxPaint(Sender: TObject);
var
  BitmapInfo: WinApi.Windows.TBitmapInfo;
  Width, Height: Integer;
  FpsString: string;
  FpsRect: TRect;
begin
  UpdateFPSCounter();

  // получаем размер вывода
  Width := PaintBox.Width;
  Height := PaintBox.Height;

  // меняем размер буффера для соответсвия размеру вывода
  if Length(FPixels) <> Width * Height * 4 then
  begin
     FPixels := nil;
     SetLength(FPixels, Width * Height * 4);
  end;

  // рисуем эффект
  DrawEffect(Pointer(FPixels), Width, Height, FTime, TFadeMethod(RadioGroupFadeMethod.ItemIndex));

  // создаем описание изображения
  BitmapInfo := Default(WinApi.Windows.TBitmapInfo);
  BitmapInfo.bmiHeader.biSize := SizeOf(WinApi.Windows.TBitmapInfoHeader);
  BitmapInfo.bmiHeader.biWidth := Width;
  BitmapInfo.bmiHeader.biHeight := -Height;// да высота отрицательная, чтобы пиксели были сверху-вниз
  BitmapInfo.bmiHeader.biPlanes := 1;
  BitmapInfo.bmiHeader.biBitCount := 32;// 32-х битный цвет (без альфа канала)
  BitmapInfo.bmiHeader.biCompression := BI_RGB;

  // рисуем изображение из буффера
  WinApi.Windows.StretchDIBits(
    PaintBox.Canvas.Handle,// назначение
    0, 0, PaintBox.Width, PaintBox.Height,// позиция назначения
    0, 0, Width, Height,// позиция источника
    Pointer(FPixels),// источник
    BitmapInfo,// описание изображения
    WinApi.Windows.DIB_RGB_COLORS,// RGB
    WinApi.Windows.SRCCOPY// просто копируем
  );

  // печатаем параметры
  FpsString := Format(
    'FPS: %d'#10'FPS AVG: %f'#10'Width: %d'#10'Height: %d',
    [FFps, FAllFps / Max(1, FAllFpsTimes), PaintBox.Width, PaintBox.Height],
    FormatSettings.Invariant
  );
  FpsRect := Rect(0, 0, PaintBox.Width, PaintBox.Height);
  PaintBox.Canvas.Brush.Style := bsClear;
  PaintBox.Canvas.Font.Color := clLime;
  PaintBox.Canvas.Font.Size := -20;
  PaintBox.Canvas.Font.Name := 'Lucida Console';
  PaintBox.Canvas.TextRect(FpsRect, FpsString, []);
end;

procedure TFormMain.RadioGroupFadeMethodClick(Sender: TObject);
begin
  // сброс
  FNextSecond := 0;
  FFps := 0;
  FFpsCounter := 0;
  FAllFps := 0;
  FAllFpsTimes := 0;
end;

procedure TFormMain.UpdateFPSCounter();
begin
  // + fps
  Inc(FFpsCounter);

  // первоночальный запуск
  if FNextSecond = 0 then
    FNextSecond := GetTickCount64() + 1000;

  // рассчет fps
  if GetTickCount64() >= FNextSecond then
  begin
    FFps := FFpsCounter;
    FFpsCounter := 0;
    FNextSecond := GetTickCount64() + 1000;

    FAllFps := FAllFps + FFps;
    FAllFpsTimes := FAllFpsTimes + 1;
  end;
end;

end.
