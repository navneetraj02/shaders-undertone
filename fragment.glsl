uniform float uTime;
uniform vec2 uResolution;
uniform vec2 uCursor;
uniform vec2 uTrail[30]; 
uniform float uActive; // Controls idle fade out
uniform vec2 uVelocity; // Smoothed normalized cursor velocity

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
    
    // Smooth physical refraction + hover bulge (increased refraction to 0.36 for deep glass look)
    vec2 nSt = st + screenNormal * 0.36 - bulgeDir * bulge;
    
    // 5. DIRECTIONAL & SPATIAL COLOR MIXING (INDEPENDENT COLORS)
    // Get direction from cursor to current pixel (refracted position)
    vec2 toCursor = nSt - cursorSt;
    float distToCursor = length(toCursor);
    vec2 spatialDir = (distToCursor > 0.0001) ? (toCursor / distToCursor) : vec2(0.0);
    
    // Add slow time-based rotation to the spatial direction so colors morph/rotate when stationary
    float rotAngle = uTime * 0.3;
    mat2 timeRot = mat2(cos(rotAngle), -sin(rotAngle), sin(rotAngle), cos(rotAngle));
    vec2 morphedSpatialDir = timeRot * spatialDir;
    
    // Add organic noise perturbations to the color lookup direction
    vec2 colorNoise = vec2(
        snoise(vec3(nSt * 1.5, uTime * 0.15)),
        snoise(vec3(nSt * 1.5, uTime * 0.15 + 20.0))
    ) * 0.45;
    
    // Smoothly blend spatial direction with mouse velocity
    // uVelocity represents the direction the cursor is moving
    float speed = length(uVelocity);
    vec2 combinedDir = mix(morphedSpatialDir, uVelocity, smoothstep(0.08, 0.45, speed));
    
    // Apply the noise perturbation to the final color wheel direction
    vec2 finalDir = normalize(combinedDir + colorNoise + vec2(0.001));
    
    // Project direction onto the 4 color axes: Up, Down, Left, Right
    float wUp = max(0.0, finalDir.y);
    float wDown = max(0.0, -finalDir.y);
    float wLeft = max(0.0, -finalDir.x);
    float wRight = max(0.0, finalDir.x);
    
    float totalW = wUp + wDown + wLeft + wRight;
    if (totalW > 0.0) {
        wUp /= totalW;
        wDown /= totalW;
        wLeft /= totalW;
        wRight /= totalW;
    }
    
    // Blend the independent colors
    vec3 fluidColor = wUp * uCursorUpColor + 
                      wDown * uCursorDownColor + 
                      wLeft * uCursorLeftColor + 
                      wRight * uCursorRightColor;
    
    // 6. TRUE GLASS RENDERING COMPOSITION
    
    // Pure white idle background
    vec3 pureWhite = uBackgroundColor; 
    
    // Frosted glass tint — cool light blue-grey, NOT pure white
    float ao = smoothstep(-1.0, 1.0, fluteVal);
    
    // Deepen the fluted glass shadows/AO to define the ridges and reduce white wash
    vec3 coloredGlass = fluidColor * mix(vec3(0.80, 0.83, 0.88), vec3(0.98, 0.99, 1.0), ao);
    
    // Combine pure white with the colored/shadowed glass using the cursor mask
    vec3 finalColor = mix(pureWhite, coloredGlass, cursorMask);
    
    // Glassy reflections — tinted blue-grey like real glass, not blinding white
    vec3 lightDir = normalize(vec3(-0.5, 1.0, 2.0)); 
    float specAmount = pow(max(dot(normal, lightDir), 0.0), 64.0); // sharper, narrower
    // Tint specular with cool glass colour instead of pure white (and slightly brighten specular to 0.22)
    vec3 specular = vec3(0.85, 0.90, 1.0) * specAmount * 0.22;
    
    vec3 viewDir = vec3(0.0, 0.0, 1.0);
    float fresnel = pow(1.0 - max(dot(normal, viewDir), 0.0), 3.0);
    
    finalColor += specular * cursorMask;
    finalColor += vec3(0.85, 0.90, 1.0) * fresnel * 0.08 * cursorMask;
    
    // 7. GLASSY EDGE LINES (Groove Border Effect)
    // Draw a single border line at the flute troughs (where fluteVal = -1.0)
    float borderDist = abs(fluteVal + 1.0);
    float fw2 = fwidth(flutePhase);
    
    // Thin sharp highlight line
    float thinLine = 1.0 - smoothstep(0.0, fw2 * 1.3, borderDist);
    // Soft shadow line to create depth
    float shadowLine = 1.0 - smoothstep(0.0, fw2 * 2.8, borderDist);
    
    // Apply the 3D groove shadow inside the cursor active area to define the borders clearly
    finalColor = mix(finalColor, finalColor * 0.6, shadowLine * cursorMask);
    
    // Add the bright glass highlight (tinted light blue-grey for glass realism)
    vec3 glassLineColor = vec3(0.88, 0.93, 1.0);
    finalColor += glassLineColor * thinLine * 0.35 * cursorMask;
    
    gl_FragColor = vec4(finalColor, 1.0);
}
