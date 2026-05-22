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

## Offline Documentation

The Asset Store package includes Documentation/LEDScreenShader_Start_Guide.pdf.
It contains a numbered English start guide, setup steps, shader property reference, migration notes, troubleshooting, and a Japanese quick guide.

## Migration

Version 2.0 replaces the previous Shader Graph implementation with the native shader `llcheesell/LEDScreen`.

If legacy Shader Graph materials are found, LEDScreenShader shows a migration prompt in the Unity Editor.
You can also run the migration manually from Tools > LEDScreenShader > Migrate Legacy Materials to Native Shader.

The migration tool detects materials that still reference the previous Shader Graph shaders, including materials that appear as Missing Shader after updating from the GitHub package.
The old input/video texture is assigned to Input Screen Texture (`_InputTex`).
Compatible LED textures, LED tiling, input texture tiling/offset, emission color, and intensity are copied to the native shader where possible.

Version 2.0では、従来のShader Graph実装からネイティブシェーダー`llcheesell/LEDScreen`へ移行しています。

旧Shader Graphを参照しているマテリアルが見つかった場合、Unity Editor上で移行プロンプトが表示されます。
手動で実行する場合は Tools > LEDScreenShader > Migrate Legacy Materials to Native Shader を使用してください。

GitHubパッケージの更新後にMissing Shaderになったマテリアルも、既知の旧Shader GUIDから検出して移行できます。
旧Input/Videoテクスチャは Input Screen Texture（`_InputTex`）に割り当てます。
互換性のあるLEDテクスチャ、LEDタイリング、Input TextureのTiling/Offset、Emission Color、Intensityは可能な範囲で引き継ぎます。

## Main Features

* Native HLSL shader
* Subpixel RGB separation
* Procedural LED patterns
* HDR brightness control
* Screen-space LED fade for moire reduction
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

* LED Columns / Rows
Sets the number of LED tiles in X/Y using `_LEDTilingX` and `_LEDTilingY`.
LEDパターンの横方向/縦方向のタイリング数を設定します。

* Intensity Multiplier
Controls emission intensity for HDR lighting and bloom workflows.

* Fade Start/End/Bias
Fades LED detail according to screen-space LED density using `_FadeStart`, `_FadeEnd`, and `_FadeBias`.
画面上のLED密度に応じてLEDディテールをフェードし、モアレを抑制します。

* Cabinet Grid
Renders cabinet module seams with adjustable width, depth, and brightness variance.
Use `_CabinetColumns` and `_CabinetRows` to set the module count.

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

* The previous Shader Graph implementation is not included in the main package. The supported shader is `llcheesell/LEDScreen`.
旧Shader Graph実装はメインパッケージには含めていません。現在のサポート対象は`llcheesell/LEDScreen`です。

Credit, or notice of use is not required but much appreciated!
twitter.com/llcheesell
