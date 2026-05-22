# LEDScreenShader

**LEDScreenShader is a shader that draws realistic LED panels on Unity's Scriptable and Built-in render pipelines.**<br>
**LEDScreenShaderは高品質なLEDパネルを表現するシェーダーです。**<br>

Supports URP, HDRP, and Built-in render pipelines with a single native HLSL shader (`llcheesell/LEDScreen`).

## Usage

1. Create a new material and set shader to `llcheesell/LEDScreen`
2. Set texture to InputTexture
3. Adjust brightness by tweaking IntensityMultiplier. The best number may vary based on the scene exposure.

* Input Texture<br>
Apply the texture you want to project to the panel. You can put a video via RenderTexture.<br>
パネルに投影するテクスチャを適用します。

* LED Texture<br>
Set the LED texture. RGB channels act as subpixel masks (R=red, G=green, B=blue).<br>
LEDのテクスチャを適用します。このパッケージにはいくつかのサンプルが含まれています。

* BaseTexture/NormalTexture/MaskMap<br>
This is the base material setting for the panel.
MaskMap: R=Metallic, G=AO, A=Smoothness.<br>
パネルのベースマテリアルを設定します。

* LED Tiling<br>
Sets the number of tiles of the LED panel.<br>
LEDテクスチャのタイリングを設定します。

* DistantFadeStart/End<br>
Fades the LED texture according to the distance from the camera. FOV-corrected. This prevents moiré effects.<br>
カメラからの距離に従ってLEDテクスチャを無効化します。これによってモアレ効果を防ぐことができます。

* DistantFadeBrightness<br>
This value allows you to adjust the brightness change caused by the fading of the LED texture.<br>
DistantFadeによって明るさの変化が生じたときに、HDRカラーで明るさを調整することが出来ます。

* Cabinet Grid<br>
Enable to render cabinet module seams with adjustable width, depth, and per-cabinet brightness variance.

* MotionVectors (URP/HDRP only)<br>
Camera-only motion vectors for TAA ghost rejection. Built-in pipeline users should use SMAA instead of TAA.

[Video Guide](https://www.youtube.com/watch?v=6b-_SwUf9jM)


## Note
* Optimized for Linear Color Space. It could be used in Gamma Color Space but the bright area tend to be clamped.<br>
リニアカラースペースでの使用を推奨。

* The combination use of Bloom Post Processing is recommended.<br>
Bloomポストエフェクトの併用を推奨。

* Built-in render pipeline does not support MotionVectors. Use SMAA for anti-aliasing.<br>
Built-inレンダーパイプラインではSMAAの使用を推奨します。

*Credit, or notice of use is not required but much appreciated!*
twitter.com/llcheesell
