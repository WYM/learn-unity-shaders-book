
// 玻璃折射+反射
Shader "USB/CH10/GlassReflection"
{
    Properties
    {
        _MainTex ("Main Tex", 2D) = "white" {} // 玻璃材质纹理
        _BumpMap ("Normal Map", 2D) = "bump" {} // 法线纹理
        _Cubemap ("Environment Cubemap", Cube) = "_Skybox" {} // 环境纹理
        _Distortion ("Distortion", Range(0, 100)) = 10 // 扭曲程度
        _RefractAmount ("Refract Amount", Range(0.0, 1.0)) = 1.0 // 折射程度（为0时则只有反射）
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Opaque" }

        // 抓取渲染当前 Pass 前的屏幕为一张纹理
        // 可以在下一个 Pass 中使用抓取到的纹理 _RefractionTex
        // 字符串可以省略，但显式定义纹理名称性能更好
        // （如果定义名称，则每帧只在第一次抓取图像，后续复用。如果不定义，则名称为 _GrabTexture，每个物体都会进行一次开销较大的屏幕抓取操作，）
        GrabPass { "_RefractionTex" }

        // RenderTarget 性能优于 GrabPass （特别是移动设备）
        // RenderTarget 可以定义目标纹理大小，而 GrabPass 与当前显示分辨率一致。
        // RebderTarget 会重新渲染场景，GrabPas 不会。但移动设备上，GrabPass 通常会读取 BakcBuffer，CPU 需要等待 GPU 处理完成，比较耗时。
        // 命令缓冲 Command Buffers 也可以通过扩展渲染管线来完成类似抓屏效果。

        Pass
        {
			Tags { "LightMode"="ForwardBase" }

            CGPROGRAM

			#pragma multi_compile_fwdbase

            #pragma vertex vert
            #pragma fragment frag

			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			
            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _BumpMap;
            float4 _BumpMap_ST;
			samplerCUBE _Cubemap;
            float _Distortion;
            fixed _RefractAmount;
            sampler2D _RefractionTex;
            float4 _RefractionTex_TexelSize; // 纹素大小（如256x512的纹理，纹素大小为1/256x1/512）。用于屏幕图像采样坐标偏移。

            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal: NORMAL;
				float4 tangent : TANGENT; 
				float2 texcoord: TEXCOORD0;
            };

            struct v2f
            {
				float4 pos : SV_POSITION;
                float4 scrPos: TEXCOORD0;
                float4 uv: TEXCOORD1;
                float4 TtoW0: TEXCOORD2;
                float4 TtoW1: TEXCOORD3;
                float4 TtoW2: TEXCOORD4;
            };

            v2f vert (a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                
                // 获取抓取屏幕图像的采样坐标，定义在 UnityCG.cginc
                o.scrPos = ComputeGrabScreenPos(o.pos);

                o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.uv.zw = TRANSFORM_TEX(v.texcoord, _BumpMap);

				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;  
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);  
				fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);  
				fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; 
				
				o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
				o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
				o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);  
                
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
				float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
				fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));

                // 切线空间下的法线方向
                fixed3 bump = UnpackNormal(tex2D(_BumpMap, i.uv.zw));

                // 计算切线空间下的纹理坐标偏移后采样屏幕图像（模拟折射效果）
                float2 offset = bump.xy * _Distortion * _RefractionTex_TexelSize.xy;
                i.scrPos.xy = offset + i.scrPos.xy;
                fixed3 refrCol = tex2D(_RefractionTex, i.scrPos.xy / i.scrPos.w).rgb;

                // 把切线空间下的法线方向变换到世界空间
                bump = normalize(half3(dot(i.TtoW0.xyz, bump), dot(i.TtoW1.xyz, bump), dot(i.TtoW2.xyz, bump)));

                // 世界空间下的反射方向
                fixed3 reflDir = reflect(-worldViewDir, bump);
                fixed4 texColor = tex2D(_MainTex, i.uv.xy);
                fixed3 reflCol = texCUBE(_Cubemap, reflDir).rgb * texColor.rgb;
                
                fixed3 finalColor = reflCol * (1 - _RefractAmount) + refrCol * _RefractAmount;

                return fixed4(finalColor, 1.0);
            }
            ENDCG
        }
    }
}
