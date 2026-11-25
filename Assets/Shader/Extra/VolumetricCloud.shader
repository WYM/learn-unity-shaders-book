Shader "USB/Extra/VolumetricCloud"
{
    Properties
    {
        _Color ("Cloud Color", Color) = (1, 1, 1, 1)
        _AmbientColor ("Ambient Color", Color) = (0.42, 0.52, 0.68, 1)
        _Coverage ("Coverage", Range(0, 1)) = 0.55
        _Softness ("Softness", Range(0.01, 1)) = 0.28
        _NoiseScale ("Noise Scale", Range(0.5, 10)) = 2.4
        _NoiseOffset ("Noise Offset", Vector) = (0, 0, 0, 0)
        _NoiseSpeed ("Noise Speed", Range(0, 1)) = 0.03
        _DetailScale ("Detail Scale", Range(1, 8)) = 3.2
        _DetailStrength ("Detail Strength", Range(0, 1)) = 0.22
        _HeightFalloff ("Height Falloff", Range(0, 1)) = 0.7
        _EdgeFade ("Edge Fade", Range(0.001, 0.3)) = 0.08
        _Steps ("Raymarch Steps", Range(8, 64)) = 32
        _Density ("Density", Range(0, 30)) = 9
        _Opacity ("Opacity", Range(0, 1)) = 0.9
        _AmbientStrength ("Ambient Strength", Range(0, 2)) = 0.8
        _LightAbsorption ("Light Absorption", Range(0, 20)) = 5
        _SilverLiningStrength ("Silver Lining Strength", Range(0, 3)) = 0.8
        _SilverLiningPower ("Silver Lining Power", Range(1, 16)) = 5
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "DisableBatching"="True" }

        Pass
        {
            Tags { "LightMode"="ForwardBase" }

            Cull Front
            ZWrite Off
            Blend One OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            #define MAX_STEPS 64
            #define LIGHT_STEPS 3

            fixed4 _Color;
            fixed4 _AmbientColor;
            float _Coverage;
            float _Softness;
            float _NoiseScale;
            float4 _NoiseOffset;
            float _NoiseSpeed;
            float _DetailScale;
            float _DetailStrength;
            float _HeightFalloff;
            float _EdgeFade;
            float _Steps;
            float _Density;
            float _Opacity;
            float _AmbientStrength;
            float _LightAbsorption;
            float _SilverLiningStrength;
            float _SilverLiningPower;

            struct a2v
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 objPos : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
            };

            v2f vert (a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.objPos = v.vertex.xyz;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            float hash13 (float3 p)
            {
                return frac(sin(dot(p, float3(127.1, 311.7, 74.7))) * 43758.5453123);
            }

            float noise3d (float3 p)
            {
                float3 i = floor(p);
                float3 f = frac(p);
                float3 u = f * f * (3.0 - 2.0 * f);

                float n000 = hash13(i + float3(0, 0, 0));
                float n100 = hash13(i + float3(1, 0, 0));
                float n010 = hash13(i + float3(0, 1, 0));
                float n110 = hash13(i + float3(1, 1, 0));
                float n001 = hash13(i + float3(0, 0, 1));
                float n101 = hash13(i + float3(1, 0, 1));
                float n011 = hash13(i + float3(0, 1, 1));
                float n111 = hash13(i + float3(1, 1, 1));

                float nx00 = lerp(n000, n100, u.x);
                float nx10 = lerp(n010, n110, u.x);
                float nx01 = lerp(n001, n101, u.x);
                float nx11 = lerp(n011, n111, u.x);
                float nxy0 = lerp(nx00, nx10, u.y);
                float nxy1 = lerp(nx01, nx11, u.y);
                return lerp(nxy0, nxy1, u.z);
            }

            float fbm (float3 p)
            {
                float value = 0.0;
                float amplitude = 0.5;

                for (int octave = 0; octave < 3; octave++)
                {
                    value += noise3d(p) * amplitude;
                    p = p * 2.03 + float3(17.13, 9.31, 5.77);
                    amplitude *= 0.5;
                }

                return value / 0.875;
            }

            // 单位 Cube 的模型空间范围是 [-0.5, 0.5]，直接用它作为体积包围盒。
            float2 rayBoxIntersect (float3 rayOrigin, float3 rayDir)
            {
                float3 boxMin = float3(-0.5, -0.5, -0.5);
                float3 boxMax = float3(0.5, 0.5, 0.5);
                float3 invDir = 1.0 / rayDir;
                float3 t0 = (boxMin - rayOrigin) * invDir;
                float3 t1 = (boxMax - rayOrigin) * invDir;
                float3 tMin = min(t0, t1);
                float3 tMax = max(t0, t1);

                float enterT = max(max(tMin.x, tMin.y), tMin.z);
                float exitT = min(min(tMax.x, tMax.y), tMax.z);
                return float2(enterT, exitT);
            }

            float sampleDensity (float3 pos)
            {
                float3 edgeDistance = 0.5 - abs(pos);
                float edge = min(edgeDistance.x, min(edgeDistance.y, edgeDistance.z));
                float edgeFade = smoothstep(0.0, max(_EdgeFade, 0.001), edge);

                float3 noisePos = pos * _NoiseScale + _NoiseOffset.xyz;
                noisePos += float3(_Time.y * _NoiseSpeed, _Time.y * _NoiseSpeed * 0.13, _Time.y * _NoiseSpeed * 0.31);

                float baseNoise = fbm(noisePos);
                float detailNoise = fbm(noisePos * _DetailScale + float3(19.19, 7.31, 3.17));

                float coverageStart = 1.0 - saturate(_Coverage);
                float shape = smoothstep(coverageStart, coverageStart + max(_Softness, 0.001), baseNoise);
                shape = saturate(shape - detailNoise * _DetailStrength);

                float height01 = saturate(pos.y + 0.5);
                float heightFade = smoothstep(0.0, 0.22, height01) * (1.0 - smoothstep(0.62, 1.0, height01));
                shape *= lerp(1.0, heightFade, saturate(_HeightFalloff));

                return saturate(shape * edgeFade);
            }

            float lightMarch (float3 pos, float3 lightDir)
            {
                float2 hit = rayBoxIntersect(pos, lightDir);
                float maxDistance = max(hit.y, 0.0);
                float stepSize = maxDistance / (LIGHT_STEPS + 1.0);
                float lightDensity = 0.0;

                for (int lightStep = 0; lightStep < LIGHT_STEPS; lightStep++)
                {
                    float3 samplePos = pos + lightDir * stepSize * (lightStep + 1.0);
                    lightDensity += sampleDensity(samplePos) * stepSize;
                }

                return lightDensity;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 rayOrigin = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos.xyz, 1.0)).xyz;
                float3 rayDir = normalize(i.objPos - rayOrigin);
                float2 hit = rayBoxIntersect(rayOrigin, rayDir);

                float startT = max(hit.x, 0.0);
                float endT = hit.y;
                if (endT <= startT)
                {
                    return fixed4(0, 0, 0, 0);
                }

                int steps = (int)clamp(_Steps, 1.0, (float)MAX_STEPS);
                float stepSize = (endT - startT) / (float)steps;
                float3 lightDir = normalize(mul((float3x3)unity_WorldToObject, _WorldSpaceLightPos0.xyz));
                float3 worldRayDir = normalize(i.worldPos - _WorldSpaceCameraPos.xyz);
                float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);

                float transmittance = 1.0;
                float3 scattering = 0.0;

                for (int rayStep = 0; rayStep < MAX_STEPS; rayStep++)
                {
                    if (rayStep >= steps)
                    {
                        break;
                    }

                    float travelT = startT + ((float)rayStep + 0.5) * stepSize;
                    float3 pos = rayOrigin + rayDir * travelT;
                    float density = sampleDensity(pos);

                    if (density > 0.001)
                    {
                        float lightDensity = lightMarch(pos, lightDir);
                        float lightTransmittance = exp(-lightDensity * _Density * _LightAbsorption);
                        float forwardScattering = pow(saturate(dot(worldRayDir, worldLightDir)), max(_SilverLiningPower, 0.001));
                        float3 lighting = _AmbientColor.rgb * _AmbientStrength + _LightColor0.rgb * lightTransmittance * (1.0 + forwardScattering * _SilverLiningStrength);

                        float sampleAlpha = 1.0 - exp(-density * _Density * stepSize);
                        scattering += transmittance * _Color.rgb * lighting * sampleAlpha;
                        transmittance *= 1.0 - sampleAlpha;

                        if (transmittance < 0.01)
                        {
                            break;
                        }
                    }
                }

                float alpha = saturate((1.0 - transmittance) * _Opacity);
                return fixed4(scattering * _Opacity, alpha);
            }
            ENDCG
        }
    }
    Fallback "Transparent/VertexLit"
}
