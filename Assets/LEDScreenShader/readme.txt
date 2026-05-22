# LEDScreenShader

LEDScreenShader is a native HLSL shader for rendering realistic LED panels in Unity.
LEDScreenShaderはUnity上で高品質なLEDパネル表現を行うネイティブHLSLシェーダーです。

The current version replaces the previous Shader Graph implementation with the native shader `llcheesell/LEDScreen`.
HDRP and URP are the main supported render pipelines.
Built-in Render Pipeline includes only a simplified fallback shader and is not officially supported.

現在のバージョンでは、従来のShader Graph実装からネイティブシェーダー `llcheesell/LEDScreen` へ移行しています。
主な対応対象はHDRP / URPです。
Built-in Render Pipeline向けには簡易的なFallbackシェーダーを同梱していますが、公式サポート対象外です。

## Render Pipeline Support

* HDRP: Supported and tested
* URP: Supported and tested
* Built-in Render Pipeline: Simplified fallback only, not officially supported

HDRP / URPではUnity 2021およびUnity 6000.3.15で動作確認しています。
Built-in Render Pipelineは未検証のため、サポート対象外として扱います。

## Usage

1. Create a new material and set the shader to `llcheesell/LEDScreen`.
2. Set the texture or RenderTexture to Input Texture.
3. Select an LED texture or procedural LED pattern.
4. Adjust Intensity Multiplier based on the scene exposure and bloom settings.

## Main Features

* Native HLSL shader
* Subpixel RGB separation
* Procedural LED patterns
* HDR brightness control
* FOV-corrected distant fader for moire reduction
* DDX/DDY auto-fade
* Cabinet grid rendering
* Motion vector support for HDRP/URP

## Main Properties

* Input Texture
Apply the texture or RenderTexture shown on the panel.
パネルに表示するテクスチャ、またはRenderTextureを指定します。

* LED Texture / Procedural LED
Use an RGB subpixel mask texture, or generate LED layouts procedurally.
LEDの発光パターンを指定します。テクスチャ、またはプロシージャルLED配列を使用できます。

* LED Tiling
Sets the number of LED tiles.
LEDパターンのタイリング数を設定します。

* Intensity Multiplier
Controls emission intensity for HDR lighting and bloom workflows.

* Distant Fade Start/End
Fades LED detail according to camera distance and field of view to reduce moire.
カメラ距離とFOVに応じてLEDディテールをフェードし、モアレを抑制します。

* Cabinet Grid
Renders cabinet module seams with adjustable width, depth, and brightness variance.

* Base Texture / Normal Map / Mask Map
Controls the base PBR material of the panel.
パネル本体のベースマテリアルを設定します。

## Notes

* Linear Color Space is recommended.
リニアカラースペースでの使用を推奨します。

* Bloom post-processing is recommended for realistic LED brightness.
リアルなLED発光表現にはBloomポストエフェクトの併用を推奨します。

* Built-in Render Pipeline is not officially supported. The included fallback shader is intended only as a simplified compatibility path.
Built-in Render Pipelineは公式サポート対象外です。同梱のFallbackシェーダーは簡易互換用として扱ってください。

* Legacy Shader Graph files are preserved in `Shaders/Legacy/` for reference only. The main supported shader is `llcheesell/LEDScreen`.
旧Shader Graphファイルは参考用として`Shaders/Legacy/`に残しています。現在の主なサポート対象は`llcheesell/LEDScreen`です。

Credit, or notice of use is not required but much appreciated!
twitter.com/llcheesell
