# SSE2Sample
Example of using sse2

![scr](scr.png)

Demo shows the difference between fade code versions and optimizations.  
Also this is an example of outputting raw pixels using the WinApi StretchDIBits function.  

[Precompiled Windows EXE (64 bit)](https://github.com/turborium/SSE2Sample/raw/main/SSE2Sample.exe)

Powered by [Delphi](https://www.embarcadero.com/products/delphi) with [ObjectPascal](https://www.danysoft.com/estaticos/free/Libros%20en%20formato%20GRATUITO/ObjectPascalHandbook_AlexandriaVersion.pdf) [(RU)](https://lp.embarcadero.com/RU-ObjectPascalEbook), get free Delphi 11 Community Edition [here](https://www.embarcadero.com/products/delphi/starter).

## Results
Method | x86 (32 bit)  | x64 (64 bit) |
------ | ------------- | ------------- |
Simple | 118 FPS  | 123 FPS  |
LoopUnroll | 122 FPS  | 116 FPS  |
LoopUnrollPtr | 105 FPS | 160 FPS  |
SSE2 | 374 FPS  | 432 FPS |

For optimization purposes, the following directives are used:
```Pascal
{$POINTERMATH ON} // разрешаем работу с указателями
{$OVERFLOWCHECKS OFF} // отключаем проверку переполнения чисел
{$RANGECHECKS OFF} // отключаем проверку диапазонов
```

**Simple** code:
```Pascal
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
```

**LoopUnroll** code:
```Pascal
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
```

**LoopUnrollPtr** code:
```Pascal
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
```

**SSE2** code:
```Pascal
procedure Fade16BytesSSE2(SourceVector, FadeVector: Pointer);
asm
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
```

---

## Вариации эффекта от ChatGPT 4o:

### Первая вариация
> Вот обновленный код для процедуры DrawEffect, который включает более утонченные цветовые переходы и более плавные формы для улучшения визуального эффекта.
> Изменения включают:
> - Уменьшенное количество спреев (SprayCount) и точек в каждом спрее (PointInSprayCount).
> - Плавные цветовые переходы, используя тригонометрические функции для базового цвета.
> - Легкие вариации основного цвета для каждой точки, чтобы избежать резких цветовых переходов.
```Pascal
procedure DrawEffect(Pixels: Pointer; Width, Height: Integer; var Time: Double; FadeMethod: TFadeMethod);
const
  SprayCount = 50;  // Уменьшил количество спреев для более плавного эффекта
  PointInSprayCount = 15;  // Уменьшил количество точек в одном спрее для большей детализации
  SprayDeltaTime = 0.05;  // Увеличил временной промежуток между спреями для плавности
  DeltaTime = 0.03;
  FadeLevel = 2;
var
  I, J: Integer;
  X, Y: Double;
  ScreenX, ScreenY: Integer;
  T: Double;
  BaseColor: TColor;
  R, G, B: Byte;
begin
  case FadeMethod of
    TFadeMethod.Simple: FadeBufferSimple(Pixels, Width * Height * 4, FadeLevel);
    TFadeMethod.LoopUnroll: FadeBufferLoopUnroll(Pixels, Width * Height * 4, FadeLevel);
    TFadeMethod.LoopUnrollPtr: FadeBufferLoopUnrollPtr(Pixels, Width * Height * 4, FadeLevel);
    TFadeMethod.SSE2: FadeBufferSSE2(Pixels, Width * Height * 4, FadeLevel);
    else raise EAbstractError.Create('Bad FadeMethod');
  end;

  T := Time;
  for I := 0 to SprayCount - 1 do
  begin
    X := 0.2 * (Cos(T) + Sin(T * 0.342 + 0.33) + Sin(T * 3.523)) * Width + 0.5 * Width;
    Y := 0.2 * (Sin(T * 0.643) + Cos(T * 0.124 + 0.15) + Sin(T * 2.423)) * Height + 0.5 * Height;
    ScreenX := Trunc(X);
    ScreenY := Trunc(Y);

    // Основной цвет спрея
    BaseColor := RGB(128 + Round(127 * Sin(T)), 128 + Round(127 * Sin(T * 1.3)), 128 + Round(127 * Sin(T * 1.7)));

    for J := 0 to PointInSprayCount - 1 do
    begin
      ScreenX := ScreenX + (Random(21 + J) - 10 - J div 2);
      ScreenY := ScreenY + (Random(21 + J) - 10 - J div 2);
      if (ScreenX < 0) or (ScreenX >= Width) or (ScreenY < 0) or (ScreenY >= Height) then
        continue;

      // Изменение оттенка основного цвета
      R := GetRValue(BaseColor) + Random(51) - 25;
      G := GetGValue(BaseColor) + Random(51) - 25;
      B := GetBValue(BaseColor) + Random(51) - 25;

      PUInt32(Pixels)[ScreenX + ScreenY * Width] := RGB(R, G, B);
    end;
    T := T + SprayDeltaTime;
  end;

  Time := Time + DeltaTime;
end;
```

### Вторая вариация
> Вот еще несколько идей для улучшения визуального эффекта:  
>   Добавление градиентных переходов:  
>   Введение градиентных переходов между цветами для создания более гладкого и плавного эффекта.
> 
>   Использование более сложных функций для координат:  
>   Применение более сложных функций для вычисления координат точек, чтобы создать интересные узоры и формы.
>
>   Добавление альфа-канала:  
>   Использование альфа-канала для создания эффекта прозрачности.
>
>   Изменение размера точек:  
>   Варьирование размеров точек для создания эффекта глубины.
```Pascal
procedure BlendPixel(Pixels: PByte; X, Y, Width: Integer; R, G, B, A: Byte);
var
  Index: Integer;
  DestR, DestG, DestB: Byte;
begin
  if (X < 0) or (X >= Width) or (Y < 0) then Exit;
  Index := (X + Y * Width) * 4;

  DestB := Pixels[Index];
  DestG := Pixels[Index + 1];
  DestR := Pixels[Index + 2];

  Pixels[Index] := (B * A + DestB * (255 - A)) div 255;
  Pixels[Index + 1] := (G * A + DestG * (255 - A)) div 255;
  Pixels[Index + 2] := (R * A + DestR * (255 - A)) div 255;
end;

procedure DrawEffect(Pixels: Pointer; Width, Height: Integer; var Time: Double; FadeMethod: TFadeMethod);
const
  SprayCount = 50;
  PointInSprayCount = 15;
  SprayDeltaTime = 0.05;
  DeltaTime = 0.03;
  FadeLevel = 2;
var
  I, J: Integer;
  X, Y: Double;
  ScreenX, ScreenY: Integer;
  T: Double;
  BaseColor: TColor;
  R, G, B, A: Byte;
  Size: Integer;
begin
  case FadeMethod of
    TFadeMethod.Simple: FadeBufferSimple(Pixels, Width * Height * 4, FadeLevel);
    TFadeMethod.LoopUnroll: FadeBufferLoopUnroll(Pixels, Width * Height * 4, FadeLevel);
    TFadeMethod.LoopUnrollPtr: FadeBufferLoopUnrollPtr(Pixels, Width * Height * 4, FadeLevel);
    TFadeMethod.SSE2: FadeBufferSSE2(Pixels, Width * Height * 4, FadeLevel);
    else raise EAbstractError.Create('Bad FadeMethod');
  end;

  T := Time;
  for I := 0 to SprayCount - 1 do
  begin
    X := 0.2 * (Cos(T) + Sin(T * 0.342 + 0.33) + Sin(T * 3.523)) * Width + 0.5 * Width;
    Y := 0.2 * (Sin(T * 0.643) + Cos(T * 0.124 + 0.15) + Sin(T * 2.423)) * Height + 0.5 * Height;
    ScreenX := Trunc(X);
    ScreenY := Trunc(Y);

    // Основной цвет спрея с градиентом
    BaseColor := RGB(128 + Round(127 * Sin(T)), 128 + Round(127 * Sin(T * 1.3)), 128 + Round(127 * Sin(T * 1.7)));

    for J := 0 to PointInSprayCount - 1 do
    begin
      ScreenX := ScreenX + (Random(21 + J) - 10 - J div 2);
      ScreenY := ScreenY + (Random(21 + J) - 10 - J div 2);
      if (ScreenX < 0) or (ScreenX >= Width) or (ScreenY < 0) or (ScreenY >= Height) then
        continue;

      // Изменение оттенка основного цвета с градиентом
      R := GetRValue(BaseColor) + Random(51) - 25;
      G := GetGValue(BaseColor) + Random(51) - 25;
      B := GetBValue(BaseColor) + Random(51) - 25;
      A := 255 - Round(255 * (J / PointInSprayCount));  // Альфа-канал

      Size := Random(3) + 1;  // Изменение размера точек

      // Рисуем точку с учетом альфа-канала и размера
      for var DX := -Size to Size do
        for var DY := -Size to Size do
          if (ScreenX + DX >= 0) and (ScreenX + DX < Width) and (ScreenY + DY >= 0) and (ScreenY + DY < Height) then
            BlendPixel(Pixels, ScreenX + DX, ScreenY + DY, Width, R, G, B, A);
    end;
    T := T + SprayDeltaTime;
  end;

  Time := Time + DeltaTime;
end;
```
