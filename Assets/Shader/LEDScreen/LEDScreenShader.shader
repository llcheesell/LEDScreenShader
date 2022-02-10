// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "LEDScreenShader"
{
	Properties
	{
		_RGB_channel("RGB_channel", 2D) = "white" {}
		[HDR]_LedTexture("LedTexture", 2D) = "black" {}
		_Intensity("Intensity", Int) = 80
		[HideInInspector] _texcoord( "", 2D ) = "white" {}
		[HideInInspector] __dirty( "", Int ) = 1
	}

	SubShader
	{
		Tags{ "RenderType" = "Opaque"  "Queue" = "Geometry+0" "IsEmissive" = "true"  }
		Cull Back
		CGPROGRAM
		#pragma target 3.0
		#pragma surface surf StandardSpecular keepalpha addshadow fullforwardshadows 
		struct Input
		{
			float2 uv_texcoord;
		};

		uniform sampler2D _LedTexture;
		uniform float4 _LedTexture_ST;
		uniform int _Intensity;
		uniform sampler2D _RGB_channel;

		void surf( Input i , inout SurfaceOutputStandardSpecular o )
		{
			float2 uv_LedTexture = i.uv_texcoord * _LedTexture_ST.xy + _LedTexture_ST.zw;
			float2 uv_TexCoord7 = i.uv_texcoord * float2( 2000,1000 );
			o.Emission = ( ( ( tex2D( _LedTexture, uv_LedTexture ) + 0.0 ) * _Intensity ) * tex2D( _RGB_channel, uv_TexCoord7 ) ).rgb;
			o.Alpha = 1;
		}

		ENDCG
	}
	Fallback "Diffuse"
	CustomEditor "ASEMaterialInspector"
}
/*ASEBEGIN
Version=18909
294;717;2924;1254;2172.01;856.3918;1;True;True
Node;AmplifyShaderEditor.TexturePropertyNode;2;-1724.152,-425.9116;Inherit;True;Property;_LedTexture;LedTexture;1;1;[HDR];Create;True;0;0;0;False;0;False;723e4ba63dbf14c7eb8220447f4df71b;723e4ba63dbf14c7eb8220447f4df71b;False;black;Auto;Texture2D;-1;0;2;SAMPLER2D;0;SAMPLERSTATE;1
Node;AmplifyShaderEditor.TextureCoordinatesNode;6;-1471.293,-226.2417;Inherit;False;0;-1;2;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.TextureCoordinatesNode;7;-1210.975,-10.06021;Inherit;False;0;-1;2;3;2;SAMPLER2D;;False;0;FLOAT2;2000,1000;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;3;-1173.711,-327.6265;Inherit;True;Property;_TextureSample0;Texture Sample 0;2;0;Create;True;0;0;0;False;0;False;-1;None;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.IntNode;16;-1088.01,-122.3918;Inherit;False;Property;_Intensity;Intensity;2;0;Create;True;0;0;0;False;0;False;80;80;False;0;1;INT;0
Node;AmplifyShaderEditor.SamplerNode;1;-903.7861,-30.3957;Inherit;True;Property;_RGB_channel;RGB_channel;0;0;Create;True;0;0;0;False;0;False;-1;53f3d0b552b692845868a1a26579997e;1131aa718f18abf459bf3ba2d1c632ef;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.FunctionNode;12;-803.3068,-328.9935;Inherit;False;ConstantBiasScale;-1;;3;63208df05c83e8e49a48ffbdce2e43a0;0;3;3;COLOR;10,0,0,0;False;1;FLOAT;0;False;2;INT;80;False;1;COLOR;0
Node;AmplifyShaderEditor.ColorNode;15;-1087.782,-569.1135;Inherit;False;Constant;_Color0;Color 0;2;0;Create;True;0;0;0;False;0;False;0.8622642,0.9019409,1,0;0,0,0,0;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;9;-463.19,-204.2377;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.StandardSurfaceOutputNode;0;-150.2605,-519.2088;Float;False;True;-1;2;ASEMaterialInspector;0;0;StandardSpecular;LEDScreenShader;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;Back;0;False;-1;0;False;-1;False;0;False;-1;0;False;-1;False;0;Opaque;0.5;True;True;0;False;Opaque;;Geometry;All;16;all;True;True;True;True;0;False;-1;False;0;False;-1;255;False;-1;255;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;False;2;15;10;25;False;0.5;True;0;0;False;-1;0;False;-1;0;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;0;0,0,0,0;VertexOffset;True;False;Cylindrical;False;Relative;0;;-1;-1;-1;-1;0;False;0;0;False;-1;-1;0;False;-1;0;0;0;False;0.1;False;-1;0;False;-1;False;16;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;3;FLOAT3;0,0,0;False;4;FLOAT;0;False;5;FLOAT;0;False;6;FLOAT3;0,0,0;False;7;FLOAT3;0,0,0;False;8;FLOAT;0;False;9;FLOAT;0;False;10;FLOAT;0;False;13;FLOAT3;0,0,0;False;11;FLOAT3;0,0,0;False;12;FLOAT3;0,0,0;False;14;FLOAT4;0,0,0,0;False;15;FLOAT3;0,0,0;False;0
WireConnection;6;2;2;0
WireConnection;3;0;2;0
WireConnection;3;1;6;0
WireConnection;1;1;7;0
WireConnection;12;3;3;0
WireConnection;12;2;16;0
WireConnection;9;0;12;0
WireConnection;9;1;1;0
WireConnection;0;2;9;0
ASEEND*/
//CHKSM=8BDE5EE4654AAC1232ECFD5D7BD263A7A22DD76A