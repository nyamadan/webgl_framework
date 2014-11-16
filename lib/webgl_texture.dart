part of webgl_framework;

class WebGLCanvasTexture {
  CanvasElement canvas;
  CanvasRenderingContext2D ctx;

  GL.Texture texture;

  WebGLCanvasTexture([this.texture, this.canvas, this.ctx]);
}

