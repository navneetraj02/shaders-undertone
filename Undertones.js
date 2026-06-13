class Undertones {
  constructor(options = {}) {
    this.selector = options.selector || 'body';
    this.colors = options.colors || ['#FF5E7E', '#030014', '#1F0033', '#0000FF'];
    this.speed = options.speed !== undefined ? options.speed : 0.5;
    this.intensity = options.intensity !== undefined ? options.intensity : 1.0;
    this.distortion = options.distortion !== undefined ? options.distortion : 1.0;
    this.opacity = options.opacity !== undefined ? options.opacity : 1.0;
    
    // Ensure we have exactly 4 colors for the shader
    this.threeColors = this.colors.map(c => new THREE.Color(c));
    while(this.threeColors.length < 4) {
      this.threeColors.push(this.threeColors[this.threeColors.length - 1]);
    }
    
    this.container = document.querySelector(this.selector);
    if (!this.container) {
      console.error(`Undertones: Container with selector "${this.selector}" not found.`);
      return;
    }

    this.init();
  }

  init() {
    this.scene = new THREE.Scene();
    
    // Create an orthographic camera exactly covering the viewing plane
    this.camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 10);
    this.camera.position.z = 1;

    this.renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    
    // We want the canvas to cover the container entirely
    // If the container is 'body', we use window dimensions
    this.updateSize();
    
    // Style the canvas to sit behind content
    this.renderer.domElement.style.position = this.selector === 'body' ? 'fixed' : 'absolute';
    this.renderer.domElement.style.top = '0';
    this.renderer.domElement.style.left = '0';
    this.renderer.domElement.style.width = '100%';
    this.renderer.domElement.style.height = '100%';
    this.renderer.domElement.style.zIndex = '-99';
    this.renderer.domElement.style.pointerEvents = 'none';
    this.renderer.domElement.style.opacity = this.opacity;
    
    // Make sure container is positioned to contain absolute elements if not body
    if (this.selector !== 'body' && getComputedStyle(this.container).position === 'static') {
        this.container.style.position = 'relative';
    }

    this.container.appendChild(this.renderer.domElement);

    this.setupGeometry();
    this.setupMaterial();
    this.setupMesh();

    this.clock = new THREE.Clock();
    
    this.onResize = this.onResize.bind(this);
    window.addEventListener('resize', this.onResize);

    this.render();
  }

  updateSize() {
    if (this.selector === 'body') {
        this.width = window.innerWidth;
        this.height = window.innerHeight;
    } else {
        const rect = this.container.getBoundingClientRect();
        this.width = rect.width;
        this.height = rect.height;
    }
    this.renderer.setSize(this.width, this.height);
  }

  onResize() {
    this.updateSize();
    if (this.material && this.material.uniforms) {
      this.material.uniforms.uResolution.value.set(this.width, this.height);
    }
  }

  setupGeometry() {
    // Plane covering the normalized device coordinates (-1 to 1)
    this.geometry = new THREE.PlaneGeometry(2, 2);
  }

  setupMaterial() {
    const vertexShader = `
      varying vec2 vUv;
      void main() {
        vUv = uv;
        gl_Position = vec4(position, 1.0);
      }
    `;

    const fragmentShader = `
      uniform float uTime;
      uniform vec2 uResolution;
      uniform vec3 uColor1;
      uniform vec3 uColor2;
      uniform vec3 uColor3;
      uniform vec3 uColor4;
      uniform float uIntensity;
      uniform float uDistortion;
      
      varying vec2 vUv;

      // 3D Simplex noise function
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
        return 42.0 * dot( m*m, vec4( dot(p0,x0), dot(p1,x1), 
                                      dot(p2,x2), dot(p3,x3) ) );
      }

      void main() {
        // Normalize coordinates and account for aspect ratio
        vec2 uv = vUv;
        float aspect = uResolution.x / uResolution.y;
        vec2 st = uv;
        st.x *= aspect;
        
        // Base noise values driving the color mix
        float n1 = snoise(vec3(st * uDistortion, uTime));
        float n2 = snoise(vec3(st * uDistortion * 1.5 - vec2(5.0, 3.0), uTime * 1.2));
        float n3 = snoise(vec3(st * uDistortion * 2.0 + vec2(1.0, -2.0), uTime * 0.8));
        
        // Smooth and intensify noise
        n1 = smoothstep(0.0, 1.0, n1 * 0.5 + 0.5);
        n2 = smoothstep(0.0, 1.0, n2 * 0.5 + 0.5);
        n3 = smoothstep(0.0, 1.0, n3 * 0.5 + 0.5);
        
        // Mix colors based on noise
        vec3 color = uColor1;
        
        // Blend dynamically
        float mix1 = clamp(n1 * uIntensity, 0.0, 1.0);
        float mix2 = clamp(n2 * uIntensity, 0.0, 1.0);
        float mix3 = clamp(n3 * uIntensity, 0.0, 1.0);
        
        color = mix(color, uColor2, mix1);
        color = mix(color, uColor3, mix2);
        color = mix(color, uColor4, mix3);
        
        // Add subtle grain/noise for better aesthetic (removes banding)
        float grain = fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453) * 0.04;
        color += grain;

        gl_FragColor = vec4(color, 1.0);
      }
    `;

    this.material = new THREE.ShaderMaterial({
      vertexShader,
      fragmentShader,
      uniforms: {
        uTime: { value: 0 },
        uResolution: { value: new THREE.Vector2(this.width, this.height) },
        uColor1: { value: this.threeColors[0] },
        uColor2: { value: this.threeColors[1] },
        uColor3: { value: this.threeColors[2] },
        uColor4: { value: this.threeColors[3] },
        uIntensity: { value: this.intensity },
        uDistortion: { value: this.distortion }
      }
    });
  }

  setupMesh() {
    this.mesh = new THREE.Mesh(this.geometry, this.material);
    this.scene.add(this.mesh);
  }

  render() {
    requestAnimationFrame(this.render.bind(this));
    
    // Update time based on speed
    const delta = this.clock.getDelta();
    this.material.uniforms.uTime.value += delta * this.speed;

    this.renderer.render(this.scene, this.camera);
  }

  // Helper method to update properties dynamically
  updateOptions(options = {}) {
    if (options.speed !== undefined) this.speed = options.speed;
    if (options.intensity !== undefined) {
        this.intensity = options.intensity;
        this.material.uniforms.uIntensity.value = this.intensity;
    }
    if (options.distortion !== undefined) {
        this.distortion = options.distortion;
        this.material.uniforms.uDistortion.value = this.distortion;
    }
    if (options.opacity !== undefined) {
        this.opacity = options.opacity;
        this.renderer.domElement.style.opacity = this.opacity;
    }
    if (options.colors) {
        this.colors = options.colors;
        const newColors = this.colors.map(c => new THREE.Color(c));
        while(newColors.length < 4) newColors.push(newColors[newColors.length - 1]);
        
        this.material.uniforms.uColor1.value.copy(newColors[0]);
        this.material.uniforms.uColor2.value.copy(newColors[1]);
        this.material.uniforms.uColor3.value.copy(newColors[2]);
        this.material.uniforms.uColor4.value.copy(newColors[3]);
    }
  }

  // Cleanup to avoid memory leaks
  destroy() {
    window.removeEventListener('resize', this.onResize);
    this.container.removeChild(this.renderer.domElement);
    this.renderer.dispose();
    this.geometry.dispose();
    this.material.dispose();
  }
}

// Export for ES modules, or attach to window for CDN script usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = Undertones;
} else if (typeof window !== 'undefined') {
    window.Undertones = Undertones;
}
