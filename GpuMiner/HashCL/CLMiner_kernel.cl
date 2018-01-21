/****************************** MACROS ******************************/
#define OPENCL_PLATFORM_UNKNOWN 0
#define OPENCL_PLATFORM_NVIDIA  1
#define OPENCL_PLATFORM_AMD     2
#define OPENCL_PLATFORM_CLOVER  3

#ifndef GROUP_SIZE
#define GROUP_SIZE 128
#endif

#ifndef PLATFORM
#define PLATFORM OPENCL_PLATFORM_AMD
#endif

#ifdef cl_clang_storage_class_specifiers
#pragma OPENCL EXTENSION cl_clang_storage_class_specifiers : enable
#endif

#define ROTLEFT(a,b) (((a) << (b)) | ((a) >> (32-(b))))
#define ROTRIGHT(a,b) (((a) >> (b)) | ((a) << (32-(b))))

#define CH(x,y,z) (((x) & (y)) ^ (~(x) & (z)))
#define MAJ(x,y,z) (((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))
#define EP0(x) (ROTRIGHT(x,2) ^ ROTRIGHT(x,13) ^ ROTRIGHT(x,22))
#define EP1(x) (ROTRIGHT(x,6) ^ ROTRIGHT(x,11) ^ ROTRIGHT(x,25))
#define SIG0(x) (ROTRIGHT(x,7) ^ ROTRIGHT(x,18) ^ ((x) >> 3))
#define SIG1(x) (ROTRIGHT(x,17) ^ ROTRIGHT(x,19) ^ ((x) >> 10))

/**************************** VARIABLES *****************************/
__constant uint const k[64] = 
{
    0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
};

/**********************TYPES****************************************/
//TODO: optimize uchar
typedef struct {
    uchar data[64];
    uint datalen;
    ulong bitlen;
    uint state[8];
} SHA256_CTX;

/*********************** FUNCTION DEFINITIONS ***********************/

uint bswap_32(uint x)
{
    return (((x & 0xff000000U) >> 24) | ((x & 0x00ff0000U) >> 8) |
        ((x & 0x0000ff00U) << 8) | ((x & 0x000000ffU) << 24));
}

void WriteBE32(unsigned char* ptr, uint x)
{
    *(uint*)ptr = bswap_32(x);
}

void sha256_transform(SHA256_CTX *ctx, const uchar *data)
{
    uint a, b, c, d, e, f, g, h, i, j, t1, t2, m[64];

    for(i = 0, j = 0; i < 16; ++i, j += 4)
    {
        m[i] = (data[j] << 24) | (data[j + 1] << 16) | (data[j + 2] << 8) | (data[j + 3]);
    }
    for(; i < 64; ++i)
    {
        m[i] = SIG1(m[i - 2]) + m[i - 7] + SIG0(m[i - 15]) + m[i - 16];
    }

    a = ctx->state[0];
    b = ctx->state[1];
    c = ctx->state[2];
    d = ctx->state[3];
    e = ctx->state[4];
    f = ctx->state[5];
    g = ctx->state[6];
    h = ctx->state[7];

    for (i = 0; i < 64; ++i) 
    {
        t1 = h + EP1(e) + CH(e,f,g) + k[i] + m[i];
        t2 = EP0(a) + MAJ(a,b,c);
        h = g;
        g = f;
        f = e;
        e = d + t1;
        d = c;
        c = b;
        b = a;
        a = t1 + t2;
    }

    ctx->state[0] += a;
    ctx->state[1] += b;
    ctx->state[2] += c;
    ctx->state[3] += d;
    ctx->state[4] += e;
    ctx->state[5] += f;
    ctx->state[6] += g;
    ctx->state[7] += h;
}

void sha256_init(SHA256_CTX *ctx)
{
    ctx->datalen = 0;
    ctx->bitlen = 0;
    ctx->state[0] = 0x6a09e667;
    ctx->state[1] = 0xbb67ae85;
    ctx->state[2] = 0x3c6ef372;
    ctx->state[3] = 0xa54ff53a;
    ctx->state[4] = 0x510e527f;
    ctx->state[5] = 0x9b05688c;
    ctx->state[6] = 0x1f83d9ab;
    ctx->state[7] = 0x5be0cd19;
}

