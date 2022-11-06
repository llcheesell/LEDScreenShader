# LEDScreenShader

**LEDScreenShader is a shader that draws realistic LED panels on Unity's Scriptable and Built-in render pipelines.**<br>
**LEDScreenShaderは高品質なLEDパネルを表現するシェーダーです。**<br>

<img width="640" alt="Screen Shot 2022-02-12 at 1 08 58" src="https://github.com/llcheesell/LEDScreenShader/blob/main/Docs/promo.gif"><br>
Currently URP and HDRP is the target render pipeline since it's developed with Shader Graph.<br>
The built-in shader is also included with minimum functionality implemented.


## Samples
* HDR Brightness control
<img width="640" src="https://github.com/llcheesell/LEDScreenShader/blob/main/Docs~/de99bb559a84878e447cbc1e7014cee4.gif">

* Includes multiple LED panel textures
<img width="640" alt="Screen Shot 2022-02-10 at 13 59" src="https://user-images.githubusercontent.com/113725/153346605-d261c567-1d2c-4da7-9944-623f21abde96.png">

* Distant Fader for Moire prevention
<img width="640" src="https://github.com/llcheesell/LEDScreenShader/blob/main/Docs~/DistantFader2.gif">

## Install
Install the package via UPM (Unity Package Manager) or from [Unity Asset Store](https://assetstore.unity.com/packages/vfx/shaders/led-screen-shader-229091)<br>

```
https://github.com/llcheesell/LEDScreenShader.git?path=/Assets/LEDScreenShader#v0.1.0
```
Preview Release is also available at preview branch
```
https://github.com/llcheesell/LEDScreenShader.git?path=/Assets/LEDScreenShader#preview
```


## Usage

<img width="300" alt="Screen Shot 2022-02-12 at 1 08 58" src="https://raw.githubusercontent.com/llcheesell/LEDScreenShader/feature/v010/Docs~/NewUI_v010.png">

* Input Texture<br>
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
* This shader includes [com.needle.shadergraph-markdown](https://github.com/needle-tools/shadergraph-markdown)'s markdown version of the shader interface. If you want to use clean UI version you need the package to be installed.

* Optimized for Linear Color Space. It could be used in Gamma Color Space but the bright area tend to be clamped.<br>
<img width="640" src="https://github.com/llcheesell/LEDScreenShader/blob/main/Docs~/linear.png">

* If you have render problems in HDRP, please check/uncheck Recursive Rendering option in Shader Graph Editor.<br>
<img width="320" src="https://raw.githubusercontent.com/llcheesell/LEDScreenShader/feature/v010/Docs~/RecursiveRendering.png">

* The combination use of Bloom Post Processing is recommended.

## Roadmap
* Performance optimization disabling detailed textures along with distantFader
* ~~Tile and Offset for InputVideo~~ (completed in v0.1.0)
* ~~update Build-in Shader~~ (completed in v0.0.6)
* ~~Support HDRP~~ (completed in v0.0.5)
* ~~Moire prevention processing according to the distance from the camera~~ (completed in v0.0.4)
* ~~Higher quality pixel textures ana materials~~ (completed in v0.0.2)

Let me know if you have any suggestions and problems.<br>
機能要望、提案などありましたら@llcheesellまでお知らせください。


## License
Under [MIT License](LICENSE)<br>
*Credit, or notice of use is not required but much appreciated!*
