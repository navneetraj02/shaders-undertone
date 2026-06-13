uniform float uTime;
uniform vec2 uResolution;
uniform vec2 uCursor;

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
    
    // 2. DIAGONAL GLASS BANDS
    float angle = 20.0 * PI / 180.0;
    float s = sin(angle);
    float c = cos(angle);
    mat2 rot = mat2(c, -s, s, c);
    vec2 rotSt = vUv * rot;
    
    // Create sleek, clean ridges
    float frequency = uFlutes * 2.0; 
    float flutePhase = rotSt.x * frequency;
    float fluteVal = sin(flutePhase);
    
    // Soft, elegant glass shadowing instead of heavy specular logic
    float ridgeShadow = smoothstep(-1.0, 1.0, fluteVal);
    vec3 baseGlass = mix(uBackgroundColor * 0.85, uBackgroundColor, ridgeShadow);
    
    // 3. SLEEK FLUID NOISE (Highly optimized - only 2 noise calls!)
    float t = uTime * 0.2;
    // Calculate noise along the diagonal flutes for a natural flow
    float noise1 = snoise(vec3(rotSt.x * 2.0, rotSt.y * 1.5, t));
    float noise2 = snoise(vec3(rotSt.x * 3.0 - 2.0, rotSt.y * 2.5, t * 1.2 + 10.0));
    
    // 4. SPOTLIGHT / CURSOR TRACKING
    float distToCursor = distance(st, cursorSt);
    // Large, soft, elegant spotlight matching the reference
    float spotlight = smoothstep(uCursorRadius * 0.4, 0.0, distToCursor);
    
    // 5. COLOR BLENDING
    // Vibrant colors matching the screenshot
    vec3 colorBlue = uCursorLeftColor;   // Vibrant Blue
    vec3 colorPurple = uCursorUpColor;   // Vibrant Purple
    vec3 colorCyan = uCursorRightColor;  // Cyan accent
    
    // Create organic masks from the noise and the spotlight
    float maskBlue = smoothstep(-0.4, 0.6, noise1) * spotlight;
    float maskPurple = smoothstep(-0.2, 0.8, noise2) * spotlight;
    
    // Blend the sleek vibrant colors together
    vec3 fluidColor = mix(uBackgroundColor, colorBlue, maskBlue);
    fluidColor = mix(fluidColor, colorPurple, maskPurple * 0.9);
    
    // Add a very subtle cyan glow right at the cursor center for depth
    float centerGlow = smoothstep(uCursorRadius * 0.15, 0.0, distToCursor);
    fluidColor = mix(fluidColor, colorCyan, centerGlow * 0.4);
    
    // 6. FINAL COMPOSITION
    // Blend the fluid color seamlessly under the clean glass ridges
    // We add a tiny bit of ridge highlighting to make the bands pop like the screenshot
    float highlight = smoothstep(0.8, 1.0, fluteVal) * 0.3 * spotlight;
    
    vec3 finalColor = mix(baseGlass, fluidColor, spotlight);
    finalColor += vec3(1.0) * highlight; // sleek white ridge reflections
    
    gl_FragColor = vec4(finalColor, 1.0);
}
