Shader "USB/CH7/Alpha Blend"
{
    Properties
    {
        _Color ("Color Tint", Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
        _AlphaScale ("Alpha Scale", Range(0, 1)) = 1
    }
    SubShader
    {
        Tags {
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
            "RenderType" = "Transparent"
        }

        Pass
        {
            Tags { "LightMode" = "ForwardBase" }

            ZWrite Off // 关闭深度写入
            Blend SrcAlpha OneMinusSrcAlpha // 混合模式 DstColorNew = SrcAlpha x SrcColor + (1 - SrcAlpha) x DstColorOld;
            
            // 混合因子
            // Output = SrcFactor x Src + DstFactor x Dst;
            // Blend SrcFactor DstFactor // 对RGBA通道使用同一套 factor
            // Blend SrcFactor DstFactor, SrcFactorA DstFactorA // 使用不同的 factor 来混合透明通道

            // 混合操作 BlendOp
            // BlendOp Add      // Output = SrcFactor x Src + DstFactor x Dst;
            // BlendOp Sub      // Output = SrcFactor x Src - DstFactor x Dst;
            // BlendOp RevSub   // Output = DstFactor x Dst - SrcFactor x Src;
            // BlendOp Min      // Output = (min(Src_r, Dst_r), min(Src_g, Dst_g), min(Src_b, Dst_b), min(Src_a, Dst_a));
            // BlendOp Max      // Output = (max(Src_r, Dst_r), max(Src_g, Dst_g), max(Src_b, Dst_b), max(Src_a, Dst_a));
            // 操作为 Min 和 Max 时，Factor 不参与运算（见计算方式）。

            // 常见混合方式，见 8.6.3
            // 例：正常、柔性相加、正片叠底、正片叠底x2、变暗、变亮、滤色、线性减淡

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Lighting.cginc"

            fixed4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed _AlphaScale;

            struct a2v {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 texcoord : TEXCOORD0;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float2 uv : TEXCOORD2;
            };

            v2f vert (a2v v) {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target {
                
                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                fixed4 texColor = tex2D(_MainTex, i.uv);

                fixed3 albedo = texColor.rgb * _Color.rgb;
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
                fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(worldNormal, worldLightDir));

                // 只有使用 Blend 打开混合后，这里设置透明通道才有意义
                return fixed4(ambient + diffuse, texColor.a * _AlphaScale);

            }
            ENDCG
        }
    }

    Fallback "Transparent/VertexLit"
}
