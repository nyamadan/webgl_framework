part of mmd_renderer;

class PMD_DeferredRenderer extends WebGLRenderer {
  static const String VS =
  """
  attribute vec3 position;
  varying vec2 v_coord;

  void main(void){
    v_coord = position.xy * 0.5 + 0.5;
    gl_Position = vec4(position, 1.0);
  }
  """;

  static const String FS =
  """
  precision mediump float;

  uniform sampler2D color_texture;
  uniform sampler2D normal_texture;
  uniform sampler2D depth_texture;

  varying vec2 v_coord;

  void main(void){
    vec4 color = texture2D(color_texture, v_coord);
    vec4 normal = texture2D(normal_texture, v_coord);
    float depth = texture2D(depth_texture, v_coord).r;
    gl_FragColor = vec4(color.rgb, 1.0);
  }
  """;

  GL.Program program;
  
  GL.Texture color_texture;
  GL.Texture normal_texture;
  GL.Texture depth_texture;

  Map<String, int> attributes;
  Map<String, GL.UniformLocation> uniforms;

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
      "color_texture",
      "normal_texture",
      "depth_texture",
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

  PMD_DeferredRenderer(int width, int height)
  {
    this.initContext(width, height);
    this.initTrackball();

    this._initialize();
  }

  PMD_DeferredRenderer.copy(WebGLRenderer src) {
    this.gl = src.gl;
    this.dom = src.dom;

    this._initialize();
  }

  void render(double ms) {
    gl.viewport(0, 0, this.dom.width, this.dom.height);
    gl.useProgram(this.program);
    
    gl.enable(GL.DEPTH_TEST);

    this.setUniformTexture0("color_texture", this.color_texture);
    this.setUniformTexture1("normal_texture", this.normal_texture);
    this.setUniformTexture2("depth_texture", this.depth_texture);
    
    this.setAttributeFloat3("position", this.position_buffer.buffer);

    gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
    gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, this.index_buffer.buffer);
    gl.drawElements(GL.TRIANGLES, this.index_buffer.data.length, GL.UNSIGNED_SHORT, 0);
  }
}

