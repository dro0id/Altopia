// Post-traitement léger (rendu Built-in) : bloom (seuil + flou), vignette et aberration chromatique.
Shader "Altopia/Bloom"
{
    Properties { _MainTex ("Texture", 2D) = "white" {} _BloomTex ("Bloom", 2D) = "black" {} }
    CGINCLUDE
    #include "UnityCG.cginc"
    sampler2D _MainTex; float4 _MainTex_TexelSize; sampler2D _BloomTex;
    float _Threshold, _Intensity, _Vignette, _Aberration;
    float2 _Dir;
    struct v2f { float4 pos : SV_POSITION; float2 uv : TEXCOORD0; };
    v2f vert (appdata_img v) { v2f o; o.pos = UnityObjectToClipPos(v.vertex); o.uv = v.texcoord; return o; }
    half4 fragPre (v2f i) : SV_Target
    {
        half3 c = tex2D(_MainTex, i.uv).rgb;
        half br = max(c.r, max(c.g, c.b));
        half k = max(0, br - _Threshold) / max(br, 0.0001);
        return half4(c * k, 1);
    }
    half4 fragBlur (v2f i) : SV_Target
    {
        float2 d = _Dir * _MainTex_TexelSize.xy;
        half3 c = tex2D(_MainTex, i.uv).rgb * 0.227027;
        c += tex2D(_MainTex, i.uv + d * 1.384615).rgb * 0.316216; c += tex2D(_MainTex, i.uv - d * 1.384615).rgb * 0.316216;
        c += tex2D(_MainTex, i.uv + d * 3.230769).rgb * 0.070270; c += tex2D(_MainTex, i.uv - d * 3.230769).rgb * 0.070270;
        return half4(c, 1);
    }
    half4 fragComp (v2f i) : SV_Target
    {
        float2 d = i.uv - 0.5;
        float2 off = d * _Aberration;
        half3 c;
        c.r = tex2D(_MainTex, i.uv + off).r; c.g = tex2D(_MainTex, i.uv).g; c.b = tex2D(_MainTex, i.uv - off).b;
        c += tex2D(_BloomTex, i.uv).rgb * _Intensity;
        c *= 1.0 - dot(d, d) * _Vignette;
        return half4(c, 1);
    }
    ENDCG
    SubShader
    {
        Cull Off ZWrite Off ZTest Always
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment fragPre
            ENDCG
        }
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment fragBlur
            ENDCG
        }
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment fragComp
            ENDCG
        }
    }
}
