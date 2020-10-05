// 折射
Shader "USB/CH10/Refraction"
{
    Properties
    {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
        _RefractColor ("Refraction Color", Color) = (1, 1, 1, 1)
        _RefractAmount ("Refract Amount", Range(0, 1)) = 1
        _RefractRatio ("Refract Ratio", Range(0.1, 1)) = 0.5
        _Cubemap ("Refraction Cubemap", Cube) = "_Skybox" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }

        Pass
        {
			Tags { "LightMode"="ForwardBase" }

            CGPROGRAM

			#pragma multi_compile_fwdbase

            #pragma vertex vert
            #pragma fragment frag

			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			
			fixed4 _Color;
			fixed4 _RefractColor;
            float _RefractAmount;
            fixed _RefractRatio;
			samplerCUBE _Cubemap;

            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal: NORMAL;
            };

            struct v2f
            {
				float4 pos : SV_POSITION;
				float3 worldPos : TEXCOORD0;
				fixed3 worldNormal : TEXCOORD1;
				fixed3 worldViewDir : TEXCOORD2;
				fixed3 worldRefr : TEXCOORD3;
				SHADOW_COORDS(4)
            };

            v2f vert (a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldViewDir = UnityWorldSpaceViewDir(o.worldPos);

                // 在世界空间下计算折射方向
                // refract(入射光线方向, 表面法线方向, 光线来源介质折射率 ÷ 光线射入介质折射率)，返回折射方向
                // refract(入射光线方向, 表面法线方向, (空气 1.0) ÷ 光线射入介质折射率)
                o.worldRefr = refract(-normalize(o.worldViewDir), normalize(o.worldNormal), _RefractRatio);

                TRANSFER_SHADOW(o);
                
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
				fixed3 worldNormal = normalize(i.worldNormal);
				fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));		
				fixed3 worldViewDir = normalize(i.worldViewDir);

				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
				
				fixed3 diffuse = _LightColor0.rgb * _Color.rgb * max(0, dot(worldNormal, worldLightDir));

                // 使用 texCUBE 世界空间下的*折射*方向采样 CubeMap
                fixed3 refraction = texCUBE(_Cubemap, i.worldRefr).rgb * _RefractColor.rgb;

                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

                // 根据 _RefractAmount 混合漫反射颜色和折射颜色，与光照相加后返回
                fixed3 color = ambient + lerp(diffuse, refraction, _RefractAmount) * atten;
				
                return fixed4(color, 1.0);
            }
            ENDCG
        }
    }
}
