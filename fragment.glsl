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
    
    // Extremely strong normal for structural depth and heavy refraction
    vec3 normal = normalize(vec3(fluteDerivative * 12.0, 0.0, 1.0));
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
    
    // Intense physical refraction to bend the colours deeply like real thick glass
    vec2 nSt = st + screenNormal * 0.6;
    
    float noise1 = snoise(vec3(nSt * 1.5, t));
    float noise2 = snoise(vec3(nSt * 2.5, t * 1.3 + 10.0));
    
    // 5. INTENSE PURE COLORS (Separated by side)
    vec3 colorBlue = uCursorLeftColor;   // Dark blue
    vec3 colorPurple = uCursorUpColor;   // Purple
    
    // Segregate colors: Left side is blue, Right side is purple.
    // We add fluid noise to the boundary so the split looks like mixing liquid rather than a straight line.
    float boundary = vUv.x + (noise1 * 0.3);
    float mixFactor = smoothstep(0.2, 0.8, boundary);
    
    // The fluid color is purely the gradient of those two colors!
    vec3 fluidColor = mix(colorBlue, colorPurple, mixFactor);
    
    // 6. PERFECT ISOLATION RENDERING COMPOSITION
    
    // Pure white idle background
    vec3 pureWhite = uBackgroundColor; 
    
    // Much deeper physical shadows to give the glass ridges intense 3D depth
    float ao = smoothstep(-1.0, 1.0, fluteVal);
    vec3 glassTint = mix(vec3(0.2), vec3(1.0), ao); 
    
    // The rich, fluid colors layered under the glass
    vec3 vibrantFluid = fluidColor * 1.25;
    vec3 coloredGlass = vibrantFluid * mix(vec3(0.65), vec3(1.0), ao);
    
    // Combine pure white with the colored/shadowed glass using the cursor mask
    vec3 finalColor = mix(pureWhite, coloredGlass, cursorMask);
    
    // Double specular lights for that rich, glossy, highly polished studio glass look!
    vec3 lightDir1 = normalize(vec3(-1.0, 1.0, 2.0)); 
    float specAmount1 = pow(max(dot(normal, lightDir1), 0.0), 128.0);
    
    vec3 lightDir2 = normalize(vec3(1.0, -1.0, 1.0)); 
    float specAmount2 = pow(max(dot(normal, lightDir2), 0.0), 64.0);
    
    vec3 specular = vec3(1.0) * (specAmount1 * 2.5 + specAmount2 * 0.8);
    
    // Thick edge fresnel glow
    vec3 viewDir = vec3(0.0, 0.0, 1.0);
    float fresnel = pow(1.0 - max(dot(normal, viewDir), 0.0), 3.0);
    
    // Specular and Fresnel are multiplied by cursorMask so they completely vanish into pure white when idle!
    finalColor += specular * cursorMask;
    finalColor += vec3(1.0) * fresnel * 0.5 * cursorMask;
    
    gl_FragColor = vec4(finalColor, 1.0);
}
