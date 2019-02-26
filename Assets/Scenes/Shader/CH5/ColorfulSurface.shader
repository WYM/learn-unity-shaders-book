Shader "USB/CH5/ColorfulSurface" {
    // 输入的属性，可以在编辑器的材质面板中编辑值，相当于 OpenGl 的 Uniform
    Properties {
        _Color("Color Tint", Color) = (1.0, 1.0, 1.0, 1.0)
    }
    // 每个 SubShader 都是Shader的一种实现，不支持时就会使用下一种，直到Fallback
    SubShader {
        // 每个 Pass 是一个渲染流程
        Pass {
            CGPROGRAM // 与结尾的 ENDCG 对应，代表中间内容为 Cg 代码

            // 定义顶点和片段着色器
            #pragma vertex vert
            #pragma fragment frag

            // Properties中定义的属性 在这里声明一下才可使用
            fixed4 _Color;

            // 定义应用程序传入顶点着色器数据的结构
            struct a2v {
                float4 vertex: POSITION; // 顶点
                float3 normal: NORMAL; // 法线
                float4 texcoord: TEXCOORD0; // texcoord
            };

            // 定义顶点着色器传入片段着色器数据的结构
            struct v2f {
                float4 pos: SV_POSITION;
                fixed3 color: COLOR0;
            };

            v2f vert(a2v v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.color = v.normal * 0.5 + fixed3(0.5, 0.8, 0.5);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target {
                fixed3 c = i.color;
                c *= _Color.rgb;
                return fixed4(c, 1.0);
            }

            ENDCG
        }
    }
}