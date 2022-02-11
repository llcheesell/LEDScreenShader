# LEDScreenShader

The shader of a realistic LED panels.

Built-in shaders are included, but I'm currently focused on development with the Shader Graph.

<img width="467" alt="Screen Shot 2022-02-12 at 1 08 58" src="https://user-images.githubusercontent.com/113725/153626690-deef6682-13d5-4086-8b39-dec24587deeb.png">

* Grid parameters are currently not working.
* Includes detailed LED panel textures.


## Samples
detailed version

<img src="https://github.com/llcheesell/LEDScreenShader/blob/main/Docs/de99bb559a84878e447cbc1e7014cee4.gif">
simple version

<img width="577" alt="Screen Shot 2022-02-10 at 13 57 37" src="https://user-images.githubusercontent.com/113725/153345784-378ab0e4-3e55-4e2c-8149-d437d9c11def.png">
<img width="640" alt="Screen Shot 2022-02-10 at 13 59" src="https://user-images.githubusercontent.com/113725/153346605-d261c567-1d2c-4da7-9944-623f21abde96.png">

## Usage
Please import via UPM (Unity Package Manager).

Package Manager > Add Package from Git URL > paste below and import.
```
https://github.com/llcheesell/LEDScreenShader.git?path=/Assets/LEDScreenShader#v0.0.3
```

or you can import unitypackage manually.

Please check [Release v0.0.3](https://github.com/llcheesell/LEDScreenShader/releases/tag/v0.0.3) page.

## Note
Optimized for Linear Color Space. It could be used in Gamma Color Space but the bright area tend to be clamped.

<img src="https://github.com/llcheesell/LEDScreenShader/blob/main/Docs/linear.png">

The combination use of Bloom Post Processing is recommended.

## Roadmap
* Moire prevention processing according to the distance from the camera
* Higher quality pixel textures ana materials (completed in v0.0.2)
