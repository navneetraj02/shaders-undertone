uniform float uTime;
uniform vec2 uResolution;
uniform vec2 uCursor;
uniform vec2 uTrail[30]; 
uniform float uActive; // Controls idle fade out

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
// 3D Simplex Noise by Ashima Arts (Optimized to just the core noise)
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

void main() {
    // 1. Setup coordinates
    vec2 aspect = vec2(uResolution.x / uResolution.y, 1.0);
    vec2 st = vUv * aspect;
    vec2 cursorSt = uCursor * aspect;
    
    // 2. GLASS STRUCTURE
    float angle = 20.0 * PI / 180.0;
    float s = sin(angle);
    float c = cos(angle);
    mat2 rot = mat2(c, -s, s, c);
    vec2 rotSt = vUv * rot;
    
    float frequency = uFlutes * 2.0; 
    // Very slowly animate the glass lines drifting down-right!
    float flutePhase = rotSt.x * frequency - uTime * 0.7;
    float fluteVal = sin(flutePhase);
    float fluteDerivative = cos(flutePhase);
    
    // Strong proper normal for deep glass effect when visible
    vec3 normal = normalize(vec3(fluteDerivative * 4.0, 0.0, 1.0));
    vec2 screenNormal = (vec2(normal.x, normal.y) * rot);
    
    // 3. WATER WAKE MASK
    float cursorMask = 0.0;
    for(int i = 0; i < 30; i++) {
        vec2 trailPoint = uTrail[i] * aspect;
        float d = distance(st, trailPoint);
        float age = float(i) / 30.0;
        float intensity = 1.0 - age;
        
        // Large smooth mask for the color
        float radius = uCursorRadius * 0.35 * (1.0 - age * 0.5); 
        cursorMask = max(cursorMask, smoothstep(radius, 0.0, d) * intensity);
    }
    
    // Fade out entirely when idle
    cursorMask *= smoothstep(0.0, 1.0, uActive);
    
    // 4. SLEEK FLUID NOISE
    float t = uTime * 0.1;
    
    // Add a subtle hover bulge effect to make the cursor feel interactive
    vec2 dir = st - cursorSt;
    float len = length(dir);
    vec2 bulgeDir = (len > 0.0) ? (dir / len) : vec2(0.0);
    float bulge = exp(-len * 3.5) * 0.04 * uActive;
    
    // Smooth physical refraction + hover bulge
    vec2 nSt = st + screenNormal * 0.25 - bulgeDir * bulge;
    
    float noise1 = snoise(vec3(nSt * 1.5, t));
    float noise2 = snoise(vec3(nSt * 2.5, t * 1.3 + 10.0));
    
    // 5. INTENSE COLORS
    vec3 colorBlue = uCursorLeftColor;   
    vec3 colorPurple = uCursorUpColor;   
    vec3 colorCyan = uCursorRightColor;  
    
    // Widen the masks so the color fills more area and is highly visible
    float maskBlue = smoothstep(-0.6, 0.6, noise1);
    float maskPurple = smoothstep(-0.4, 0.8, noise2);
    
    vec3 fluidColor = mix(uBackgroundColor, colorBlue, maskBlue);
    fluidColor = mix(fluidColor, colorPurple, maskPurple * 0.9);
    fluidColor = mix(fluidColor, colorCyan, maskPurple * maskBlue);
    
    // 6. FINAL COMPOSITION
    
    // --- GLOBAL GLASS LINES (always visible across entire screen) ---
    // Each line has a soft shadow in the valley and a bright highlight on the peak
    float ao = smoothstep(-1.0, 1.0, fluteVal);
    
    // The line shadow — makes each groove dark (visible as thin dark lines)
    float lineShadow = smoothstep(0.6, 1.0, abs(fluteVal)); // sharp edge near peak
    float lineHighlight = pow(max(fluteVal, 0.0), 8.0);     // bright peak
    
    // Base glass — always white background with very subtle line shading
    vec3 baseGlass = uBackgroundColor;
    baseGlass -= vec3(0.08) * (1.0 - ao);         // soft shadow in grooves
    baseGlass += vec3(0.06) * lineHighlight;       // soft highlight on ridges
    baseGlass = clamp(baseGlass, 0.0, 1.0);
    
    // --- CURSOR COLOR (only where cursor is) ---
    vec3 vibrantFluid = fluidColor * 1.35;
    // Let the glass structure show through the color too
    vec3 coloredGlass = vibrantFluid * mix(vec3(0.92), vec3(1.0), ao);
    
    // Blend: lines always show, color appears only inside cursor mask
    vec3 finalColor = mix(baseGlass, coloredGlass, cursorMask);
    
    // Specular highlights on the peaks — always visible globally, brighter inside cursor
    vec3 lightDir = normalize(vec3(-0.5, 1.0, 2.0)); 
    float specAmount = pow(max(dot(normal, lightDir), 0.0), 64.0);
    // Specular always visible globally (subtle) + extra bright inside cursor
    finalColor += vec3(1.0) * specAmount * 0.12;
    finalColor += vec3(1.0) * specAmount * 0.5 * cursorMask;
    
    // Fresnel glow on line edges — always visible globally
    vec3 viewDir = vec3(0.0, 0.0, 1.0);
    float fresnel = pow(1.0 - max(dot(normal, viewDir), 0.0), 2.0);
    finalColor += vec3(1.0) * fresnel * 0.08;
    finalColor += vec3(1.0) * fresnel * 0.2 * cursorMask;
    
    finalColor = clamp(finalColor, 0.0, 1.0);
    gl_FragColor = vec4(finalColor, 1.0);
}
