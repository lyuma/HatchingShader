Shader "Custom/HatchingShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" { }
        _NormalTex ("Normal Texture", 2D) = "bump" { }
        _Hatch0 ("Hatch0", 2D) = "white" { }
        _Hatch1 ("Hatch1", 2D) = "white" { }
        _Hatch2 ("Hatch2", 2D) = "white" { }
        _Hatch3 ("Hatch3", 2D) = "white" { }
        _Hatch4 ("Hatch4", 2D) = "white" { }
        _Hatch5 ("Hatch5", 2D) = "white" { }
        _OutlineMask ("Outline Mask Texture", 2D) = "black" { }
        _OutlineColor ("Outline Color", Color) = (0, 0, 0, 1)
        _OutlineWidth ("Outline Width", Float) = 0
        [Enum(OFF, 0, ON, 1)] _Hoge2 ("Toggle Billboard", int) = 0
        _Angle ("Angle", Range(0.0, 360.0)) = 0.0
        _Xcomp ("_Xcomp", Range(0.0, 0.99)) = 0.0
        _Ycomp ("_Ycomp", Range(0.0, 0.99)) = 0.0
        _Zcomp ("_Zcomp", Range(0.0, 0.99)) = 0.0
        _RimPower ("Rim Power", Float) = 0.0
        _RimAmplitude ("Rim Amplitude", Float) = 0.0
        _Threshold ("Threshold", Range(0.0, 1.0)) = 0.5
        _Adjust ("NdotL or NdotV", Range(0.0, 1.0)) = 0.6
        _Density ("Density", Range(0.0, 1.0)) = 0.6
        _Roughness ("Roughness", Range(0.1, 30)) = 8.0
        _Hoge ("Toggle Gray Scale", Range(0.1, 1)) = 0.0
        [Enum(OFF, 0, FRONT, 1, BACK, 2)] _CullMode ("Cull Mode", int) = 0
    }
    
    SubShader
    {
        Tags { "Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "TransparentCutout" }
        Blend SrcAlpha OneMinusSrcAlpha
        Cull[_CullMode]
        LOD 100

        CGINCLUDE
        #pragma vertex vert
        #pragma fragment frag
        #pragma multi_compile_fog
        
        #include "UnityCG.cginc"
        #include "AutoLight.cginc"
        
        float2x2 rotateFnc(float b)
        {
            float alpha = b * UNITY_PI / 180.0;
            float sina, cosa;
            sincos(alpha, sina, cosa);
            return float2x2(cosa, -sina, sina, cosa);
        }

        float4 Rotate(float4 a, float b)
        {
            float2x2 m = rotateFnc(b);
            return float4(mul(m, a.xz), a.yw).xzyw;
        }

        #ifdef USING_STEREO_MATRICES
        static float3 centerCameraPos = 0.5 * (unity_StereoWorldSpaceCameraPos[0] +  unity_StereoWorldSpaceCameraPos[1]);
        #else
        static float3 centerCameraPos = _WorldSpaceCameraPos;
        #endif

        ENDCG
        
        Pass
        {
            Tags { "LightMode" = "ShadowCaster" }
            
            CGPROGRAM

            struct v2f
            {
                V2F_SHADOW_CASTER;
            };

            v2f vert(appdata_base v)
            {
                v2f o;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                return o;
            }

            float4 frag(v2f i): SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
            
        }

        Pass
        {
            Cull Front
            CGPROGRAM

            struct appdata
            {
                float4 vertex: POSITION;
                float2 uvM: TEXCOORD0;
                float3 normal: NORMAL;
            };

            struct v2f
            {
                float2 uv: TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex: SV_POSITION;
                float2 uvM: TEXCOORD0;
                float3 normal: TEXCOORD1;
                float4 wpos: TEXCOORD2;
            };

            uniform sampler2D _MainTex; uniform float4 _MainTex_ST;
            uniform sampler2D _OutlineMask; uniform float4 _OutlineMask_ST;
            uniform float _Hoge;
            uniform int _Hoge2;
            uniform fixed4 _OutlineColor;
            uniform float _RimPower;
            uniform float _RimAmplitude;
            uniform float _OutlineWidth;
            uniform float _Xcomp;
            uniform float _Ycomp;
            uniform float _Zcomp;
            uniform float _Angle;
            
            v2f vert(appdata v)
            {
                v2f o;
                _OutlineWidth /= 1000;
                o.uvM = v.uvM;
                float3 outlineMask = tex2Dlod(_OutlineMask, float4(TRANSFORM_TEX(o.uvM, _OutlineMask), 0.0, 0)).rgb;
                v.vertex.xyz += lerp(0, v.normal * (1.0 - outlineMask.rgb) * _OutlineWidth, saturate(_OutlineWidth * 1000));
                v.vertex = Rotate(v.vertex, _Angle);
                v.vertex.xyz = v.vertex.xyz * (1 - float3(_Xcomp, _Ycomp, _Zcomp));
                float4 pos = mul(UNITY_MATRIX_P, mul(UNITY_MATRIX_MV, float4(0, 0, 0, 1)) + float4(v.vertex.x, v.vertex.y, v.vertex.z, 0));
                o.vertex = lerp(UnityObjectToClipPos(v.vertex), pos, _Hoge2);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.wpos = mul(unity_ObjectToWorld, v.vertex);
                UNITY_TRANSFER_FOG(o, o.vertex);
                return o;
            }
            
            fixed4 frag(v2f i): SV_Target
            {
                float3 N = i.normal;
                float3 V = normalize(centerCameraPos.xyz - i.wpos.xyz);

                float NdotV = max(0, dot(N, V));
                float NNdotV = 1.01 - dot(N, V);
                float rim = pow(NNdotV, _RimPower) * _RimAmplitude;

                fixed4 col = _OutlineColor;
                col.rgb = lerp(col.rgb, dot(col.rgb, half3(0.2326, 0.7152, 0.0722)), _Hoge);

                fixed3 colRim = col.rgb * 1.0 + rim * fixed3(1.0, 1.0, 1.0);

                col.rgb = lerp(col.rgb, colRim, V);

                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
            
        }

        Pass
        {
            Tags { "LightMode" = "ForwardBase" }
            CGPROGRAM
            
            #pragma multi_compile_fwdbase

            struct appdata
            {
                float4 vertex: POSITION;
                float2 uv: TEXCOORD0;
                float3 normal: NORMAL;
                float3 tangent: TANGENT;
            };

            struct v2f
            {
                float2 uv: TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex: SV_POSITION;
                float3 normal: TEXCOORD2;
                float2 huv: TEXCOORD3;
                float4 wpos: TEXCOORD4;
                LIGHTING_COORDS(5, 6)
                float3 tangent: TEXCOORD7;
                float3 binormal: TEXCOORD8;
            };

            uniform sampler2D _MainTex; uniform float4 _MainTex_ST;
            uniform sampler2D _NormalTex; uniform float4 _NormalTex_ST;
            uniform sampler2D _Hatch0;
            uniform sampler2D _Hatch1;
            uniform sampler2D _Hatch2;
            uniform sampler2D _Hatch3;
            uniform sampler2D _Hatch4;
            uniform sampler2D _Hatch5;
            uniform float4 _LightColor0;
            uniform float _Xcomp;
            uniform float _Ycomp;
            uniform float _Zcomp;
            uniform float _RimPower;
            uniform float _RimAmplitude;
            uniform float _Threshold;
            uniform float _Adjust;
            uniform float _Density;
            uniform float _Roughness;
            uniform float _Hoge;
            uniform int _Hoge2;
            uniform float _Angle;
            
            v2f vert(appdata v)
            {
                v2f o;
                o.wpos = mul(unity_ObjectToWorld, v.vertex);
                v.vertex = Rotate(v.vertex, _Angle);
                v.vertex.xyz = v.vertex.xyz * (1 - float3(_Xcomp, _Ycomp, _Zcomp));
                float4 pos = mul(UNITY_MATRIX_P, mul(UNITY_MATRIX_MV, float4(0, 0, 0, 1)) + float4(v.vertex.x, v.vertex.y, v.vertex.z, 0));
                o.vertex = lerp(UnityObjectToClipPos(v.vertex), pos, _Hoge2);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.huv = TRANSFORM_TEX(v.uv, _MainTex) * _Roughness;
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.tangent = UnityObjectToWorldNormal(v.tangent);
                o.binormal = normalize(cross(o.tangent, o.normal));
                UNITY_TRANSFER_FOG(o, o.vertex);
                return o;
            }
            
            fixed4 frag(v2f i): SV_Target
            {
                float3 tangentNormal = float4(UnpackNormal(tex2D(_NormalTex, i.uv)), 1);
                float3x3 TBN = float3x3(i.tangent, i.binormal, i.normal);
                TBN = transpose(TBN);
                float3 worldNormal = mul(TBN, tangentNormal);

                float3 N = lerp(i.normal, worldNormal, saturate(length(tangentNormal) * 100));
                float3 L = _WorldSpaceLightPos0;
                float3 V = normalize(centerCameraPos.xyz - i.wpos.xyz);

                float NdotV = max(0, dot(N, V));
                float NNdotV = 1.01 - dot(N, V);
                float rim = pow(NNdotV, _RimPower) * _RimAmplitude;

                float NdotL = max(0, dot(L, N));
                UNITY_LIGHT_ATTENUATION(attenuation, i, N)
                float3 lightCol = _LightColor0.rgb * attenuation;

                fixed4 col = tex2D(_MainTex, i.uv);

                fixed4 hatch0 = tex2D(_Hatch0, i.huv);
                fixed4 hatch1 = tex2D(_Hatch1, i.huv);
                fixed4 hatch2 = tex2D(_Hatch2, i.huv);
                fixed4 hatch3 = tex2D(_Hatch3, i.huv);
                fixed4 hatch4 = tex2D(_Hatch4, i.huv);
                fixed4 hatch5 = tex2D(_Hatch5, i.huv);

                if (length(_LightColor0.rgb) < _Threshold)
                {
                    float3 diffuse = col.rgb * NdotV;
                    float intensity = lerp(saturate(length(diffuse)), 0.5 * saturate(dot(diffuse, half3(0.2326, 0.7152, 0.0722))), _Density);

                    if(0.6 < intensity)
                    {
                        col *= fixed4(1, 1, 1, 1);
                    }
                    else if(0.5 < intensity && intensity <= 0.6)
                    {
                        col *= lerp(hatch0, hatch1, 1 - intensity);
                    }
                    else if(0.4 < intensity && intensity <= 0.5)
                    {
                        col *= lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity);
                    }
                    else if(0.3 < intensity && intensity <= 0.4)
                    {
                        col *= lerp(lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity), hatch3, 1 - intensity);
                    }
                    else if(0.2 < intensity && intensity <= 0.3)
                    {
                        col *= lerp(lerp(lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity), hatch3, 1 - intensity), hatch4, 1 - intensity);
                    }
                    else if(0.1 < intensity && intensity <= 0.2)
                    {
                        col *= lerp(lerp(lerp(lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity), hatch3, 1 - intensity), hatch4, 1 - intensity), hatch4, 1 - intensity);
                    }
                    else if(intensity <= 0.1)
                    {
                        col *= lerp(lerp(lerp(lerp(lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity), hatch3, 1 - intensity), hatch4, 1 - intensity), hatch4, 1 - intensity), hatch5 * 0.5, NdotV * 1.5);
                    }
                }
                else
                {
                    float manipulate = lerp(NdotL, NdotV, _Adjust);
                    float3 diffuse = lerp(col.rgb * manipulate, lightCol, 1.0 / pow(3, length(lightCol)));
                    float intensity = lerp(saturate(length(diffuse)), 0.5 * saturate(dot(diffuse, half3(0.2326, 0.7152, 0.0722))), _Density);

                    if(0.6 < intensity)
                    {
                        col *= fixed4(1, 1, 1, 1);
                    }
                    else if(0.5 < intensity && intensity <= 0.6)
                    {
                        col *= lerp(hatch0, hatch1, 1 - intensity);
                    }
                    else if(0.4 < intensity && intensity <= 0.5)
                    {
                        col *= lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity);
                    }
                    else if(0.3 < intensity && intensity <= 0.4)
                    {
                        col *= lerp(lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity), hatch3, 1 - intensity);
                    }
                    else if(0.2 < intensity && intensity <= 0.3)
                    {
                        col *= lerp(lerp(lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity), hatch3, 1 - intensity), hatch4, 1 - intensity);
                    }
                    else if(0.1 < intensity && intensity <= 0.2)
                    {
                        col *= lerp(lerp(lerp(lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity), hatch3, 1 - intensity), hatch4, 1 - intensity), hatch4, 1 - intensity);
                    }
                    else if(intensity <= 0.1)
                    {
                        col *= lerp(lerp(lerp(lerp(lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity), hatch3, 1 - intensity), hatch4, 1 - intensity), hatch4, 1 - intensity), hatch5 * 0.5, (1 - NdotL) * 1.5);
                    }
                }

                col.rgb = lerp(col.rgb, dot(col.rgb, half3(0.2326, 0.7152, 0.0722)), _Hoge);

                fixed3 colRim = col.rgb * 1.0 + rim * fixed3(1.0, 1.0, 1.0);
                col.rgb = lerp(col.rgb, colRim, V);
                col.a = 1;

                UNITY_APPLY_FOG(i.fogCoord, col);
                return saturate(col);
            }
            ENDCG
            
        }
        Pass
        {
            Tags { "LightMode" = "ForwardAdd" }
            Blend One One
            CGPROGRAM
            
            #pragma multi_compile_fwdadd

            struct appdata
            {
                float4 vertex: POSITION;
                float2 uv: TEXCOORD0;
                float3 normal: NORMAL;
                float3 tangent: TANGENT;
            };

            struct v2f
            {
                float2 uv: TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex: SV_POSITION;
                float3 normal: TEXCOORD2;
                float2 huv: TEXCOORD3;
                float4 wpos: TEXCOORD4;
                LIGHTING_COORDS(5, 6)
                float3 tangent: TEXCOORD7;
                float3 binormal: TEXCOORD8;
            };

            uniform sampler2D _MainTex; uniform float4 _MainTex_ST;
            uniform sampler2D _NormalTex; uniform float4 _NormalTex_ST;
            uniform sampler2D _Hatch0;
            uniform sampler2D _Hatch1;
            uniform sampler2D _Hatch2;
            uniform sampler2D _Hatch3;
            uniform sampler2D _Hatch4;
            uniform sampler2D _Hatch5;
            uniform float4 _LightColor0;
            uniform float _Xcomp;
            uniform float _Ycomp;
            uniform float _Zcomp;
            uniform float _RimPower;
            uniform float _RimAmplitude;
            uniform float _Threshold;
            uniform float _Adjust;
            uniform float _Density;
            uniform float _Roughness;
            uniform float _Hoge;
            uniform int _Hoge2;
            uniform float _Angle;
            
            v2f vert(appdata v)
            {
                v2f o;
                o.wpos = mul(unity_ObjectToWorld, v.vertex);
                v.vertex = Rotate(v.vertex, _Angle);
                v.vertex.xyz = v.vertex.xyz * (1 - float3(_Xcomp, _Ycomp, _Zcomp));
                float4 pos = mul(UNITY_MATRIX_P, mul(UNITY_MATRIX_MV, float4(0, 0, 0, 1)) + float4(v.vertex.x, v.vertex.y, v.vertex.z, 0));
                o.vertex = lerp(UnityObjectToClipPos(v.vertex), pos, _Hoge2);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.huv = TRANSFORM_TEX(v.uv, _MainTex) * _Roughness;
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.tangent = UnityObjectToWorldNormal(v.tangent);
                o.binormal = normalize(cross(o.tangent, o.normal));
                UNITY_TRANSFER_FOG(o, o.vertex);
                return o;
            }
            
            fixed4 frag(v2f i): SV_Target
            {
                float3 tangentNormal = float4(UnpackNormal(tex2D(_NormalTex, i.uv)), 1);
                float3x3 TBN = float3x3(i.tangent, i.binormal, i.normal);
                TBN = transpose(TBN);
                float3 worldNormal = mul(TBN, tangentNormal);

                float3 N = lerp(i.normal, worldNormal, saturate(length(tangentNormal) * 100));
                float3 V = normalize(centerCameraPos.xyz - i.wpos.xyz);

                float3 lightDir;
                if (_WorldSpaceLightPos0.w > 0)
                {
                    lightDir = _WorldSpaceLightPos0.xyz - i.wpos.xyz;
                }
                else
                {
                    lightDir = _WorldSpaceLightPos0.xyz;
                }
                float3 L = normalize(lightDir);

                float NdotV = max(0, dot(N, V));
                float NNdotV = 1.01 - dot(N, V);
                float rim = pow(NNdotV, _RimPower) * _RimAmplitude;

                float NdotL = max(0, dot(L, N));
                UNITY_LIGHT_ATTENUATION(attenuation, i, N)
                float3 lightCol = _LightColor0.rgb * attenuation;

                fixed4 col = tex2D(_MainTex, i.uv);

                fixed4 hatch0 = tex2D(_Hatch0, i.huv);
                fixed4 hatch1 = tex2D(_Hatch1, i.huv);
                fixed4 hatch2 = tex2D(_Hatch2, i.huv);
                fixed4 hatch3 = tex2D(_Hatch3, i.huv);
                fixed4 hatch4 = tex2D(_Hatch4, i.huv);
                fixed4 hatch5 = tex2D(_Hatch5, i.huv);

                if (length(_LightColor0.rgb) < _Threshold)
                {
                    float3 diffuse = col.rgb * NdotV;
                    float intensity = lerp(saturate(length(diffuse)), 0.5 * saturate(dot(diffuse, half3(0.2326, 0.7152, 0.0722))), _Density);

                    if(0.6 < intensity)
                    {
                        col *= fixed4(1, 1, 1, 1);
                    }
                    else if(0.5 < intensity && intensity <= 0.6)
                    {
                        col *= lerp(hatch0, hatch1, 1 - intensity);
                    }
                    else if(0.4 < intensity && intensity <= 0.5)
                    {
                        col *= lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity);
                    }
                    else if(0.3 < intensity && intensity <= 0.4)
                    {
                        col *= lerp(lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity), hatch3, 1 - intensity);
                    }
                    else if(0.2 < intensity && intensity <= 0.3)
                    {
                        col *= lerp(lerp(lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity), hatch3, 1 - intensity), hatch4, 1 - intensity);
                    }
                    else if(0.1 < intensity && intensity <= 0.2)
                    {
                        col *= lerp(lerp(lerp(lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity), hatch3, 1 - intensity), hatch4, 1 - intensity), hatch4, 1 - intensity);
                    }
                    else if(intensity <= 0.1)
                    {
                        col *= lerp(lerp(lerp(lerp(lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity), hatch3, 1 - intensity), hatch4, 1 - intensity), hatch4, 1 - intensity), hatch5 * 0.5, NdotV * 1.5);
                    }
                }
                else
                {
                    float manipulate = lerp(NdotL, NdotV, _Adjust);
                    float3 diffuse = lerp(col.rgb * manipulate, lightCol, 1.0 / pow(3, length(lightCol)));
                    float intensity = lerp(saturate(length(diffuse)), 0.5 * saturate(dot(diffuse, half3(0.2326, 0.7152, 0.0722))), _Density);

                    if(0.6 < intensity)
                    {
                        col *= fixed4(1, 1, 1, 1);
                    }
                    else if(0.5 < intensity && intensity <= 0.6)
                    {
                        col *= lerp(hatch0, hatch1, 1 - intensity);
                    }
                    else if(0.4 < intensity && intensity <= 0.5)
                    {
                        col *= lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity);
                    }
                    else if(0.3 < intensity && intensity <= 0.4)
                    {
                        col *= lerp(lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity), hatch3, 1 - intensity);
                    }
                    else if(0.2 < intensity && intensity <= 0.3)
                    {
                        col *= lerp(lerp(lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity), hatch3, 1 - intensity), hatch4, 1 - intensity);
                    }
                    else if(0.1 < intensity && intensity <= 0.2)
                    {
                        col *= lerp(lerp(lerp(lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity), hatch3, 1 - intensity), hatch4, 1 - intensity), hatch4, 1 - intensity);
                    }
                    else if(intensity <= 0.1)
                    {
                        col *= lerp(lerp(lerp(lerp(lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity), hatch3, 1 - intensity), hatch4, 1 - intensity), hatch4, 1 - intensity), hatch5 * 0.5, (1 - NdotL) * 1.5);
                    }
                }

                col.rgb = lerp(col.rgb, dot(col.rgb, half3(0.2326, 0.7152, 0.0722)), _Hoge);

                fixed3 colRim = col.rgb * 1.0 + rim * fixed3(1.0, 1.0, 1.0);
                col.rgb = lerp(col.rgb, colRim, V);
                col.a = 1;

                UNITY_APPLY_FOG(i.fogCoord, col);
                return saturate(col);
            }
            ENDCG
            
        }
    }
    Fallback "Diffuse"
}
