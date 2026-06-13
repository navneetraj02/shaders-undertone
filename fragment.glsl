uniform float uTime;
uniform vec2 uResolution;
uniform vec2 uCursor;
uniform vec2 uTrail[30];

uniform vec3 uBackgroundColor;
uniform vec3 uCursorBaseColor;
uniform vec3 uCursorUpColor;
uniform vec3 uCursorDownColor;
uniform vec3 uCursorLeftColor;
uniform vec3 uCursorRightColor;

uniform float uFlutes;
uniform float uCursorRadius;

varying vec2 vUv;

#define PI 3.14159265359

// -------------------------------------------------------------------------
// 3D Simplex Noise by Ashima Arts
vec4 permute(vec4 x){return mod(((x*34.0)+1.0)*x, 289.0);}
vec4 taylorInvSqrt(vec4 r){return 1.79284291400159 - 0.85373472095314 * r;}

float snoise(vec3 v){ 
  const vec2  C = vec2(1.0/6.0, 1.0/3.0) ;
  const vec4  D = vec4(0.0, 0.5, 1.0, 2.0);

  vec3 i  = floor(v + dot(v, C.yyy) );
  vec3 x0 = v - i + dot(i, C.xxx) ;

  vec3 g = step(x0.yzx, x0.xyz);
  vec3 l = 1.0 - g;
  vec3 i1 = min( g.xyz, l.zxy );
  vec3 i2 = max( g.xyz, l.zxy );

  vec3 x1 = x0 - i1 + 1.0 * C.xxx;
  vec3 x2 = x0 - i2 + 2.0 * C.xxx;
  vec3 x3 = x0 - 1.0 + 3.0 * C.xxx;

  i = mod(i, 289.0 ); 
  vec4 p = permute( permute( permute( 
             i.z + vec4(0.0, i1.z, i2.z, 1.0 ))
           + i.y + vec4(0.0, i1.y, i2.y, 1.0 )) 
           + i.x + vec4(0.0, i1.x, i2.x, 1.0 ));

  float n_ = 1.0/7.0; 
  vec3  ns = n_ * D.wyz - D.xzx;

  vec4 j = p - 49.0 * floor(p * ns.z *ns.z);  

  vec4 x_ = floor(j * ns.z);
  vec4 y_ = floor(j - 7.0 * x_ );    

  vec4 x = x_ *ns.x + ns.yyyy;
  vec4 y = y_ *ns.x + ns.yyyy;
  vec4 h = 1.0 - abs(x) - abs(y);

  vec4 b0 = vec4( x.xy, y.xy );
  vec4 b1 = vec4( x.zw, y.zw );

  vec4 s0 = floor(b0)*2.0 + 1.0;
  vec4 s1 = floor(b1)*2.0 + 1.0;
  vec4 sh = -step(h, vec4(0.0));

  vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
  vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww ;

  vec3 p0 = vec3(a0.xy,h.x);
  vec3 p1 = vec3(a0.zw,h.y);
  vec3 p2 = vec3(a1.xy,h.z);
  vec3 p3 = vec3(a1.zw,h.w);

  vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
  p0 *= norm.x;
  p1 *= norm.y;
  p2 *= norm.z;
  p3 *= norm.w;

  vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
  m = m * m;
  return 42.0 * dot( m*m, vec4( dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3) ) );
}

