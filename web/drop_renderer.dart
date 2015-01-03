part of teapot_renderer;

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
    info.r = drop * strength;
    gl_FragColor = info;
  }
  """;

  GL.Program program;
  
  GL.Texture ripple_texture;

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
      "half_pixel",
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

    if (this.uniforms.containsKey("texture")) {
      gl.activeTexture(GL.TEXTURE0);
      gl.bindTexture(GL.TEXTURE_2D, this.ripple_texture);
      gl.uniform1i(this.uniforms["texture"], 0);
    }
    
    this.setUniformVector2("center", new Vector2.zero());
    this.setUniformFloat("radius", 0.25);
    this.setUniformFloat("strength", 1.0);
    if (this.uniforms.containsKey("center")) {
      gl.uniform2f(this.uniforms["center"], 0.5 / this.dom.width, 0.5 / this.dom.height);
    }

    if (this.attributes.containsKey("position")) {
      gl.enableVertexAttribArray(this.attributes["position"]);
      gl.bindBuffer(GL.ARRAY_BUFFER, this.position_buffer.buffer);
      gl.vertexAttribPointer(this.attributes["position"], 3, GL.FLOAT, false, 0, 0);
    }

    gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
    gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, this.index_buffer.buffer);
    gl.drawElements(GL.TRIANGLES, this.index_buffer.data.length, GL.UNSIGNED_SHORT, 0);
  }
}

