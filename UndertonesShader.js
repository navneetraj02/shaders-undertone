/**
 * UndertonesShader - Fluted Glass Edition
 * Recreates the exact "Undertones 3" preset from shaders.com.
 * Uses diagonal 3D glass ridges and a colorful refracting cursor light.
 */
class UndertonesShader {
  /**
   * @param {Object} options Configuration options matching the UI.
   */
  constructor(options = {}) {
    this.selector = options.selector || 'body';
    
    // UI Default colors
    this.backgroundColor = options.backgroundColor || '#ffffff';
    this.cursorBaseColor = options.cursorBaseColor || '#ffffff';
    this.cursorUpColor = options.cursorUpColor || '#7f66ff';
    this.cursorDownColor = options.cursorDownColor || '#4642ff';
    this.cursorLeftColor = options.cursorLeftColor || '#56c2fc';
    this.cursorRightColor = options.cursorRightColor || '#5b4fff';
    
    // Parameters
    this.cursorRadius = options.cursorRadius !== undefined ? options.cursorRadius : 2.0;
    this.flutes = options.flutes !== undefined ? options.flutes : 15.0; // Ridge density
    this.zIndex = options.zIndex !== undefined ? options.zIndex : -99;
    
    this.container = document.querySelector(this.selector);
    if (!this.container) {
      console.error(`UndertonesShader: Container "${this.selector}" not found.`);
      return;
    }

    // Mouse tracking state for the color mask
    this.mouse = new THREE.Vector2(0.5, 0.5);
    this.targetMouse = new THREE.Vector2(0.5, 0.5);
    
    // Idle fading state
    this.activeState = 1.0; // Start fully visible
    
    // Trail array for water effect
    this.trailCount = 30; // Increased length for stickiness
    this.trail = [];
    for(let i = 0; i < this.trailCount; i++) {
        this.trail.push(new THREE.Vector2(0.5, 0.5));
    }

    // Fetch shaders asynchronously
    this.init();
  }

  async init() {
    try {
        const [vertexShader, fragmentShader] = await Promise.all([
            fetch('vertex.glsl').then(res => res.text()),
            fetch('fragment.glsl').then(res => res.text())
        ]);

        this.setupThree(vertexShader, fragmentShader);
    } catch (error) {
        console.error("UndertonesShader: Failed to load GLSL files. Ensure you are running a local server.", error);
    }
  }

  setupThree(vertexShader, fragmentShader) {
    this.scene = new THREE.Scene();
    
    // Orthographic camera for 2D plane
    this.camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 10);
    this.camera.position.z = 1;

    this.renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    
    this.updateSize();
    
    // Style the canvas to sit behind content
    const canvas = this.renderer.domElement;
    canvas.style.position = this.selector === 'body' ? 'fixed' : 'absolute';
    canvas.style.top = '0';
    canvas.style.left = '0';
    canvas.style.width = '100%';
    canvas.style.height = '100%';
    canvas.style.zIndex = this.zIndex;
    canvas.style.pointerEvents = 'none';
    
    if (this.selector !== 'body' && getComputedStyle(this.container).position === 'static') {
        this.container.style.position = 'relative';
        this.container.style.overflow = 'hidden';
    }

    this.container.appendChild(canvas);

    this.geometry = new THREE.PlaneGeometry(2, 2);

    this.material = new THREE.ShaderMaterial({
      vertexShader,
      fragmentShader,
      uniforms: {
        uTime: { value: 0 },
        uResolution: { value: new THREE.Vector2(this.width, this.height) },
        uCursor: { value: this.mouse },
        uTrail: { value: this.trail },
        uActive: { value: this.activeState },
        uCursorRadius: { value: this.cursorRadius },
        uFlutes: { value: this.flutes },
        uBackgroundColor: { value: new THREE.Color(this.backgroundColor) },
        uCursorBaseColor: { value: new THREE.Color(this.cursorBaseColor) },
        uCursorUpColor: { value: new THREE.Color(this.cursorUpColor) },
        uCursorDownColor: { value: new THREE.Color(this.cursorDownColor) },
        uCursorLeftColor: { value: new THREE.Color(this.cursorLeftColor) },
        uCursorRightColor: { value: new THREE.Color(this.cursorRightColor) }
      }
    });

