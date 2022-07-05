Shader "KM/Seascape"
{
    Properties
    {
        [MainTexture] _BaseMap("Base Map", 2D) = "white"
        _iResolution("iResolution", vector) = (1,1,0,0)
        _iMouse("_iMouse", vector) = (0,0,0,0)



        ITER_GEOMETRY("ITER_GEOMETRY",int) = 3
        ITER_FRAGMENT ("ITER_FRAGMENT",int) = 5

        SEA_HEIGHT("SEA_HEIGHT",float) = 0.6
        SEA_CHOPPYT("SEA_CHOPPYT",float) = 4.0
        SEA_SPEEDT("SEA_SPEEDT",float) = 0.8
        SEA_FREQT("SEA_FREQT",float) = 0.16


        SEA_BASE("SEA_BASE", vector) = (0.0,0.09,0.18)
        SEA_WATER_COLOR("SEA_WATER_COLOR", vector) = (0.48,0.54,0.36)

        //float2x2 octave_m = float2x2(1.6,1.2,-1.2,1.6);
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque" "RenderPeipeline" = "UniversalPepeline"
        }
        LOD 100

        Pass
        {
            name "ShaderToy"
            blend one zero
            ZWrite on
            ZTest Lequal
            Cull off
            HLSLPROGRAM
            #pragma  vertex vert
            #pragma  fragment frag

            #define iGlobalTime   _Time.y
            #define iTime   _Time.y
            #define iResolution   _iResolution
            #define iMouse   _iMouse
            #define EPSILON_NRM (0.1 / iResolution.x)
            #define SEA_TIME (1.0 + iTime * SEA_SPEED)


            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            TEXTURE2D_X(_BaseMap);
            SAMPLER(sampler_BaseMap);


            CBUFFER_START(UnityPerMaterial)
            float4 _iResolution;
            float4 _iMouse;
            float4 _BaseMap_ST;

            int ITER_GEOMETRY = 3;
            int ITER_FRAGMENT = 5;
            float SEA_HEIGHT = 0.6;
            float SEA_CHOPPY = 4.0;
            float SEA_SPEED = 0.8;
            float SEA_FREQ = 0.16;
            float3 SEA_BASE = float3(0.0, 0.09, 0.18);
            float3 SEA_WATER_COLOR = float3(0.8, 0.9, 0.6) * 0.6;

            float2x2 octave_m = float2x2(1.6, 1.2, -1.2, 1.6);

            CBUFFER_END


            const int NUM_STEPS = 8;


            //#define AA
            // sea

            // const int ITER_GEOMETRY = 3;
            // const int ITER_FRAGMENT = 5;
            // const float SEA_HEIGHT = 0.6;
            // const float SEA_CHOPPY = 4.0;
            // const float SEA_SPEED = 0.8;
            // const float SEA_FREQ = 0.16;
            // const float3 SEA_BASE = float3(0.0,0.09,0.18);
            // const float3 SEA_WATER_COLOR = float3(0.8,0.9,0.6)*0.6;
            //             
            // const float2x2 octave_m = float2x2(1.6,1.2,-1.2,1.6);


            // math
            float3x3 fromEuler(float3 ang)
            {
                float2 a1 = float2(sin(ang.x), cos(ang.x));
                float2 a2 = float2(sin(ang.y), cos(ang.y));
                float2 a3 = float2(sin(ang.z), cos(ang.z));
                float3x3 m;
                m[0] = float3(a1.y * a3.y + a1.x * a2.x * a3.x, a1.y * a2.x * a3.x + a3.y * a1.x, -a2.y * a3.x);
                m[1] = float3(-a2.y * a1.x, a1.y * a2.y, a2.x);
                m[2] = float3(a3.y * a1.x * a2.x + a1.y * a3.x, a1.x * a3.x - a1.y * a3.y * a2.x, a2.y * a3.y);
                return m;
            }

            float hash(float2 p)
            {
                float h = dot(p, float2(127.1, 311.7));
                return frac(sin(h) * 43758.5453123);
            }

            float noise(in float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                float2 u = f * f * (3.0 - 2.0 * f);
                return -1.0 + 2.0 * lerp(lerp(hash(i + float2(0.0, 0.0)),
                                              hash(i + float2(1.0, 0.0)), u.x),
                                         lerp(hash(i + float2(0.0, 1.0)),
                                              hash(i + float2(1.0, 1.0)), u.x), u.y);
            }

            // lighting
            float diffuse(float3 n, float3 l, float p)
            {
                return pow(dot(n, l) * 0.4 + 0.6, p);
            }

            float specular(float3 n, float3 l, float3 e, float s)
            {
                float nrm = (s + 8.0) / (PI * 8.0);
                return pow(max(dot(reflect(e, n), l), 0.0), s) * nrm;
            }

            // sky
            float3 getSkyColor(float3 e)
            {
                e.y = (max(e.y, 0.0) * 0.8 + 0.2) * 0.8;
                return float3(pow(1.0 - e.y, 2.0), 1.0 - e.y, 0.6 + (1.0 - e.y) * 0.4) * 1.1;
            }

            // sea
            float sea_octave(float2 uv, float choppy)
            {
                uv += noise(uv);
                float2 wv = 1.0 - abs(sin(uv));
                float2 swv = abs(cos(uv));
                wv = lerp(wv, swv, wv);
                return pow(1.0 - pow(wv.x * wv.y, 0.65), choppy);
            }

            float map(float3 p)
            {
                float freq = SEA_FREQ;
                float amp = SEA_HEIGHT;
                float choppy = SEA_CHOPPY;
                float2 uv = p.xz;
                uv.x *= 0.75;
                float d, h = 0.0;
                for (int i = 0; i < ITER_GEOMETRY; i++)
                {
                    d = sea_octave((uv + SEA_TIME) * freq, choppy);
                    d += sea_octave((uv - SEA_TIME) * freq, choppy);
                    h += d * amp;
                    //uv *= octave_m;
                    uv = mul(octave_m, uv);
                    freq *= 1.9;
                    amp *= 0.22;
                    choppy = lerp(choppy, 1.0, 0.2);
                }
                return p.y - h;
            }

            float map_detailed(float3 p)
            {
                float freq = SEA_FREQ;
                float amp = SEA_HEIGHT;
                float choppy = SEA_CHOPPY;
                float2 uv = p.xz;
                uv.x *= 0.75;
                float d, h = 0.0;
                for (int i = 0; i < ITER_FRAGMENT; i++)
                {
                    d = sea_octave((uv + SEA_TIME) * freq, choppy);
                    d += sea_octave((uv - SEA_TIME) * freq, choppy);
                    h += d * amp;
                    //uv *= octave_m;
                    uv = mul(octave_m, uv);
                    freq *= 1.9;
                    amp *= 0.22;
                    choppy = lerp(choppy, 1.0, 0.2);
                }
                return p.y - h;
            }

            float3 getSeaColor(float3 p, float3 n, float3 l, float3 eye, float3 dist)
            {
                float fresnel = clamp(1.0 - dot(n, -eye), 0.0, 1.0);
                fresnel = pow(fresnel, 3.0) * 0.5;
                float3 reflected = getSkyColor(reflect(eye, n));
                float3 refraced = SEA_BASE + diffuse(n, l, 80.0) * SEA_WATER_COLOR * 0.12;
                float3 color = lerp(refraced, reflected, fresnel);
                float atten = max(1.0 - dot(dist, dist) * 0.001, 0.0);
                color += SEA_WATER_COLOR * (p.y - SEA_HEIGHT) * 0.18 * atten;
                color += (specular(n, l, eye, 60.0));
                return color;
            }

            // tracing
            float3 getNormal(float3 p, float eps)
            {
                float3 n;
                n.y = map_detailed(p);
                n.x = map_detailed(float3(p.x + eps, p.y, p.z)) - n.y;
                n.z = map_detailed(float3(p.x, p.y, p.z + eps)) - n.y;
                n.y = eps;
                return normalize(n);
            }

            float heightMapTracing(float3 ori, float3 dir, out float3 p)
            {
                float tm = 0.0;
                float tx = 1000.0;
                float hx = map(ori + dir * tx);
                if (hx > 0.0)
                {
                    p = ori + dir * tx;
                    return tx;
                }
                float hm = map(ori + dir * tm);
                float tmid = 0.0;
                for (int i = 0; i < NUM_STEPS; i++)
                {
                    tmid = lerp(tm, tx, hm / (hm - hx));
                    p = ori + dir * tmid;
                    float hmid = map(p);
                    if (hmid < 0.0)
                    {
                        tx = tmid;
                        hx = hmid;
                    }
                    else
                    {
                        tm = tmid;
                        hm = hmid;
                    }
                }
                return tmid;
            }

            float3 getPixel(in float2 coord, float time)
            {
                float2 uv = coord / iResolution.xy;
                uv = uv * 2.0 - 1.0;
                uv.x *= iResolution.x / iResolution.y;
                // ray
                float3 ang = float3(sin(time * 3.0) * 0.1, sin(time) * 0.2 + 0.3, time);
                float3 ori = float3(0.0, 3.5, time * 5.0);
                float3 dir = normalize(float3(uv.xy, -2.0));
                dir.z += length(uv) * 0.14;
                //dir = normalize(dir) * fromEuler(ang);
                dir = mul(fromEuler(ang), normalize(dir));
                // tracing
                float3 p;
                heightMapTracing(ori, dir, p);
                float3 dist = p - ori;
                float3 n = getNormal(p, dot(dist, dist) * EPSILON_NRM);
                float3 light = normalize(float3(0.0, 1.0, 0.8));
                // color
                return lerp(
                    getSkyColor(dir),
                    getSeaColor(p, n, light, dir, dist),
                    pow(smoothstep(0.0, -0.02, dir.y), 0.2));
            }

            // main
            void mainImage(out float4 fragColor, in float2 fragCoord)
            {
                // fragColor = float4(octave_m[0], 0, 1);
                // return;
                float time = iTime * 0.3 + iMouse.x * 0.01;
                #ifdef AA
    float3 color = float3(0.0,0.0,0.0);
    for(int i = -1; i <= 1; i++) {
        for(int j = -1; j <= 1; j++) {
        	float2 uv = fragCoord+float2(i,j)/3.0;
    		color += getPixel(uv, time);
        }
    }
    color /= 9.0;
                #else
                float3 color = getPixel(fragCoord, time);
                #endif
                // post
                fragColor = float4(pow(color, 0.65), 1.0);
            }


            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                output.positionHCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;

                return output;
            }

            half4 frag(Varyings input):SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float2 screenUV = input.positionHCS / _ScreenParams;

                //float2 UV = float2(input.uv.y,input.uv.x)*1000;
                float2 UV = float2(input.uv.x, input.uv.y) * 1000;
                float4 color;
                
                octave_m = float2x2(1.6, -1.2, 1.2, 1.6);
                
                // return float4(octave_m[0],0,1);
                mainImage(color, UV);
                return color;
            }
            ENDHLSL
        }
    }
}