///////////////////////////////////////////
// 構造体
///////////////////////////////////////////
// 頂点シェーダーへの入力
struct SVSIn
{
    float4 pos : POSITION;
    float2 uv : TEXCOORD0;
};

// ピクセルシェーダーへの入力
struct SPSIn
{
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
    float4 posInProj : TEXCOORD1;
};

///////////////////////////////////////////
// 定数バッファー
///////////////////////////////////////////
// モデル用の定数バッファー
cbuffer ModelCb : register(b0)
{
    float4x4 mWorld;
    float4x4 mView;
    float4x4 mProj;
};

cbuffer StealthCb : register(b1)
{
    float4 g_alphaRate;
};



///////////////////////////////////////////
// シェーダーリソース
///////////////////////////////////////////

Texture2D<float4> g_albedoMap : register(t0);
// step-3 シーンテクスチャにアクセスするための変数を追加
Texture2D<float4> g_sceneTexture : register(t10);

///////////////////////////////////////////
// サンプラーステート
///////////////////////////////////////////
sampler g_sampler : register(s0);

///////////////////////////////////////////
// 関数
///////////////////////////////////////////
// ハッシュ関数
float hash(float n)
{
    return frac(sin(n) * 43758.5453);
}

// 3次元ベクトルからシンプレックスノイズを生成する関数
float SimplexNoise(float3 x)
{
    // The noise function returns a value in the range -1.0f -> 1.0f
    float3 p = floor(x);
    float3 f = frac(x);

    f = f * f * (3.0 - 2.0 * f);
    float n = p.x + p.y * 57.0 + 113.0 * p.z;

    return lerp(lerp(lerp(hash(n + 0.0), hash(n + 1.0), f.x),
                     lerp(hash(n + 57.0), hash(n + 58.0), f.x), f.y),
                lerp(lerp(hash(n + 113.0), hash(n + 114.0), f.x),
                     lerp(hash(n + 170.0), hash(n + 171.0), f.x), f.y), f.z);
}

/// <summary>
/// モデル用の頂点シェーダーのエントリーポイント
/// </summary>
SPSIn VSMain(SVSIn vsIn, uniform bool hasSkin)
{
    SPSIn psIn;

    psIn.pos = mul(mWorld, vsIn.pos); // モデルの頂点をワールド座標系に変換
    psIn.pos = mul(mView, psIn.pos); // ワールド座標系からカメラ座標系に変換
    psIn.pos = mul(mProj, psIn.pos); // カメラ座標系からスクリーン座標系に変換
    psIn.uv = vsIn.uv;

    // step-4 頂点の正規化スクリーン座標系の座標をピクセルシェーダーに渡す
    psIn.posInProj = psIn.pos;
    psIn.posInProj.xy /= psIn.posInProj.w;

    return psIn;
}

/// <summary>
/// モデル用のピクセルシェーダーのエントリーポイント
/// </summary>
float4 PSMain(SPSIn psIn) : SV_Target0
{
    // step-5 シンプレックスノイズを利用して、UV座標をずらしてシーンテクスチャを貼り付ける
    // 正規化スクリーン座標系からUV座標系に変換する
    float2 uv = psIn.posInProj.xy * float2(0.5f, -0.5f) + 0.5f;
    // シンプレックスノイズを利用して、UVオフセットを計算する
    float uOffset = SimplexNoise(float3(uv, 0.0f) * 256.0f) * 0.02f;
    
    // シーンテクスチャから色をサンプリングする
    // 背景から持ってきた色情報
    float4 stealth = g_sceneTexture.Sample(g_sampler, uv + uOffset);
    
    float Y = 0.299f * stealth.r + 0.587f * stealth.g + 0.114f * stealth.b;
    stealth.r = Y;
    stealth.g = Y;
    stealth.b = Y;
    
    // ティーポットの色情報
    float4 albedo = g_albedoMap.Sample(g_sampler, psIn.uv);

    // ステルスの色を返す
    float4 finalColor = stealth * 0.75f + albedo * 0.25f;
    
    float alphaRate = (1.0f - mWorld[2][0]) * 0.5f;
    
    //finalColor.a *= alphaRate;
    finalColor.a *= g_alphaRate.x;
    
    return finalColor;
}