void sha256_update(SHA256_CTX *ctx, uchar *data, uint len)
{
    for (uint i = 0; i < len; ++i)
    {
        ctx->data[ctx->datalen] = data[i];
        ctx->datalen++;
        if (ctx->datalen == 64)
        {
            sha256_transform(ctx, ctx->data);
            ctx->bitlen += 512;
            ctx->datalen = 0;
        }
    }
}

void sha256_final(SHA256_CTX *ctx, uchar *hash)
{
    uint i = ctx->datalen;

    // Pad whatever data is left in the buffer.
    if (ctx->datalen < 56)
    {
        ctx->data[i++] = 0x80;
        while (i < 56)
        {
            ctx->data[i++] = 0x00;
        }
    }
    else 
    {
        ctx->data[i++] = 0x80;
        while (i < 64)
        {
            ctx->data[i++] = 0x00;
        }
        sha256_transform(ctx, ctx->data);
        
        for(uint i = 0; i < 7; i++)
        {
            ((ulong*)ctx->data)[i] = 0;
        }		
    }

    // Append to the padding the total message's length in bits and transform.
    ctx->bitlen += ctx->datalen << 3;
    *((uint*)(ctx->data + 60)) = bswap_32((uint)ctx->bitlen);
    *((uint*)(ctx->data + 56)) = bswap_32((uint)(ctx->bitlen >> 32));
    sha256_transform(ctx, ctx->data);

    // Since this implementation uses little endian byte ordering and SHA uses big endian,
    // reverse all the bytes when copying the final state to the output hash.
    WriteBE32(hash, ctx->state[0]);
    WriteBE32(hash + 4, ctx->state[1]);
    WriteBE32(hash + 8, ctx->state[2]);
    WriteBE32(hash + 12, ctx->state[3]);
    WriteBE32(hash + 16, ctx->state[4]);
    WriteBE32(hash + 20, ctx->state[5]);
    WriteBE32(hash + 24, ctx->state[6]);
    WriteBE32(hash + 28, ctx->state[7]);
}

int cmphash(uint *l, uint *r) 
{
    for (int i = 7; i >= 0; --i)
    {
        if (l[i] != r[i])
        {
            return (l[i] < r[i] ? -1 : 1);
        }
    }
    return 0;
}

__kernel void search_nonce(__constant uint const* hashState,
                            ulong startNonce, 
                            uint iterations,
                            __constant uint const* targetHash,
                            __global ulong *output)
{
    SHA256_CTX ctx;
    uint hash[8];
    uint minHash[8];
    ulong min_nonce = 0;
    uint id = get_global_id(0);
    ulong nonce = startNonce + id * iterations;

    for(uint i = 0; i < 8; ++i)
    {
        minHash[i] = targetHash[i];
    }
    for(uint i = 0; i < iterations; ++i)
    {
        for(uint i = 0; i < 8; ++i)
        {
            ctx.state[i] = hashState[i];
        }
        ctx.bitlen = 3584;
        ctx.datalen = 0;
        for(uint i = 0; i < 8; i++)
        {
            ((ulong*)ctx.data)[i] = 0;
        }

        sha256_update(&ctx, (uchar*)&nonce, 8);
        sha256_final(&ctx, (uchar*)hash);
        sha256_init(&ctx);
        sha256_update(&ctx, (uchar*)hash, 32);
        sha256_final(&ctx, (uchar*)hash);

        if(cmphash(minHash, hash) < 0)
        {
            for(uint i = 0; i < 8; ++i)
            {
                minHash[i] = hash[i];
            }
            min_nonce = nonce;
        }
        ++nonce;
    }
    if (min_nonce > 0)
	{
		output[OUTPUT_SIZE] = output[min_nonce & OUTPUT_MASK] = min_nonce;
	}
}
