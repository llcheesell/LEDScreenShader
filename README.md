# LEDScreenShader

Built for Built-in and Universal Render Pipeline.
Built-in shaders are included, but I'm currently focused on development with the Shader Graph.

<img width="454" alt="Screen Shot 2022-02-10 at 14 49 34" src="https://user-images.githubusercontent.com/113725/153345725-990ba8da-07cd-4d51-a9e0-4c4500b4ca18.png">
* Grid parameters are currently not supported.

## Samples
<img width="577" alt="Screen Shot 2022-02-10 at 13 57 37" src="https://user-images.githubusercontent.com/113725/153345784-378ab0e4-3e55-4e2c-8149-d437d9c11def.png">
<img width="640" alt="Screen Shot 2022-02-10 at 13 59" src="https://user-images.githubusercontent.com/113725/153346605-d261c567-1d2c-4da7-9944-623f21abde96.png">

## Usage
Please import via UPM (Unity Package Manager).

Optimized for Linear Color Space. It could be used in Gamma Color Space but the bright area tend to be clamped.
The use of Bloom Post Processing is recommended.

## Roadmap
* Moire prevention processing according to the distance from the camera
* Higher quality pixel textures ana materials
