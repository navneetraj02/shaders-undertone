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
    
    // The glass structure forms screen-wide based on uActive and fades out slowly
    
    // 2. GLASS STRUCTURE
    float angle = 20.0 * PI / 180.0;
    float s = sin(angle);
    float c = cos(angle);
    mat2 rot = mat2(c, -s, s, c);
    vec2 rotSt = vUv * rot;
    
    float frequency = uFlutes * 2.0; 
    
    // Dynamic smooth trail warp (bulges/expands the color columns along the trail and then contracts)
    // Uses smooth probabilistic union to prevent sharp Voronoi/min-distance crease lines
    float trailBulge = 0.0;
    float nonActiveProb = 1.0;
    for(int i = 0; i < 30; i += 3) {
        vec2 trailPoint = uTrail[i] * aspect;
        float d = distance(st, trailPoint);
        float age = float(i) / 30.0;
        float intensity = 1.0 - age;
        
        // Smooth weight for this trail point (radius 0.48)
        float w = smoothstep(0.48, 0.0, d) * intensity;
        nonActiveProb *= (1.0 - w);
    }
    trailBulge = (1.0 - nonActiveProb) * uActive;
    
    // Very slowly animate the glass lines drifting down-right!
    float flutePhase = rotSt.x * frequency - uTime * 0.7;
    float fluteVal = sin(flutePhase);
    float fluteDerivative = cos(flutePhase);
    
    // Strong proper normal for deep glass effect when visible
    vec3 normal = normalize(vec3(fluteDerivative * 4.0, 0.0, 1.0));
    vec2 screenNormal = (vec2(normal.x, normal.y) * rot);
    
    // 3. SLEEK FLUID NOISE (Optimized: calculated first to reuse noise)
    float t = uTime * 0.1;
    
    // Add a tactile hover bulge/press effect to make the cursor feel interactive
    vec2 dir = st - cursorSt;
    float len = length(dir);
    
    // Smooth out the center divisor to eliminate the sharp "pinched" singularity at the cursor position
    float smoothLen = len + 0.16; 
    vec2 bulgeDisplacement = dir * (exp(-len * 1.1) * 0.45 * uActive) / smoothLen;
    
    // Constant direction perpendicular to the diagonal flutes (prevents high-frequency line artifacts across the cursor)
    vec2 waveDir = vec2(c, s);
    
    // Smooth physical refraction + hover bulge + smooth trail bulge (bulges the background color organically)
    vec2 nSt = st + screenNormal * 0.48 - bulgeDisplacement + waveDir * trailBulge * 0.35;
    
    // Compute Ashima 3D Simplex noise once and reuse it for both coordinates warping and color mixes
    float noise1 = snoise(vec3(nSt * 1.5, t));
    float noise2 = snoise(vec3(nSt * 2.5, t * 1.3 + 10.0));
    
    // 4. WATER WAKE MASK (with organic fluid warping using noise)
    float cursorMask = 0.0;
    // Reuse noise1 and noise2 to simulate organic fluid/water flow without extra snoise calls
    vec2 fluidWarp = vec2(noise1, noise2) * 0.12 * uActive;
    vec2 fluidSt = st + fluidWarp;
    
    // Smooth probabilistic union to prevent sharp crease artifacts on color boundaries
    float nonActiveColorProb = 1.0;
    for(int i = 0; i < 30; i++) {
        vec2 trailPoint = uTrail[i] * aspect;
        float d = distance(fluidSt, trailPoint);
        float age = float(i) / 30.0;
        float intensity = pow(1.0 - age, 2.0); // Slower decay along the trail so colors fade slower
        
        // Large smooth mask for the color
        float radius = uCursorRadius * 0.30 * (1.0 - age * 0.5); 
        float w = smoothstep(radius, 0.0, d) * intensity;
        nonActiveColorProb *= (1.0 - w);
    }
    // The colors fade out slower using pow(uActive, 2.0), then slowly the glass lines fade out using uActive directly
    cursorMask = (1.0 - nonActiveColorProb) * pow(uActive, 2.0);
    
    // 5. 4-WAY SEPARATED GRADIENT COLORS
    vec3 cLeft = uCursorLeftColor;     // #56c2fc (Vibrant Light Cyan-Blue)
    vec3 cRight = uCursorRightColor;   // #5b4fff (Vibrant Indigo-Blue)
    vec3 cUp = uCursorUpColor;         // #7f66ff (Vibrant Purple-Blue)
    vec3 cDown = uCursorDownColor;     // #4642ff (Vibrant Blue-Purple)
    
    // Combine noise to create a fluid mask (widen thresholds and add 0.35 minimum color density to prevent white wash)
    float rawNoiseMask = smoothstep(-0.8, 0.4, noise1 * 0.5 + noise2 * 0.5);
    float fluidMask = mix(0.35, 1.0, rawNoiseMask);
    
    // 2D bilinear gradient blending with organic noise to create a seamless 4-color fluid texture
    float mixHorizontal = smoothstep(0.25, 0.75, vUv.x + noise1 * 0.08);
    float mixVertical = smoothstep(0.25, 0.75, vUv.y + noise2 * 0.08);
    
    vec3 colorHoriz = mix(cLeft, cRight, mixHorizontal);
    vec3 colorVert = mix(cDown, cUp, mixVertical);
    vec3 gradientColor = mix(colorHoriz, colorVert, 0.5);
    
    // Add light blue highlight in the top-left corner (using uCursorLeftColor) with an organic wavy boundary
    float distToTopLeft = distance(vUv, vec2(0.0, 1.0));
    float topLeftMask = smoothstep(0.65, 0.15, distToTopLeft + noise2 * 0.06);
    gradientColor = mix(gradientColor, cLeft, topLeftMask);
    
    // Add a bottom-spanning purple gradient that transitions from uCursorDownColor to uCursorRightColor
    float bottomMask = smoothstep(0.35, 0.0, vUv.y + noise1 * 0.05);
    float bottomXFactor = smoothstep(0.0, 0.6, vUv.x + noise2 * 0.04);
    vec3 bottomPurpleColor = mix(cDown, cRight, bottomXFactor);
    gradientColor = mix(gradientColor, bottomPurpleColor, bottomMask);
    
    // Mix background white with the dynamic gradient color
    vec3 fluidColor = mix(uBackgroundColor, gradientColor, fluidMask);
    
    // 6. TRUE GLASS RENDERING COMPOSITION
    
    // Pure white idle background
    vec3 pureWhite = uBackgroundColor; 
    
    // Frosted glass tint — cool light blue-grey, NOT pure white
    float ao = smoothstep(-1.0, 1.0, fluteVal);
    // Use a subtle cool frost colour so empty glass areas feel like ice/glass
    vec3 frostColor = mix(vec3(0.88, 0.90, 0.94), vec3(0.97, 0.98, 1.0), ao);
    vec3 baseGlass = frostColor;
    
    // Keep colors deep and dark
    vec3 vibrantFluid = fluidColor;
    // In coloured areas the glass stays more transparent so colour shines through clearly
    vec3 coloredGlass = vibrantFluid * mix(vec3(0.92), vec3(1.0), ao);
    
    // Start with a clean white background
    vec3 finalColor = pureWhite;
    
    // Blend the beautiful 3D colored glass flutes inside the cursorMask core
    finalColor = mix(finalColor, coloredGlass, cursorMask);

    // Add a subtle grey shadow border around the colored region
    float colorDist = distance(st, cursorSt);
    float borderRadius = uCursorRadius * 1.2;
    float borderMask = smoothstep(uCursorRadius, borderRadius, colorDist);
    vec3 borderGray = vec3(0.5);
    finalColor = mix(finalColor, borderGray, borderMask * 0.15);    
    // Glassy reflections — dynamic zig-zag specular reflection that follows the cursor
    vec3 lightVec = vec3(cursorSt - st, 0.20); 
    vec3 lightDir = normalize(lightVec);
    vec3 viewDir = vec3(0.0, 0.0, 1.0);
    vec3 halfDir = normalize(lightDir + viewDir);
    
    // Rotate the 3D normal into screen space for physically accurate reflection
    vec3 screenNormal3D = vec3(screenNormal, normal.z);
    
    // Specular exponent (128.0) and factor (0.55) to create a beautiful glassy reflection glint
    float specAmount = pow(max(dot(screenNormal3D, halfDir), 0.0), 128.0);
    
    // Restrict highlight to the peaks (ridges) of the flutes to create a stepped/zig-zag reflection
    float ridgeMask = smoothstep(0.3, 1.0, fluteVal);
    
    // Tint the reflection with the local 4-color mixed gradient to show the reflection of our exact custom colors
    vec3 specColor = mix(vec3(0.95, 0.98, 1.0), gradientColor, 0.75);
    vec3 specular = specColor * specAmount * ridgeMask * 0.55;
    
    float fresnel = pow(1.0 - max(dot(screenNormal3D, viewDir), 0.0), 3.0);
    
    // Apply specular and fresnel reflections screen-wide using uActive
    vec3 fresnelColor = mix(vec3(0.85, 0.90, 1.0), gradientColor, 0.65);
    finalColor += specular * uActive;
    finalColor += fresnelColor * fresnel * 0.12 * uActive;
    
    // 7. GLASSY EDGE LINES (Border Lines)
    // Draw crisp, thin border lines at both peaks (ridges) and troughs (valleys) of the flutes
    // using screen-space derivatives for a perfectly uniform pixel width.
    float phaseNormalized = flutePhase / (2.0 * PI);
    float borderPhase = phaseNormalized * 2.0 + 0.5; // Double frequency, aligned to peaks and troughs
    float distToBorder = min(fract(borderPhase), 1.0 - fract(borderPhase));
    
    // Constant screen-space width for thin border lines (approx 2 pixels wide)
    float fwNormalized = fwidth(borderPhase);
    float thinLine = 1.0 - smoothstep(0.0, fwNormalized * 0.35, distToBorder);
    
    // Very subtle, thin shadow line to prevent the "double line" visual illusion (approx 3 pixels wide)
    float shadowLine = 1.0 - smoothstep(0.0, fwNormalized * 0.60, distToBorder);
    
    // Soft grey glow backing to make the thin lines stand out beautifully on the white space
    float lineGlow = 1.0 - smoothstep(0.0, fwNormalized * 1.8, distToBorder);
    finalColor = mix(finalColor, vec3(0.92, 0.93, 0.95), lineGlow * 0.65 * uActive);
    
    // Deeper shadow mix across the entire screen using uActive to keep lines thin and visible on white background
    finalColor = mix(finalColor, vec3(0.82, 0.84, 0.88), shadowLine * 0.50 * uActive);
    
    // Glass highlight: blue-ish/purple-ish tint inside cursor mask, soft glassy grey outside
    vec3 localBorderColor = mix(vec3(0.4, 0.65, 1.0), vec3(0.75, 0.45, 1.0), mixHorizontal);
    vec3 baseGlassLine = vec3(0.58, 0.59, 0.61); // Medium-dark grey, properly visible on the white space
    vec3 borderLineColor = mix(baseGlassLine, localBorderColor, cursorMask);
    
    // Draw thin glassy border lines screen-wide using mix to keep them perfectly thin and visible
    finalColor = mix(finalColor, borderLineColor, thinLine * 0.65 * uActive);
    
    // Add shiny light appearance along the borders of the lines and under it (strictly 0.35 width to match thinLine)
    float shinyBorder = 1.0 - smoothstep(0.0, fwNormalized * 0.35, distToBorder);
    
    // Tint the edge highlight with the local 4-color mixed gradient to show the color reflection (only inside uCursorMask)
    vec3 shinyHighlightColor = mix(vec3(0.95, 0.98, 1.0), gradientColor, 0.70);
    vec3 shinyHighlight = shinyHighlightColor * shinyBorder * (0.35 + specAmount * 2.5) * cursorMask;
    finalColor += shinyHighlight * uActive;
    
    gl_FragColor = vec4(finalColor, 1.0);
}
