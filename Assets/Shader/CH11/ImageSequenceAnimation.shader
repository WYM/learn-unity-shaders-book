// 序列帧动画
Shader "USB/CH10/ImageSequenceAnimation"
{
    Properties
    {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
        _MainTex ("ImageSequence", 2D) = "white" {}
        _HorizontalAmount ("Horizontal Amount", Float) = 4
        _VerticalAmount ("Vertical Amount", Float) = 4
        _Speed ("Speed", Range(1, 100)) = 30
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "IgnoreProjector"="true" "RenderType"="Transparent" }

        Pass
        {
            Tags { "LightMode"="ForwardBase" }

            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
			
			fixed4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			float _HorizontalAmount;
			float _VerticalAmount;
			float _Speed;

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
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float columns = max(1.0, floor(_HorizontalAmount));
                float rows = max(1.0, floor(_VerticalAmount));
                float frameCount = columns * rows;
                float frame = floor(_Time.y * _Speed);
                float frameInLoop = frame - floor(frame / frameCount) * frameCount;
                float row = floor(frameInLoop / columns);
                float column = frameInLoop - row * columns;

                // 图集从左上角开始排列，纹理 UV 的原点在左下角。
                float2 uv = (i.uv + float2(column, rows - 1.0 - row)) / float2(columns, rows);

                fixed4 c = tex2D(_MainTex, uv);
                c.rgb *= _Color;

                return c;
            }
            ENDCG
        }
    }
    Fallback "Transparent/VertexLit"
}
