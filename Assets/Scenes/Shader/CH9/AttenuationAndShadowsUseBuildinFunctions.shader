Shader "USB/CH9/Attenuation And Shadows Use Buildin Functions"
{
    Properties
    {
        _Diffuse("Diffuse", Color) = (1, 1, 1, 1)
        _Specular("Specular", Color) = (1, 1, 1, 1) // 高光反射颜色
        _Gloss("Gloss", Range(8.0, 256)) = 20 // 高光区域大小
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" }

        // 光源的 Render Mode
        // 设为 Not Important 时，光源不会按逐像素处理
        // 渲染顺序根据重要度排序，重要度取决于强度和远近（文档无重要度排序的具体规则说明）。

        // Base Pass 首先计算环境光。
        // 每个光源有5个属性：未知、方向、颜色、强度、衰减
        // 当场景中有多个平行光时，Unity会传入最亮的一个给BasePass逐像素处理，其他的平行光会按逐顶点或在Additional Pass中逐像素处理。
        Pass {
            Tags { "LightMode" = "ForwardBase" }

            CGPROGRAM

            // 保证光照衰减等光照变量
            #pragma multi_compile_fwdbase

            #pragma vertex vert
            #pragma fragment frag

            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            fixed4 _Diffuse;
            fixed4 _Specular;
            float _Gloss;

            struct a2v {
                float4 vertex: POSITION;
                float3 normal: NORMAL;
            };

            struct v2f {
                float4 pos: SV_POSITION;
                float3 worldNormal: TEXCOORD0;
                float3 worldPos: TEXCOORD1;
                SHADOW_COORDS(2)
            };

            v2f vert(a2v v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

                TRANSFER_SHADOW(o);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target{

                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLight = normalize(_WorldSpaceLightPos0.xyz);

                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

                fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * max(0, dot(worldNormal, worldLight));

                fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
                fixed3 halfDir = normalize(worldLight + viewDir);

                fixed3 specular = _LightColor0.rgb * _Specular.rgb * (pow(max(0, dot(worldNormal, halfDir)), _Gloss));

                // 使用内置宏计算光衰减和阴影，结果输出到 atten 变量
                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
                return fixed4(ambient + (diffuse + specular) * atten, 1.0);
            }

            ENDCG
        }

        // 将点光源一个个应用到物体上，每个额外的逐像素光源都会调用一次
        Pass {
            Tags { "LightMode" = "ForwardAdd" }
            Blend One One // 设置Blend是为了不要覆盖之前的光照结果，也可以用 Blend SrcAlpha One 或其他的

            CGPROGRAM

            // 引用光照变量
            #pragma multi_compile_fwdadd

            #pragma vertex vert
            #pragma fragment frag

            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            fixed4 _Diffuse;
            fixed4 _Specular;
            float _Gloss;

            struct a2v {
                float4 vertex: POSITION;
                float3 normal: NORMAL;
            };

            struct v2f {
                float4 pos: SV_POSITION;
                float3 worldNormal: TEXCOORD0;
                float3 worldPos: TEXCOORD1;
                SHADOW_COORDS(2)
            };

            v2f vert(a2v v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                TRANSFER_SHADOW(o);
                return o;
            }

            // 可能的光源类型：平行光、点光源、聚光灯
            fixed4 frag(v2f i) : SV_Target {
                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));

                fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * max(0, dot(worldNormal, worldLightDir));

                fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
                fixed3 halfDir = normalize(worldLightDir + viewDir);
                fixed3 specular = _LightColor0.rgb * _Specular.rgb * (pow(max(0, dot(worldNormal, halfDir)), _Gloss));

                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
                return fixed4((diffuse + specular) * atten, 1.0);
            }

            ENDCG
        }
    }

    // 因为 FallBack，使得没有 ShadowCaster Pass 的 ForwardRendering 使用了从 Specular -> VertexLit 继承的 ShadowCaster Pass
    // 代码：buildin-shaders-xxx/DefaultResourcesExtra/Normal->VertexLit.shader
    FallBack "Specular"
}
