
Shader "USB/CH9/Shadow"
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

            // 引入帮助计算阴影的 SHADOW_COORDS, TRANSFER_SHADOW, SHADOW_ATTENUATION
            // Unity 会自动在支持的平台上使用屏幕空间阴影
            // 关闭阴影时，SHADOW_ATTENUATION 的结果固定为 1
            // 使用宏时，a2v的顶点坐标变量名必须是vertex，顶点着色器输入结构变量名必须为v，v2f的顶点位置变量名必须为pos。
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
                SHADOW_COORDS(2) // 宏：声明一个对 Shadow Map 采样的坐标，参数为v2f的下一个可用插值寄存器索引(TEXCOORD0, TEXCOORD1, TEXCOORD2)
            };

            v2f vert(a2v v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

                // 计算 Shadow Map 坐标，填入前面声明的 SHADOW_COORD 里
                TRANSFER_SHADOW(o);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target{

                // 采样 Shadow Map
                fixed shadow = SHADOW_ATTENUATION(i);

                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLight = normalize(_WorldSpaceLightPos0.xyz);

                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

                fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * max(0, dot(worldNormal, worldLight));

                fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
                fixed3 halfDir = normalize(worldLight + viewDir);

                fixed3 specular = _LightColor0.rgb * _Specular.rgb * (pow(max(0, dot(worldNormal, halfDir)), _Gloss));

                // 光衰减。平行光的衰减永远为1.0.
                fixed atten = 1.0;
                return fixed4(ambient + (diffuse + specular) * atten * shadow, 1.0);
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
            };

            v2f vert(a2v v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;

            }

            // 可能的光源类型：平行光、点光源、聚光灯
            fixed4 frag(v2f i) : SV_Target {
                fixed3 worldNormal = normalize(i.worldNormal);

                // 计算光源方向
                #ifdef USING_DIRECTIONL_LIGHT // 如果是平行光
                    fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
                #else
                    // 光源方向 = 世界空间下的光源位置 - 世界空间下的顶点位置
                    fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos.xyz);
                #endif

                fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * max(0, dot(worldNormal, worldLightDir));

                fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
                fixed3 halfDir = normalize(worldLightDir + viewDir);
                fixed3 specular = _LightColor0.rgb * _Specular.rgb * (pow(max(0, dot(worldNormal, halfDir)), _Gloss));

                // 光衰减。
                #ifdef USING_DIRECTIONL_LIGHT
                    // 平行光的衰减永远为1.0.
                    fixed atten = 1.0;
                #else
                    // 光源衰减涉及大量计算，Unity使用了一张纹理作为查找表。
                    // 获取光源空间下的坐标，然后使用衰减纹理获得衰减值。
                    // 优点：性能。
                    // 缺点：纹理大小影响精度、不直观。
                    // 注：默认衰减纹理是 _LightTexture0 ，如果光源启用了 cookie ，则衰减纹理为 _LightTextureB0

                    // 手动计算线性衰减：
                    // 因为无法得到光源范围、聚光灯朝向、张开角度等信息，效果往往不尽如人意。（WYM：SRP可以解决该问题？）
                    // float distance = length(_WorldSpaceLightPos0.xyz - i.worldPos.xyz);
                    // fixed atten = 1.0 / distance;

                    // 原书中使用的代码：
                    // float3 lightCoord = mul(unity_WorldToLight, float4(i.worldPos, 1)).xyz;
                    // fixed atten = tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;



                    // 新版代码
                    #if defined (POINT)
                        float3 lightCoord = mul(unity_WorldToLight, float4(i.worldPos, 1)).xyz;
                        // 光源空间中顶点距离平方（dot），避免开方操作。只关心衰减纹理对角线上的颜色值。
                        fixed atten = tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
                    #elif defined (SPOT)
                        float4 lightCoord = mul(unity_WorldToLight, float4(i.worldPos, 1));
                        fixed atten = (lightCoord.z > 0) * tex2D(_LightTexture0, lightCoord.xy / lightCoord.w + 0.5).w * tex2D(_LightTextureB0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
                    #else
                        fixed atten = 1.0;
                    #endif

                #endif

                return fixed4((diffuse + specular) * atten, 1.0);
            }

            ENDCG
        }
    }

    // 因为 FallBack，使得没有 ShadowCaster Pass 的 ForwardRendering 使用了从 Specular -> VertexLit 继承的 ShadowCaster Pass
    // 代码：buildin-shaders-xxx/DefaultResourcesExtra/Normal->VertexLit.shader
    FallBack "Specular"
}
