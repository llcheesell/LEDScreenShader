// Upgrade NOTE: upgraded instancing buffer 'LEDScreenShader' to new syntax.

// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "LEDScreenShader"
{
	Properties
	{
		_LEDTexture("LEDTexture", 2D) = "white" {}
		_LEDTextureTiles("LEDTextureTiles", Vector) = (100,100,0,0)
		_LEDTextureOffset("LEDTextureOffset", Vector) = (0,0,0,0)
		[HDR]_InputVideo("InputVideo", 2D) = "white" {}
		_BrightnessIntensity("BrightnessIntensity", Int) = 80
		_BaseTexture("BaseTexture", 2D) = "black" {}
		[Normal]_NormalTexture("NormalTexture", 2D) = "bump" {}
		_AlphaMap("AlphaMap", 2D) = "white" {}
		[HDR]_MaskMap("MaskMap", 2D) = "black" {}
		_DistantFadeStart("DistantFadeStart", Range( 0 , 1000)) = 10
		_DistantFadeLength("DistantFadeLength", Range( 0 , 1000)) = 30
		_DistantFadeIntensity("DistantFadeIntensity", Range( 0 , 2000)) = 1
		[HideInInspector] _texcoord( "", 2D ) = "white" {}
		[HideInInspector] __dirty( "", Int ) = 1
	}

	SubShader
	{
		Tags{ "RenderType" = "Transparent"  "Queue" = "Transparent+0" "IgnoreProjector" = "True" "IsEmissive" = "true"  }
		Cull Back
		CGINCLUDE
		#include "UnityShaderVariables.cginc"
		#include "UnityPBSLighting.cginc"
		#include "Lighting.cginc"
		#pragma target 3.0
		#pragma multi_compile_instancing
		struct Input
		{
			float2 uv_texcoord;
			float eyeDepth;
		};

		uniform sampler2D _NormalTexture;
		uniform float2 _LEDTextureOffset;
		uniform sampler2D _BaseTexture;
		uniform float _DistantFadeLength;
		uniform float _DistantFadeStart;
		uniform sampler2D _InputVideo;
		uniform float4 _InputVideo_ST;
		uniform int _BrightnessIntensity;
		uniform sampler2D _LEDTexture;
		uniform float _DistantFadeIntensity;
		uniform sampler2D _MaskMap;
		uniform sampler2D _AlphaMap;

		UNITY_INSTANCING_BUFFER_START(LEDScreenShader)
			UNITY_DEFINE_INSTANCED_PROP(float2, _LEDTextureTiles)
#define _LEDTextureTiles_arr LEDScreenShader
		UNITY_INSTANCING_BUFFER_END(LEDScreenShader)

		void vertexDataFunc( inout appdata_full v, out Input o )
		{
			UNITY_INITIALIZE_OUTPUT( Input, o );
			o.eyeDepth = -UnityObjectToViewPos( v.vertex.xyz ).z;
		}

		void surf( Input i , inout SurfaceOutputStandard o )
		{
			float2 _LEDTextureTiles_Instance = UNITY_ACCESS_INSTANCED_PROP(_LEDTextureTiles_arr, _LEDTextureTiles);
			float2 uv_TexCoord7 = i.uv_texcoord * _LEDTextureTiles_Instance + _LEDTextureOffset;
			o.Normal = tex2D( _NormalTexture, uv_TexCoord7 ).rgb;
			o.Albedo = tex2D( _BaseTexture, uv_TexCoord7 ).rgb;
			float cameraDepthFade17 = (( i.eyeDepth -_ProjectionParams.y - _DistantFadeStart ) / _DistantFadeLength);
			float clampResult45 = clamp( cameraDepthFade17 , 0.0 , 1.0 );
			float2 uv_InputVideo = i.uv_texcoord * _InputVideo_ST.xy + _InputVideo_ST.zw;
			float4 tex2DNode3 = tex2D( _InputVideo, uv_InputVideo );
			float layeredBlendVar40 = clampResult45;
			float4 layeredBlend40 = ( lerp( ( ( ( tex2DNode3 + 0.0 ) * _BrightnessIntensity ) * tex2D( _LEDTexture, uv_TexCoord7 ) ),( ( tex2DNode3 + 0.0 ) * _DistantFadeIntensity ) , layeredBlendVar40 ) );
			o.Emission = layeredBlend40.rgb;
			float4 tex2DNode27 = tex2D( _MaskMap, uv_TexCoord7 );
			o.Metallic = tex2DNode27.r;
			o.Smoothness = tex2DNode27.a;
			o.Occlusion = tex2DNode27.g;
			o.Alpha = tex2D( _AlphaMap, uv_TexCoord7 ).r;
		}

		ENDCG
		CGPROGRAM
		#pragma surface surf Standard alpha:fade keepalpha fullforwardshadows exclude_path:deferred vertex:vertexDataFunc 

		ENDCG
		Pass
		{
			Name "ShadowCaster"
			Tags{ "LightMode" = "ShadowCaster" }
			ZWrite On
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.0
			#pragma multi_compile_shadowcaster
			#pragma multi_compile UNITY_PASS_SHADOWCASTER
			#pragma skip_variants FOG_LINEAR FOG_EXP FOG_EXP2
			#include "HLSLSupport.cginc"
			#if ( SHADER_API_D3D11 || SHADER_API_GLCORE || SHADER_API_GLES || SHADER_API_GLES3 || SHADER_API_METAL || SHADER_API_VULKAN )
				#define CAN_SKIP_VPOS
			#endif
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "UnityPBSLighting.cginc"
			sampler3D _DitherMaskLOD;
			struct v2f
			{
				V2F_SHADOW_CASTER;
				float3 customPack1 : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
				float4 tSpace0 : TEXCOORD3;
				float4 tSpace1 : TEXCOORD4;
				float4 tSpace2 : TEXCOORD5;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};
			v2f vert( appdata_full v )
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID( v );
				UNITY_INITIALIZE_OUTPUT( v2f, o );
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO( o );
				UNITY_TRANSFER_INSTANCE_ID( v, o );
				Input customInputData;
				vertexDataFunc( v, customInputData );
				float3 worldPos = mul( unity_ObjectToWorld, v.vertex ).xyz;
				half3 worldNormal = UnityObjectToWorldNormal( v.normal );
				half3 worldTangent = UnityObjectToWorldDir( v.tangent.xyz );
				half tangentSign = v.tangent.w * unity_WorldTransformParams.w;
				half3 worldBinormal = cross( worldNormal, worldTangent ) * tangentSign;
				o.tSpace0 = float4( worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x );
				o.tSpace1 = float4( worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y );
				o.tSpace2 = float4( worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z );
				o.customPack1.xy = customInputData.uv_texcoord;
				o.customPack1.xy = v.texcoord;
				o.customPack1.z = customInputData.eyeDepth;
				o.worldPos = worldPos;
				TRANSFER_SHADOW_CASTER_NORMALOFFSET( o )
				return o;
			}
			half4 frag( v2f IN
			#if !defined( CAN_SKIP_VPOS )
			, UNITY_VPOS_TYPE vpos : VPOS
			#endif
			) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID( IN );
				Input surfIN;
				UNITY_INITIALIZE_OUTPUT( Input, surfIN );
				surfIN.uv_texcoord = IN.customPack1.xy;
				surfIN.eyeDepth = IN.customPack1.z;
				float3 worldPos = IN.worldPos;
				half3 worldViewDir = normalize( UnityWorldSpaceViewDir( worldPos ) );
				SurfaceOutputStandard o;
				UNITY_INITIALIZE_OUTPUT( SurfaceOutputStandard, o )
				surf( surfIN, o );
				#if defined( CAN_SKIP_VPOS )
				float2 vpos = IN.pos;
				#endif
				half alphaRef = tex3D( _DitherMaskLOD, float3( vpos.xy * 0.25, o.Alpha * 0.9375 ) ).a;
				clip( alphaRef - 0.01 );
				SHADOW_CASTER_FRAGMENT( IN )
			}
			ENDCG
		}
	}
	Fallback "Diffuse"
	CustomEditor "ASEMaterialInspector"
}
/*ASEBEGIN
Version=18935
0;606;2082.333;744.6667;2000.808;896.9584;1;True;True
Node;AmplifyShaderEditor.TexturePropertyNode;2;-1789.284,153.141;Inherit;True;Property;_InputVideo;InputVideo;3;1;[HDR];Create;True;0;0;0;False;0;False;None;None;False;white;Auto;Texture2D;-1;0;2;SAMPLER2D;0;SAMPLERSTATE;1
Node;AmplifyShaderEditor.Vector2Node;31;-1730.249,-824.2637;Inherit;False;InstancedProperty;_LEDTextureTiles;LEDTextureTiles;1;0;Create;True;0;0;0;False;0;False;100,100;100,100;0;3;FLOAT2;0;FLOAT;1;FLOAT;2
Node;AmplifyShaderEditor.TextureCoordinatesNode;6;-1532.925,251.0529;Inherit;False;0;-1;2;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.Vector2Node;33;-1733.748,-696.2715;Inherit;False;Property;_LEDTextureOffset;LEDTextureOffset;2;0;Create;True;0;0;0;False;0;False;0,0;0,0;0;3;FLOAT2;0;FLOAT;1;FLOAT;2
Node;AmplifyShaderEditor.RangedFloatNode;19;-835.6564,756.1196;Inherit;False;Property;_DistantFadeStart;DistantFadeStart;9;0;Create;True;0;0;0;False;0;False;10;0;0;1000;0;1;FLOAT;0
Node;AmplifyShaderEditor.IntNode;16;-1178.781,378.3923;Inherit;False;Property;_BrightnessIntensity;BrightnessIntensity;4;0;Create;True;0;0;0;False;0;False;80;80;False;0;1;INT;0
Node;AmplifyShaderEditor.RangedFloatNode;18;-835.473,675.6519;Inherit;False;Property;_DistantFadeLength;DistantFadeLength;10;0;Create;True;0;0;0;False;0;False;30;0;0;1000;0;1;FLOAT;0
Node;AmplifyShaderEditor.TextureCoordinatesNode;7;-1496.674,-699.4337;Inherit;False;0;-1;2;3;2;SAMPLER2D;;False;0;FLOAT2;2000,1000;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;3;-1264.482,173.1577;Inherit;True;Property;_TextureSample0;Texture Sample 0;2;0;Create;True;0;0;0;False;0;False;-1;None;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;1;-1227.232,-532.3691;Inherit;True;Property;_LEDTexture;LEDTexture;0;0;Create;True;0;0;0;False;0;False;-1;40995f7a6e4074451a7646b65ff61a06;1131aa718f18abf459bf3ba2d1c632ef;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.RangedFloatNode;42;-642.7348,316.2481;Inherit;False;Property;_DistantFadeIntensity;DistantFadeIntensity;11;0;Create;True;0;0;0;False;0;False;1;100;0;2000;0;1;FLOAT;0
Node;AmplifyShaderEditor.CameraDepthFade;17;-411.982,696.5834;Inherit;False;3;2;FLOAT3;0,0,0;False;0;FLOAT;1;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;12;-894.0785,171.7907;Inherit;False;ConstantBiasScale;-1;;3;63208df05c83e8e49a48ffbdce2e43a0;0;3;3;COLOR;10,0,0,0;False;1;FLOAT;0;False;2;INT;80;False;1;COLOR;0
Node;AmplifyShaderEditor.TexturePropertyNode;23;-809.9808,-789.1049;Inherit;True;Property;_BaseTexture;BaseTexture;5;0;Create;True;0;0;0;False;0;False;cdb43915b2cf04400a9107000ca8ab26;None;False;black;LockedToTexture2D;Texture2D;-1;0;2;SAMPLER2D;0;SAMPLERSTATE;1
Node;AmplifyShaderEditor.ClampOpNode;45;-280.077,557.7511;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;9;-463.19,-232.5986;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.TexturePropertyNode;26;-830.223,-1229.729;Inherit;True;Property;_MaskMap;MaskMap;8;1;[HDR];Create;True;0;0;0;False;0;False;7a81ba4cd306441db9267d6b1340d044;None;False;black;LockedToTexture2D;Texture2D;-1;0;2;SAMPLER2D;0;SAMPLERSTATE;1
Node;AmplifyShaderEditor.TexturePropertyNode;24;-804.5828,-613.6763;Inherit;True;Property;_NormalTexture;NormalTexture;6;1;[Normal];Create;True;0;0;0;False;0;False;78bbb74e77f194cb09d583ed3be6658c;None;True;bump;LockedToTexture2D;Texture2D;-1;0;2;SAMPLER2D;0;SAMPLERSTATE;1
Node;AmplifyShaderEditor.TexturePropertyNode;25;-817.4827,-992.2581;Inherit;True;Property;_AlphaMap;AlphaMap;7;0;Create;True;0;0;0;False;0;False;None;None;False;white;LockedToTexture2D;Texture2D;-1;0;2;SAMPLER2D;0;SAMPLERSTATE;1
Node;AmplifyShaderEditor.FunctionNode;41;-311.2746,199.6591;Inherit;False;ConstantBiasScale;-1;;5;63208df05c83e8e49a48ffbdce2e43a0;0;3;3;COLOR;10,0,0,0;False;1;FLOAT;0;False;2;FLOAT;80;False;1;COLOR;0
Node;AmplifyShaderEditor.SamplerNode;28;-541.0975,-998.6613;Inherit;True;Property;_TextureSample3;Texture Sample 3;9;0;Create;True;0;0;0;False;0;False;-1;None;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.LayeredBlendNode;40;4.950106,-244.1899;Inherit;False;6;0;FLOAT;0;False;1;COLOR;0,0,0,0;False;2;COLOR;0,0,0,0;False;3;FLOAT;0;False;4;FLOAT;0;False;5;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.SamplerNode;30;-538.7419,-633.2709;Inherit;True;Property;_TextureSample5;Texture Sample 5;12;0;Create;True;0;0;0;False;0;False;-1;None;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;27;-565.7319,-1236.477;Inherit;True;Property;_TextureSample2;Texture Sample 2;10;0;Create;True;0;0;0;False;0;False;-1;None;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;29;-534.6935,-788.458;Inherit;True;Property;_TextureSample4;Texture Sample 4;11;0;Create;True;0;0;0;False;0;False;-1;None;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.StandardSurfaceOutputNode;0;302.981,-618.8895;Float;False;True;-1;2;ASEMaterialInspector;0;0;Standard;LEDScreenShader;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;False;False;False;False;False;False;Back;0;False;-1;0;False;-1;False;0;False;-1;0;False;-1;False;0;Transparent;0.5;True;True;0;False;Transparent;;Transparent;ForwardOnly;18;all;True;True;True;True;0;False;-1;False;0;False;-1;255;False;-1;255;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;False;2;15;10;25;False;0.5;True;2;5;False;-1;10;False;-1;0;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;0;0,0,0,0;VertexOffset;True;False;Cylindrical;False;True;Relative;0;;-1;0;-1;-1;0;False;0;0;False;-1;-1;0;False;-1;0;0;0;False;0.1;False;-1;0;False;-1;False;16;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;3;FLOAT;0;False;4;FLOAT;0;False;5;FLOAT;0;False;6;FLOAT3;0,0,0;False;7;FLOAT3;0,0,0;False;8;FLOAT;0;False;9;FLOAT;0;False;10;FLOAT;0;False;13;FLOAT3;0,0,0;False;11;FLOAT3;0,0,0;False;12;FLOAT3;0,0,0;False;14;FLOAT4;0,0,0,0;False;15;FLOAT3;0,0,0;False;0
WireConnection;6;2;2;0
WireConnection;7;0;31;0
WireConnection;7;1;33;0
WireConnection;3;0;2;0
WireConnection;3;1;6;0
WireConnection;1;1;7;0
WireConnection;17;0;18;0
WireConnection;17;1;19;0
WireConnection;12;3;3;0
WireConnection;12;2;16;0
WireConnection;45;0;17;0
WireConnection;9;0;12;0
WireConnection;9;1;1;0
WireConnection;41;3;3;0
WireConnection;41;2;42;0
WireConnection;28;0;25;0
WireConnection;28;1;7;0
WireConnection;40;0;45;0
WireConnection;40;1;9;0
WireConnection;40;2;41;0
WireConnection;30;0;24;0
WireConnection;30;1;7;0
WireConnection;27;0;26;0
WireConnection;27;1;7;0
WireConnection;29;0;23;0
WireConnection;29;1;7;0
WireConnection;0;0;29;0
WireConnection;0;1;30;0
WireConnection;0;2;40;0
WireConnection;0;3;27;1
WireConnection;0;4;27;4
WireConnection;0;5;27;2
WireConnection;0;9;28;0
ASEEND*/
//CHKSM=16ADF71A0F99DF4179B4A37F61074A3C47BDEBBF