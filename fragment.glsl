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
    // Slowly animate the glass panels drifting down-right
    float flutePhase = rotSt.x * frequency - uTime * 0.7;

    // ---- SHARP FLAT PANEL GLASS ----
    float stripPos = fract(flutePhase / (PI * 2.0));

    // Very thin crisp border lines
    float borderWidth = 0.02;
    float leftEdge  = smoothstep(0.0, borderWidth, stripPos);
    float rightEdge = smoothstep(1.0, 1.0 - borderWidth, stripPos);
    float interior  = leftEdge * rightEdge;
    float fluteVal  = interior;

    // Normal kicks sharply only at borders for clean edge reflections
    float edgeSign  = (stripPos < 0.5) ? 1.0 : -1.0;
    float normalKick = (1.0 - interior) * edgeSign;
    vec3 normal = normalize(vec3(normalKick * 7.0, 0.0, 1.0));
    vec2 screenNormal = (vec2(normal.x, normal.y) * rot);

    // HOVER GLOW: cursor proximity brightens the glass lines around it
    float cursorDist = distance(st, cursorSt);
    float hoverGlow = exp(-cursorDist * 4.5) * uActive;
    // The glow is strongest right on the border lines
    float borderGlow = (1.0 - interior) * hoverGlow * 0.6;
    
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
    
    // Stronger hover bulge for premium interactive feel
    vec2 dir = st - cursorSt;
    float len = length(dir);
    vec2 bulgeDir = (len > 0.0) ? (dir / len) : vec2(0.0);
    float bulge = exp(-len * 3.0) * 0.07 * uActive;
    
    // Glass refraction + hover bulge distortion
    vec2 nSt = st + screenNormal * 0.3 - bulgeDir * bulge;
    
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
    
    // 6. TRUE GLASS RENDERING COMPOSITION
    
    // Pure white idle background
    vec3 pureWhite = uBackgroundColor; 
    
    // Deep dark borders, bright white panel interiors
    vec3 glassTint = mix(vec3(0.50), vec3(1.0), fluteVal);
    vec3 baseGlass = uBackgroundColor * glassTint;

    // Fluid colors shine through, borders stay dark and crisp
    vec3 vibrantFluid = fluidColor * 1.4;
    vec3 coloredGlass = vibrantFluid * mix(vec3(0.72), vec3(1.0), fluteVal);
    
    vec3 finalColor = mix(pureWhite, coloredGlass, cursorMask);
    
    // Sharp specular glint right on the border lines
    vec3 lightDir = normalize(vec3(-0.5, 1.0, 2.0)); 
    float specAmount = pow(max(dot(normal, lightDir), 0.0), 28.0);
    vec3 specular = vec3(1.0) * specAmount * 1.3;
    
    vec3 viewDir = vec3(0.0, 0.0, 1.0);
    float fresnel = pow(1.0 - max(dot(normal, viewDir), 0.0), 1.5);
    
    // Apply glass shine + the hover border glow effect
    finalColor += specular * cursorMask;
    finalColor += vec3(1.0) * fresnel * 0.4 * cursorMask;
    // Hover glow lights up the border lines near the cursor even without color
    finalColor += vec3(0.85, 0.90, 1.0) * borderGlow * (1.0 - cursorMask);
    
    gl_FragColor = vec4(finalColor, 1.0);
}
