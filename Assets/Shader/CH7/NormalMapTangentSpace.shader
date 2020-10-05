/**
 * 在*切线空间*下进行光照计算的法线贴图实现
 * 效率更优。在顶点着色器中完成光照方向和视角方向的变换。
 */
Shader "USB/CH7/Normal Map In Tangent Space"
{
    Properties
    {
        _Color ("Color Tint", Color) = (1,1,1,1)
        _MainTex ("Main Tex", 2D) = "white" {}
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _BumpScale ("Bump Scale", Float) = 1.0
        _Specular ("Specular", Color) = (1, 1, 1, 1)
        _Gloss ("Gloss", Range(8.0, 256)) = 20
    }
    SubShader
    {
        Pass
        {
            Tags { "LightMode" = "ForwardBase" }

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Lighting.cginc"

            fixed4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _BumpMap;
            float4 _BumpMap_ST;
            float _BumpScale;
            fixed4 _Specular;
            float _Gloss;

            struct a2v {
                float4 vertex: POSITION;
                float3 normal: NORMAL;
                float4 tangent: TANGENT;
                float4 texcoord: TEXCOORD0;
            };

            struct v2f {
                float4 pos: SV_POSITION;
                float4 uv: TEXCOORD0;
                float3 lightDir: TEXCOORD1;
                float3 viewDir: TEXCOORD2;
            };

            v2f vert(a2v v) {
                v2f o;
                
                // Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
                o.pos = UnityObjectToClipPos(v.vertex);

                // xy 分量存 MainTex 的纹理坐标，zw 分量存 BumpMao 的纹理坐标
                // 实际上，MainTex 和 BumpMap 通常会使用同一组纹理坐标，只存一个纹理坐标即可
                o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                o.uv.zw = v.texcoord.xy * _BumpMap_ST.xy + _BumpMap_ST.zw;

                // 计算副切线，并组成从模型空间到切线空间的变换矩阵 rotation
                // TANGENT_SPACE_ROTATION 定义在 UnityCG.cginc，相当于：
                // float3 binormal = cross(normalize(v.normal), normalize(v.tangent.xyz)) * v.tangent.w;
                // float3x3 rotation = float3x3(v.tangent.xyz, binormal, v.normal); // 切线方向、副切线方向、法线方向
                TANGENT_SPACE_ROTATION;

                // 获取光照方向，并从模型空间转换到切线空间
                o.lightDir = mul(rotation, ObjSpaceLightDir(v.vertex)).xyz;
                // 获取视角方向，并从模型空间转换到切线空间
                o.viewDir = mul(rotation, ObjSpaceViewDir(v.vertex)).xyz;

                return o;
            }

            fixed4 frag(v2f i) : SV_Target{
                fixed3 tangentLightDir = normalize(i.lightDir);
                fixed3 tangentViewDir = normalize(i.viewDir);

                // 获取法线贴图 Texel
                fixed4 packedNormal = tex2D(_BumpMap, i.uv.zw);
                fixed3 tangentNormal;

                // 如果贴图未设为 Normal Map，手动把法线从 [0, 1] 映射回 [-1, 1]
                // tangentNormal.xy = (packedNormal.xy * 2 - 1) * _BumpScale;
                // tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));

                // 将贴图设为 Normal Map
                // 使用内置函数（Unity会根据平台优化压缩 Normal Map [2通道DXT5nm格式]，所以不能使用手动方法）
                tangentNormal = UnpackNormal(packedNormal);
                tangentNormal.xy *= _BumpScale;
                tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));

                fixed3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
                fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(tangentNormal, tangentLightDir));

                fixed3 halfDir = normalize(tangentLightDir + tangentViewDir);
                fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(tangentNormal, halfDir)), _Gloss);

                return fixed4(ambient + diffuse + specular, 1.0);
            }

            ENDCG
        }
    }
    FallBack "Specular"
}