// -------------------------------------------------------------------------
// Fractional Brownian Motion
float fbm(vec3 x) {
    float v = 0.0;
    float a = 0.5;
    vec3 shift = vec3(100.0);
    for (int i = 0; i < 4; ++i) {
        v += a * snoise(x);
        x = x * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

void main() {
    // 1. Setup coordinates
    vec2 aspect = vec2(uResolution.x / uResolution.y, 1.0);
    vec2 st = vUv * aspect;
    vec2 cursorSt = uCursor * aspect;
    
    // 2. FLUTED GLASS CALCULATION (70 degree rotation)
    float angle = 20.0 * PI / 180.0;
    float s = sin(angle);
    float c = cos(angle);
    mat2 rot = mat2(c, -s, s, c);
    vec2 rotSt = vUv * rot;
    
    float frequency = uFlutes * 2.5; 
    float flutePhase = rotSt.x * frequency;
    
    float fluteVal = sin(flutePhase);
    float fluteDerivative = cos(flutePhase);
    
    // Strong glass normal
    vec3 normal = normalize(vec3(fluteDerivative * 3.5, 0.0, 1.0));
    vec2 screenNormal = (vec2(normal.x, normal.y) * rot);
    
    // 3. FLUID ADVECTION LOGIC (Domain Warping)
    // Made extremely slow/still as requested
    float t = uTime * 0.01;
    
    // We add intense Chromatic Aberration/Dispersion by computing fluid 3 times!
    float refrStrengthR = 0.25;
    float refrStrengthG = 0.35;
    float refrStrengthB = 0.45;
    
    vec2 nStR = (st + screenNormal * refrStrengthR) * 1.5;
    vec2 nStG = (st + screenNormal * refrStrengthG) * 1.5;
    vec2 nStB = (st + screenNormal * refrStrengthB) * 1.5;
    
    // Domain warp R
    vec2 qR = vec2(fbm(vec3(nStR, t)), fbm(vec3(nStR + vec2(5.2, 1.3), t)));
    vec2 rR = vec2(fbm(vec3(nStR + 2.0*qR + vec2(1.7, 9.2), t*1.2)), fbm(vec3(nStR + 2.0*qR + vec2(8.3, 2.8), t*1.5)));
    float fR = fbm(vec3(nStR + 1.5*rR, t*0.8));
    
    // Domain warp G
    vec2 qG = vec2(fbm(vec3(nStG, t)), fbm(vec3(nStG + vec2(5.2, 1.3), t)));
    vec2 rG = vec2(fbm(vec3(nStG + 2.0*qG + vec2(1.7, 9.2), t*1.2)), fbm(vec3(nStG + 2.0*qG + vec2(8.3, 2.8), t*1.5)));
    float fG = fbm(vec3(nStG + 1.5*rG, t*0.8));
    
    // Domain warp B
    vec2 qB = vec2(fbm(vec3(nStB, t)), fbm(vec3(nStB + vec2(5.2, 1.3), t)));
    vec2 rB = vec2(fbm(vec3(nStB + 2.0*qB + vec2(1.7, 9.2), t*1.2)), fbm(vec3(nStB + 2.0*qB + vec2(8.3, 2.8), t*1.5)));
    float fB = fbm(vec3(nStB + 1.5*rB, t*0.8));
    
    // 4. TRAIL CALCULATION
    float cursorMask = 0.0;
    // Iterate over the trail array to build a smooth fading mask
    for(int i = 0; i < 30; i++) {
        vec2 trailPoint = uTrail[i] * aspect;
        float d = distance(st, trailPoint);
        // fade size and intensity based on age in trail
        float age = float(i) / 30.0;
        float radius = uCursorRadius * 0.35 * (1.0 - age * 0.5); // size shrinks slightly
        float intensity = 1.0 - age; // opacity fades completely
        cursorMask = max(cursorMask, smoothstep(radius, 0.0, d) * intensity);
    }
    
    // 5. COLOR MAPPING (using the split R, G, B noises for rich chromatic effect)
    
    // Calculate masks for the different color channels to make it intensely vibrant
    float maskR1 = smoothstep(-0.3, 0.5, fR) * cursorMask;
    float maskG1 = smoothstep(-0.3, 0.5, fG) * cursorMask;
    float maskB1 = smoothstep(-0.3, 0.5, fB) * cursorMask;
    
    float f2R = fbm(vec3(nStR - 1.5*rR, t*0.9+10.0));
    float f2G = fbm(vec3(nStG - 1.5*rG, t*0.9+10.0));
    float f2B = fbm(vec3(nStB - 1.5*rB, t*0.9+10.0));
    
    float maskR2 = smoothstep(-0.2, 0.6, f2R) * cursorMask;
    float maskG2 = smoothstep(-0.2, 0.6, f2G) * cursorMask;
    float maskB2 = smoothstep(-0.2, 0.6, f2B) * cursorMask;
    
    // Rich saturated inks
    vec3 color1 = mix(uCursorLeftColor, uCursorRightColor, fG);
    vec3 color2 = mix(uCursorUpColor, uCursorDownColor, f2G);
    
    // We compose the colored fluid separately for R, G, and B to get the rainbow edges
    float finalR = mix(1.0, color1.r, maskR1) * mix(1.0, color2.r, maskR2 * 0.8);
    float finalG = mix(1.0, color1.g, maskG1) * mix(1.0, color2.g, maskG2 * 0.8);
    float finalB = mix(1.0, color1.b, maskB1) * mix(1.0, color2.b, maskB2 * 0.8);
    
    vec3 fluidColor = vec3(finalR, finalG, finalB);
    
    // 6. GLASS LIGHTING OVERLAY
    float shadow = smoothstep(-1.0, 1.0, fluteVal);
    vec3 glassTint = mix(vec3(0.92), vec3(1.0), shadow);
    
    vec3 finalColor = fluidColor * glassTint;
    
    // Specular Highlights - scaled back slightly so they don't wash out the rich colors
    vec3 lightDir = normalize(vec3(-1.0, 1.0, 2.0)); 
    float specAmount = pow(max(dot(normal, lightDir), 0.0), 128.0);
    vec3 specular = vec3(1.0) * specAmount * 0.8; 
    
    vec3 rimDir = normalize(vec3(1.0, -1.0, 0.5));
    float rimAmount = pow(max(dot(normal, rimDir), 0.0), 64.0);
    vec3 rim = vec3(1.0) * rimAmount * 0.2;
    
    finalColor += specular + rim;

    gl_FragColor = vec4(finalColor, 1.0);
}
