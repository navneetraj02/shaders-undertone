uniform float uTime;
uniform vec2 uResolution;
uniform vec2 uCursor;
uniform vec2 uTrail[15]; 
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
// Extremely optimized 2D Value Noise (sine-free hash, lag-free)
float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float noise2D(vec2 p) {
    vec2 i = floor(p);
    vec2 pLocal = fract(p);
    vec2 u = pLocal * pLocal * (3.0 - 2.0 * pLocal);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y) * 2.0 - 1.0;
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
    
    // 3. WATER WAKE MASK (with organic fluid warping)
    float cursorMask = 0.0;
    // Dynamic coordinate warping using fast sine/cosine waves (extremely optimized, lag-free)
    float wavePhase = uTime * 2.5;
    vec2 fluidWarp = vec2(
        sin(st.y * 6.0 + wavePhase) * cos(st.x * 4.0 - wavePhase),
        cos(st.x * 6.0 + wavePhase) * sin(st.y * 4.0 - wavePhase)
    ) * 0.08 * uActive;
    vec2 fluidSt = st + fluidWarp;
    
    for(int i = 0; i < 15; i++) {
        vec2 trailPoint = uTrail[i] * aspect;
        float d = distance(fluidSt, trailPoint);
        float age = float(i) / 15.0;
        float intensity = 1.0 - age;
        
        // Large smooth mask for the color
        float radius = uCursorRadius * 0.35 * (1.0 - age * 0.5); 
        cursorMask = max(cursorMask, smoothstep(radius, 0.0, d) * intensity);
    }
    
    // Fade out entirely when idle
    cursorMask *= smoothstep(0.0, 1.0, uActive);
    
    // 4. SLEEK FLUID NOISE
    float t = uTime * 0.1;
    
    // Add a tactile hover bulge/press effect to make the cursor feel interactive
    vec2 dir = st - cursorSt;
    float len = length(dir);
    
    // Smooth out the center divisor to eliminate the sharp "pinched" singularity at the cursor position
    float smoothLen = len + 0.16; 
    vec2 bulgeDisplacement = dir * (exp(-len * 1.1) * 0.45 * uActive) / smoothLen;
    
    // Smooth physical refraction + hover bulge (refraction set to 0.48 for deep tactile response)
    vec2 nSt = st + screenNormal * 0.48 - bulgeDisplacement;
    
    float noise1 = noise2D(nSt * 1.5 + vec2(t * 0.2, t * 0.15));
    float noise2 = noise2D(nSt * 2.5 - vec2(t * 0.1, t * 0.2));
    
    // 5. HORIZONTALLY SEPARATED GRADIENT COLORS
    vec3 colorBlue = uCursorLeftColor;   
    vec3 colorPurple = uCursorUpColor;   
    
    // Combine noise to create a fluid mask (widen thresholds and add 0.35 minimum color density to prevent white wash)
    float rawNoiseMask = smoothstep(-0.8, 0.4, noise1 * 0.5 + noise2 * 0.5);
    float fluidMask = mix(0.35, 1.0, rawNoiseMask);
    
    // Horizontal gradient factor (left = blue, right = purple) with organic wavy boundary
    // Sharpened and centered so left is completely blue and right is completely purple
    float gradientFactor = smoothstep(0.42, 0.58, vUv.x + noise1 * 0.08);
    vec3 gradientColor = mix(colorBlue, colorPurple, gradientFactor);
    
    // Add light blue in the top-left corner (vUv.x close to 0, vUv.y close to 1) with an organic wavy boundary
    float distToTopLeft = distance(vUv, vec2(0.0, 1.0));
    float topLeftMask = smoothstep(0.65, 0.15, distToTopLeft + noise2 * 0.06);
    vec3 colorLightBlue = vec3(0.35, 0.75, 1.0); // Beautiful vibrant light blue
    gradientColor = mix(gradientColor, colorLightBlue, topLeftMask);
    
    // Add sky blue along with dark blue in the bottom-left corner (vUv.x close to 0, vUv.y close to 0)
    float distToBottomLeft = distance(vUv, vec2(0.0, 0.0));
    float bottomLeftMask = smoothstep(0.65, 0.15, distToBottomLeft + noise2 * 0.06);
    float bottomLeftMix = smoothstep(-0.3, 0.3, noise1 * 0.5);
    vec3 bottomLeftColor = mix(colorBlue, colorLightBlue, bottomLeftMix);
    gradientColor = mix(gradientColor, bottomLeftColor, bottomLeftMask);
    
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
    
    // Combine pure white with the colored/shadowed glass using the cursor mask
    vec3 finalColor = mix(pureWhite, coloredGlass, cursorMask);
    
    // Glassy reflections — dynamic zig-zag specular reflection that follows the cursor
    vec3 lightVec = vec3(cursorSt - st, 0.20); 
    vec3 lightDir = normalize(lightVec);
    vec3 viewDir = vec3(0.0, 0.0, 1.0);
    vec3 halfDir = normalize(lightDir + viewDir);
    
    // Rotate the 3D normal into screen space for physically accurate reflection
    vec3 screenNormal3D = vec3(screenNormal, normal.z);
    
    // Extremely sharp specular exponent (512.0) and tiny factor (0.02) to create a subtle reflection-like glint
    float specAmount = pow(max(dot(screenNormal3D, halfDir), 0.0), 512.0);
    
    // Restrict highlight to the peaks (ridges) of the flutes to create a stepped/zig-zag reflection
    float ridgeMask = smoothstep(0.3, 1.0, fluteVal);
    vec3 specular = vec3(0.92, 0.96, 1.0) * specAmount * ridgeMask * 0.02;
    
    float fresnel = pow(1.0 - max(dot(screenNormal3D, viewDir), 0.0), 3.0);
    
    finalColor += specular * cursorMask;
    finalColor += vec3(0.85, 0.90, 1.0) * fresnel * 0.0 * cursorMask;
    
    // 7. GLASSY EDGE LINES (Border Lines)
    // Draw crisp, thin border lines at both peaks (ridges) and troughs (valleys) of the flutes
    // using screen-space derivatives for a perfectly uniform pixel width.
    float phaseNormalized = flutePhase / (2.0 * PI);
    float borderPhase = phaseNormalized * 2.0 + 0.5; // Double frequency, aligned to peaks and troughs
    float distToBorder = min(fract(borderPhase), 1.0 - fract(borderPhase));
    
    // Constant screen-space width for thin border lines (approx 2 pixels wide)
    float fwNormalized = fwidth(borderPhase);
    float thinLine = 1.0 - smoothstep(0.0, fwNormalized * 0.5, distToBorder);
    
    // Very subtle, thin shadow line to prevent the "double line" visual illusion (approx 3 pixels wide)
    float shadowLine = 1.0 - smoothstep(0.0, fwNormalized * 0.8, distToBorder);
    
    // Deeper shadow mix (0.70) across the entire screen (using uActive instead of cursorMask)
    finalColor = mix(finalColor, finalColor * 0.70, shadowLine * uActive);
    
    // Glass highlight: blue-ish/purple-ish tint inside cursor mask, soft glassy grey outside
    vec3 localBorderColor = mix(vec3(0.4, 0.65, 1.0), vec3(0.75, 0.45, 1.0), gradientFactor);
    vec3 baseGlassLine = vec3(0.85, 0.88, 0.92);
    vec3 borderLineColor = mix(baseGlassLine, localBorderColor, cursorMask);
    
    // Set visibility to 0.65 across the entire screen (using uActive instead of cursorMask)
    finalColor += borderLineColor * thinLine * 0.65 * uActive;
    
    gl_FragColor = vec4(finalColor, 1.0);
}
