// 广告牌
// 根据视角方向旋转，使其看起来总是面对摄像机。
Shader "Unlit/Billboard"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
        _VetrticalBillboarding ("Vertical Restraints", Range(0, 1)) = 1 // 约束垂直方向的程度（0固定指向方向[up方向不改变，尽量面向摄像机]，1固定法线方向为观察视角[完全面朝摄像机]）
    }
    SubShader {
        // 禁用合批
        Tags { "Queue"="Transparent" "IgnoreProjector"="true" "RenderType"="Transparent" "DisableBatching"="True" }

        Pass
        {
            Tags { "LightMode"="ForwardBase" }

            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off // 正反面都能显示

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
			
			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed4 _Color;
			float _VetrticalBillboarding;

            struct a2v
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
			    float4 pos : SV_POSITION;
			    float2 uv : TEXCOORD0;
            };

            v2f vert (a2v v)
            {
                v2f o;

                // 获取模型空间下的视角位置 viewer
                float center = float3(0, 0, 0); // 以空间原点为锚点
                float3 viewer = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));

                // 当 _VetrticalBillboarding 为 1 时，法线方向固定为视角方向。
                // 当 _VetrticalBillboarding 为 0 时，法线y固定为0，即固定向上方向。
                float3 normalDir = viewer - center;
                normalDir.y = normalDir.y * _VetrticalBillboarding;
                normalDir = normalize(normalDir);

                // 防止法线与向上方向平行得到错误结果，获取合适的粗略向上方向
                float3 upDir = abs(normalDir.y) > 0.999 ? float3(0, 0, 1) : float3(0, 1, 0);
                float3 rightDir = normalize(cross(upDir, normalDir));
                upDir = normalize(cross(normalDir, rightDir)); // 通过归一化后的向右方向最终获得准确的向上方向

                // 对原始位置相对锚点偏移，得到新的顶点位置
                float3 centerOffs = v.vertex.xyz - center;
                float3 localPos = center + rightDir * centerOffs.x + upDir * centerOffs.y + normalDir * centerOffs.z;
                
                o.pos = UnityObjectToClipPos(float4(localPos, 1));
                o.uv = v.uv;

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 c = tex2D(_MainTex, i.uv);
                c.rgb *= _Color.rgb;

                return c;
            }
            ENDCG
        }
    }
    Fallback "Transparent/VertexLit"
}
