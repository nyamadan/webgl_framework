part of ripple_renderer;

class DropRenderer extends WebGLRenderer {
  static const String VS =
  """
  attribute vec3 position;
  varying vec2 coord;

  void main(void){
    coord = position.xy * 0.5 + 0.5;
    gl_Position = vec4(position, 1.0);
  }
  """;

  static const String FS =
  """
  precision mediump float;

  const float PI = 3.141592653589793;
  uniform sampler2D texture;
  uniform vec2 center;
  uniform float radius;
  uniform float strength;
  varying vec2 coord;

  void main(void){
    vec4 info = texture2D(texture, coord);
    float drop = max(0.0, 1.0 - length(center * 0.5 + 0.5 - coord) / radius);
    drop = 0.5 - cos(drop * PI) * 0.5;
    info.r += drop * strength;
    gl_FragColor = info;
  }
  """;

  GL.Program program;
  
  GL.Texture ripple_texture;
  
  Vector2 center;
  double radius;
  double strength;

  WebGLArrayBuffer32 position_buffer;
  WebGLElementArrayBuffer16 index_buffer;

  void _initialize() {
    var vs = this.compileVertexShader(VS);
    var fs = this.compileFragmentShader(FS);
    this.program = this.linkProgram(vs, fs);
    gl.deleteShader(vs);
    gl.deleteShader(fs);

    this.attributes = this.getAttributes(this.program, [
      "position",
    ]);
    this.uniforms = this.getUniformLocations(this.program, [
      "texture",
      "center",
      "strength",
      "radius",
    ]);

    this.position_buffer = new WebGLArrayBuffer32(gl, new Float32List.fromList([
      -1.0,  1.0, 0.0,
       1.0,  1.0, 0.0,
       1.0, -1.0, 0.0,
      -1.0, -1.0, 0.0,
    ]));
    
    this.index_buffer = new WebGLElementArrayBuffer16(gl, new Uint16List.fromList([
      0, 1, 3,
      1, 2, 3,
    ]));
  }

  DropRenderer(int width, int height)
  {
    this.initContext(width, height);
    this.initTrackball();

    this._initialize();
  }

  DropRenderer.copy(WebGLRenderer src) {
    this.gl = src.gl;
    this.dom = src.dom;

    this._initialize();
  }
  
  void render(double ms) {
    gl.viewport(0, 0, this.dom.width, this.dom.height);
    gl.useProgram(this.program);
    
    gl.enable(GL.DEPTH_TEST);
    gl.clearColor(0.5, 0.5, 0.5, 1.0);

    this.setUniformTexture0("texture", this.ripple_texture);
    this.setUniformVector2("center", this.center != null ? this.center : new Vector2.zero());
    this.setUniformFloat("radius", this.radius != null ? this.radius : 0.125);
    this.setUniformFloat("strength", this.strength != null ? this.strength : 0.05);
    this.setAttributeFloat3("position", this.position_buffer.buffer);

    gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
    gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, this.index_buffer.buffer);
    gl.drawElements(GL.TRIANGLES, this.index_buffer.data.length, GL.UNSIGNED_SHORT, 0);
  }
}