    this.mesh = new THREE.Mesh(this.geometry, this.material);
    this.scene.add(this.mesh);

    this.clock = new THREE.Clock();
    
    // Bind events
    this.onResize = this.onResize.bind(this);
    this.onMouseMove = this.onMouseMove.bind(this);
    window.addEventListener('resize', this.onResize);
    window.addEventListener('mousemove', this.onMouseMove);
    window.addEventListener('touchmove', this.onMouseMove, { passive: true });

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
    if (!this.renderer) return;
    this.updateSize();
    if (this.material && this.material.uniforms) {
      this.material.uniforms.uResolution.value.set(this.width, this.height);
    }
  }

  onMouseMove(e) {
    let clientX, clientY;
    if (e.touches && e.touches.length > 0) {
        clientX = e.touches[0].clientX;
        clientY = e.touches[0].clientY;
    } else {
        clientX = e.clientX;
        clientY = e.clientY;
    }

    if (this.selector === 'body') {
        this.targetMouse.x = clientX / window.innerWidth;
        this.targetMouse.y = 1.0 - (clientY / window.innerHeight);
    } else {
        const rect = this.container.getBoundingClientRect();
        this.targetMouse.x = (clientX - rect.left) / rect.width;
        this.targetMouse.y = 1.0 - ((clientY - rect.top) / rect.height);
    }
  }

  render() {
    this.animationId = requestAnimationFrame(this.render.bind(this));
    
    const delta = this.clock.getDelta();
    
    if (this.material) {
        this.material.uniforms.uTime.value += delta;
        
        // Handle idle fading - slow fade out (approx 6.7 seconds to fully dissolve)
        const dist = this.mouse.distanceTo(this.targetMouse);
        if (dist > 0.0005) {
            this.activeState = Math.min(this.activeState + delta * 3.0, 1.0);
        } else {
            this.activeState = Math.max(this.activeState - delta * 0.15, 0.0);
        }
        
        // Track the target mouse position instantly (no lag for the main glow center)
        this.mouse.copy(this.targetMouse);
        
        // Elastic sticky trail physics - head follows instantly, trail follows responsively
        this.trail[0].copy(this.mouse);
        for(let i = 1; i < this.trailCount; i++) {
            // Each point pulls towards the point in front of it (0.06 lerp for long lagging trail follow)
            this.trail[i].lerp(this.trail[i-1], 0.06);
        }
        
        if (this.material.uniforms.uCursor) {
            this.material.uniforms.uCursor.value.copy(this.mouse);
            this.material.uniforms.uTrail.value = this.trail;
            this.material.uniforms.uActive.value = this.activeState;
        }
    }

    this.renderer.render(this.scene, this.camera);
  }

  /**
   * Update properties via UI
   */
  updateOptions(options = {}) {
    if (!this.material) return;
    
    const u = this.material.uniforms;
    if (options.cursorRadius !== undefined) u.uCursorRadius.value = options.cursorRadius;
    if (options.flutes !== undefined) u.uFlutes.value = options.flutes;
    
    if (options.backgroundColor) u.uBackgroundColor.value.set(options.backgroundColor);
    if (options.cursorBaseColor) u.uCursorBaseColor.value.set(options.cursorBaseColor);
    if (options.cursorUpColor) u.uCursorUpColor.value.set(options.cursorUpColor);
    if (options.cursorDownColor) u.uCursorDownColor.value.set(options.cursorDownColor);
    if (options.cursorLeftColor) u.uCursorLeftColor.value.set(options.cursorLeftColor);
    if (options.cursorRightColor) u.uCursorRightColor.value.set(options.cursorRightColor);
  }

  dispose() {
    if (this.animationId) cancelAnimationFrame(this.animationId);
    window.removeEventListener('resize', this.onResize);
    window.removeEventListener('mousemove', this.onMouseMove);
    window.removeEventListener('touchmove', this.onMouseMove);
    
    if (this.renderer) {
        this.container.removeChild(this.renderer.domElement);
        this.renderer.dispose();
    }
    if (this.geometry) this.geometry.dispose();
    if (this.material) this.material.dispose();
  }
}

if (typeof module !== 'undefined' && module.exports) {
    module.exports = UndertonesShader;
} else if (typeof window !== 'undefined') {
    window.UndertonesShader = UndertonesShader;
}
