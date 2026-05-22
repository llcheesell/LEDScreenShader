# LEDScreenShader

**LEDScreenShader is a shader that draws realistic LED panels on Unity's Scriptable and Built-in render pipelines.**<br>
**LEDScreenShaderは高品質なLEDパネルを表現するシェーダーです。**<br>

<img width="640" alt="Screen Shot 2022-02-12 at 1 08 58" src="https://github.com/llcheesell/LEDScreenShader/blob/main/Docs/promo.gif"><br>
Supports URP, HDRP, and Built-in render pipelines with a single native HLSL shader.

## Features
* **Subpixel RGB Separation** — LED texture RGB channels act as per-subpixel masks, accurately reproducing real LED panel behavior
* **HDR Brightness Control** — Intensity Multiplier with squared scaling for HDRP high-luminance environments
* **FOV-Corrected Distant Fader** — Automatic moire prevention that adapts to camera FOV
* **DDX/DDY Auto-Fade** — Screen-space coverage detection for automatic fade at any resolution, FOV, or viewing angle
* **Cabinet Grid** — Configurable cabinet seams with normal perturbation and per-cabinet brightness variance
* **MotionVectors Pass** — Camera-only motion vectors for TAA ghost rejection (URP/HDRP)
* **3-Pipeline Support** — URP, HDRP, and Built-in in a single `.shader` file

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
https://github.com/llcheesell/LEDScreenShader.git?path=/Assets/LEDScreenShader#v0.2.0
```
Preview Release is also available at preview branch
```
https://github.com/llcheesell/LEDScreenShader.git?path=/Assets/LEDScreenShader#preview
```


## Usage

1. Create a new material and set shader to `llcheesell/LEDScreen`
2. Set texture to **Input Texture**
3. Adjust brightness by tweaking **Intensity Multiplier**. The best number may vary based on the scene exposure.

### Properties

**Input**
* **Input Texture** (`_InputTex`) — The texture to project on the panel. Supports video via RenderTexture.<br>
パネルに投影するテクスチャを適用します。
* **Input Tiling/Offset** (`_InputTex_ST`) — Tiling and offset for the input texture.

**LED**
* **LED Texture** (`_LEDTex`) — RGB subpixel mask texture. R/G/B channels define which subpixel areas light up.<br>
LEDのテクスチャを適用します。このパッケージにはいくつかのサンプルが含まれています。
* **LED Tiling** (`_LEDTiling`) — Number of LED tiles in X/Y.<br>
LEDテクスチャのタイリングを設定します。

**Brightness**
* **Intensity Multiplier** (`_IntensityMultiplier`) — Emission intensity (squared internally for HDR compatibility).

**Distant Fader**
* **Distant Fade Start/End** (`_DistantFadeStart`, `_DistantFadeEnd`) — Distance range for LED texture fade. FOV-corrected automatically.<br>
カメラからの距離に従ってLEDテクスチャを無効化します。これによってモアレ効果を防ぐことができます。
* **Distant Fade Brightness** (`_DistantFadeBrightness`) — HDR color multiplier applied when faded.<br>
DistantFadeによって明るさの変化が生じたときに、HDRカラーで明るさを調整することが出来ます。

**Cabinet Grid**
* **Cabinet Grid Enabled** (`_CabinetGridEnabled`) — Toggle cabinet seam rendering.
* **Cabinet Tiling** (`_CabinetTiling`) — Number of cabinet modules (cols, rows).
* **Cabinet Seam Width/Depth** — Seam width in UV space and normal indent strength.
* **Cabinet Brightness Variance** — Per-cabinet luminance variation range.

**Base Material**
* **Base Texture / Normal Map / Mask Map** (`_BaseMap`, `_NormalMap`, `_MaskMap`) — PBR surface properties. MaskMap channels: R=Metallic, G=AO, A=Smoothness.<br>
パネルのベースマテリアルを設定します。


## Note
* Optimized for Linear Color Space. It could be used in Gamma Color Space but the bright area tend to be clamped.<br>
<img width="640" src="https://github.com/llcheesell/LEDScreenShader/blob/main/Docs~/linear.png">

* The combination use of Bloom Post Processing is recommended.

* **Built-in render pipeline**: MotionVectors pass is not available. SMAA is recommended for anti-aliasing instead of TAA.<br>
Built-inレンダーパイプラインではMotionVectorsパスは利用できません。TAAの代わりにSMAAの使用を推奨します。

* Legacy Shader Graph files are preserved in `Shaders/Legacy/` for reference.

## Roadmap
* ~~Subpixel RGB separation~~ (completed in v0.2.0)
* ~~Cabinet Grid rendering~~ (completed in v0.2.0)
* ~~MotionVectors pass for TAA~~ (completed in v0.2.0)
* ~~DDX/DDY auto-fade~~ (completed in v0.2.0)
* ~~Native HLSL rewrite (3-pipeline unified)~~ (completed in v0.2.0)
* ~~Tile and Offset for InputVideo~~ (completed in v0.1.0)
* ~~update Build-in Shader~~ (completed in v0.0.6)
* ~~Support HDRP~~ (completed in v0.0.5)
* ~~Moire prevention processing according to the distance from the camera~~ (completed in v0.0.4)
* ~~Higher quality pixel textures and materials~~ (completed in v0.0.2)

Let me know if you have any suggestions and problems.<br>
機能要望、提案などありましたら@llcheesellまでお知らせください。


## License
Under [MIT License](LICENSE)<br>
*Credit, or notice of use is not required but much appreciated!*
