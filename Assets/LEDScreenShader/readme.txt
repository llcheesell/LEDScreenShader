# LEDScreenShader

**LEDScreenShader is a shader that draws realistic LED panels on Unity's Scriptable and Built-in render pipelines.**<br>
**LEDScreenShaderは高品質なLEDパネルを表現するシェーダーです。**<br>

Currently URP and HDRP is the target render pipeline since it's developed with Shader Graph.<br>
The built-in shader is also included with minimum functionality implemented.

## Usage

1. Create a new material and set shader to appropriate Render-Pipeline's LEDScreenShader.
2. set texture to InputVideo
3. Adjust brightness by tweaking IntensityMultiplier. The best number may vary based on the scene exposure.

* InputVideo<br>
Apply the texture you want to project to the panel. You can put a video via RenderTexture.<br>
パネルに投影するテクスチャを適用します。

* LED Texture<br>
Set the LED texture. This texture will be multiplied by the InputVideo.<br>
The package include several LED Texture.<br>
LEDのテクスチャを適用します。このパッケージにはいくつかのサンプルが含まれています。

* BaseTexture/NormalTexture/AlphaMap/MaskMap<br>
This is the base material setting for the panel.
Metalic and Smoothness will be multiplied to MaskMap.<br>
パネルのベースマテリアルを設定します。

* Tiling/Offset<br>
Sets the number of tiles and offset of the LED panel.<br>
LEDテクスチャのタイリングを設定します。

* DistantFadeStart/End<br>
Fades the LED texture according to the distance from the camera. This prevents moiré effects.<br>
カメラからの距離に従ってLEDテクスチャを無効化します。これによってモアレ効果を防ぐことができます。

* DistantFadeBrightness<br>
This value allows you to adjust the brightness change caused by the fading of the LED texture.<br>
DistantFadeによって明るさの変化が生じたときに、HDRカラーで明るさを調整することが出来ます。

*Grid parameters are currently disabled due to quality issue.*


[Video Guide](https://www.youtube.com/watch?v=6b-_SwUf9jM)


## Note
* Optimized for Linear Color Space. It could be used in Gamma Color Space but the bright area tend to be clamped.<br>
リニアカラースペースでの使用を推奨。

* If you have render problems in HDRP, please check/uncheck Recursive Rendering option in Shader Graph Editor.<br>

* The combination use of Bloom Post Processing is recommended.<br>
Bloomポストエフェクトの併用を推奨。

## Roadmap
* Performance optimization disabling detailed textures along with distantFader
* ~~Tile and Offset for InputVideo (completed)
* ~~update Build-in Shader~~ (completed in v0.0.6)
* ~~Support HDRP~~ (completed in v0.0.5)
* ~~Moire prevention processing according to the distance from the camera~~ (completed in v0.0.4)
* ~~Higher quality pixel textures ana materials~~ (completed in v0.0.2)

Let me know if you have any suggestions and problems.<br>
機能要望、提案などありましたらllcheesellまでお知らせください。


*Credit, or notice of use is not required but much appreciated!*
twitter.com/llcheesell