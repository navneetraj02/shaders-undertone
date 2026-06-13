# UndertonesShader Component

A premium, production-ready animated WebGL background shader component using Three.js and GLSL. This component creates organic, liquid-like, drifting color fields using Fractional Brownian Motion (FBM) and domain warping.

## Features
- **Fluid Organic Motion**: Multi-octave FBM for complex liquid gradients.
- **Domain Warping**: Noise distorting noise, creating premium color blending without seams.
- **Responsive**: Automatically resizes with the window or parent container.
- **Background Mode**: Naturally pushes itself behind content (`z-index: -99`).
- **Separated GLSL**: Vertex and Fragment shaders are logically split into standalone `.glsl` files.

## Installation & Setup

1. Include Three.js in your project (via CDN or bundler):
   ```html
   <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r134/three.min.js"></script>
   ```

2. Include `UndertonesShader.js`:
   ```html
   <script src="UndertonesShader.js"></script>
   ```

3. Ensure `vertex.glsl` and `fragment.glsl` are in the same directory as your HTML file (or update the fetch paths in `UndertonesShader.js`).

4. Because it fetches the `.glsl` files via HTTP, you must run this on a local web server (e.g. `python3 -m http.server`), not directly from a `file://` URL.

## Usage

```javascript
const background = new UndertonesShader({
  selector: 'body', // The DOM element to attach the canvas to
  colors: ['#ff6b6b', '#ffb86b', '#ffd86b', '#ff8e6b'], // Up to 4 colors
  speed: 1.0,       // Animation speed
  intensity: 1.0,   // Color mixing contrast
  distortion: 0.5,  // Amount of domain warping
  opacity: 0.8,     // Canvas opacity
  scale: 1.0,       // Scale of the noise
  zIndex: -99       // CSS z-index of the canvas
});
```

## Dynamic Updates

You can update the shader properties in real-time without re-instantiating:

```javascript
background.updateOptions({
  speed: 2.0,
  colors: ['#000000', '#ffffff', '#ff0000', '#0000ff']
});
```

## Cleanup

To completely remove the shader and prevent memory leaks (e.g. in single-page applications):

```javascript
background.dispose();
```
