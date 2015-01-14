part of mmd_renderer;

class PMD_DeferredAaRenderer extends WebGLRenderer {
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
  precision highp float;

  uniform sampler2D color_texture;
  uniform sampler2D normal_texture;
  uniform sampler2D depth_texture;

  uniform vec2 delta;

  varying vec2 v_coord;

  const float scale = 300.0;
  const float depth_scale = 1.0;
  float bilateral(vec3 cn, float cz, vec3 n, float z) {
    return exp(-scale * max(depth_scale * abs(cz - z), 1.0 - dot(cn * 0.5 + 1.0, n * 0.5 + 1.0)));
  }

  void main(void){
    mat3 weights = mat3(0.0);
    for(int i1 = 0; i1 < 2; i1++) {
      for(int j1 = 0; j1 < 2; j1++) {
        vec2 offset1 = vec2(delta.x * (float(i1) - 0.5), delta.y * (float(j1) - 0.5));
        mat3 tmp_weights = mat3(0.0);
        vec3 cn = texture2D(normal_texture, v_coord + offset1).rgb;
        float cz = texture2D(depth_texture, v_coord + offset1).r;
        float sum = 0.0;
        for(int i2 = -1; i2 <= 1; i2++) {
          for(int j2 = -1; j2 <= 1; j2++) {
            vec2 offset2 = vec2(delta.x * float(i2), delta.y * float(j2));
            if(abs(offset1.x - offset2.x) <= delta.x && abs(offset1.y - offset2.y) <= delta.y) {
              vec3 n = texture2D(normal_texture, v_coord + offset2).rgb * 2.0;
              float z = texture2D(depth_texture, v_coord + offset2).r;
  
              float w = bilateral(cn, cz, n, z);
              tmp_weights[i2 + 1][j2 + 1] = w;
              sum += w;
            }
          }
        }

        for(int i = 0; i < 3; i++) {
          for(int j = 0; j < 3; j++) {
            weights[i][j] += tmp_weights[i][j] / sum;
          }
        }
      }
    }

    vec4 result = vec4(0.0);
    for(int i = 0; i < 3; i++) {
      for(int j = 0; j < 3; j++) {
        vec2 offset = vec2(delta.x * float(i - 1), delta.y * float(j - 1));
        result += weights[i][j] * 0.25 *  texture2D(color_texture, v_coord + offset);
      }
    }

    //vec3 cn = texture2D(normal_texture, v_coord).rgb;
    //vec3 n = texture2D(normal_texture, v_coord + vec2(delta.x, 0.0)).rgb;
    //float cz = texture2D(depth_texture, v_coord).r;
    //float z = texture2D(depth_texture, v_coord + vec2(delta.x, 0.0)).r;
    //gl_FragColor = vec4(vec3(bilateral(cn, cz, cn, cz)), 1.0);
    //gl_FragColor = vec4(weights[1], 1.0);
    gl_FragColor = result;
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
      "delta",
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

  PMD_DeferredAaRenderer(int width, int height)
  {
    this.initContext(width, height);
    this.initTrackball();

    this._initialize();
  }

  PMD_DeferredAaRenderer.copy(WebGLRenderer src) {
    this.gl = src.gl;
    this.dom = src.dom;

    this._initialize();
  }

  void render(double ms) {
    gl.viewport(0, 0, this.dom.width, this.dom.height);
    gl.useProgram(this.program);
    
    gl.enable(GL.DEPTH_TEST);
    
    this.setUniformVector2("delta", new Vector2(1.0 / this.dom.width, 1.0 / this.dom.height));

    this.setUniformTexture0("color_texture", this.color_texture);
    this.setUniformTexture1("normal_texture", this.normal_texture);
    this.setUniformTexture2("depth_texture", this.depth_texture);
    
    this.setAttributeFloat3("position", this.position_buffer.buffer);

    gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
    gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, this.index_buffer.buffer);
    gl.drawElements(GL.TRIANGLES, this.index_buffer.data.length, GL.UNSIGNED_SHORT, 0);
  }
}
