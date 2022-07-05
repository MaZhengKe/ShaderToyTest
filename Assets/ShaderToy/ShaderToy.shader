Shader "KM/ShaderToy"
{
    Properties
    {
        [MainTexture] _BaseMap("Base Map", 2D) = "white"
        _iResolution("iResolution", vector) = (1,1,0,0)
        _iMouse("iResolution", vector) = (0,0,0,0)
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


            
            
            
            //
            // #define vec2   float2
            // #define vec3 float3
            // #define vec4   float4
            //
            // #define mat2 float2x2
            // #define mat3 float3x3
            //
            // //
            // // #define vec3Zero   float3
            // //
            // // #define vec3One(x) float3(x,x,x)
            // // #define vec3Three(x,y,z) float3(x,y,z)
            // //
            // // #define GetMacro(_1,_2,_3,NAME,...) NAME
            // //
            // // #define vec3(...) GetMacro(__VA_ARGS__,vec3Three,vec3Two,vec3One,vec3Zero,...)(__VA_ARGS__)
            // //
            // //
            //
            // #define mix   lerp
            // #define fract   frac
            // #define atan(x,y)   atan2(y,x)
            // #define mod(x,y)   (x%y)

            
            #define iGlobalTime   _Time.y
            #define iTime   _Time.y
            #define iResolution   _iResolution
            #define iMouse   _iMouse


            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            TEXTURE2D_X(_BaseMap);
            SAMPLER(sampler_BaseMap);


            CBUFFER_START(UnityPerMaterial)
            float4 _iResolution;
            float4 _iMouse;
            float4 _BaseMap_ST;
            CBUFFER_END

            
const int NUM_STEPS = 8;
            
            //#include "Heart.hlsl"
            #include "Seascape.hlsl"


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
                float2 UV = float2(input.uv.x,input.uv.y)*1000;
                float4 color;

                mainImage(color,UV);
                // return float4(aaaa,0,0,1);
                return color;


                return SAMPLE_TEXTURE2D_X(_BaseMap, sampler_BaseMap, UV) * 0.8;
            }
            ENDHLSL
        }
    }
}