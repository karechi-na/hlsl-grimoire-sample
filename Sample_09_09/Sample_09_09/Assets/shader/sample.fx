/*!
 * @brief チェッカーボードワイプ
 */

cbuffer cb : register(b0)
{
    float4x4 mvp; // MVP行列
    float4 mulColor; // 乗算カラー
};

cbuffer NagaCB : register(b1)
{
    float negaRate; // ネガポジ反転率
};

//cbuffer WipeCB : register(b2)
//{
//    float2 wipeDirection;
//    float wipeSize;
//};


struct VSInput
{
    float4 pos : POSITION;
    float2 uv : TEXCOORD0;
};

struct PSInput
{
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
};

Texture2D<float4> colorTexture : register(t0); // カラーテクスチャ
sampler Sampler : register(s0);

PSInput VSMain(VSInput In)
{
    PSInput psIn;
    psIn.pos = mul(mvp, In.pos);
    psIn.uv = In.uv;
    return psIn;
}

float4 PSMain(PSInput In) : SV_Target0
{
    float4 color = colorTexture.Sample(Sampler, In.uv);
    

    // step-1 画像を徐々にネガポジ反転させていく
    float3 negaColor = 1.0f - color.xyz;
    
    float Y = 0.299f * color.r + 0.587f * color.g + 0.114f * color.b;
    
    float3 monochromeColor = float3(Y, Y, Y);
    
   // negaRate をそのまま補間係数として使用（徐々に切替）
    float t = saturate(negaRate); // 0..1 にクランプ
    
    float monoAmt = smoothstep(0.0f, 0.5f, t); // 0 -> 1
    float negAmt = smoothstep(0.5f, 1.0f, t); // 0 -> 1

    // 元色 -> モノクロ
    float3 midColor = lerp(color.xyz, monochromeColor, monoAmt);
    // モノクロ（または元→モノクロ） -> ネガ
    float3 processedColor = lerp(midColor, negaColor, negAmt);

    // --- ワイプ（左から右へ）マスク ---
    // UV.x <= t の領域が変換対象になる（境界はややフェード）
    const float edge = 0.02f; // 境界のフェード幅（調整可）
    float edgeMask = 1.0f - smoothstep(t - edge, t + edge, In.uv.x); // 1: 変換, 0: 未変換

    // 最終色：変換済みと元をマスクでブレンド
    float3 outRGB = lerp(color.xyz, processedColor, edgeMask);

    float4 outColor = float4(outRGB, color.a);
    
    //color.xyz = lerp(color.xyz, negaColor, t);
    
    //color.xyz = lerp(color.xyz, monochromeColor, t);

    // 乗算カラーを適用
    outColor *= mulColor;
    
    return outColor;
}
