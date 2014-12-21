part of webgl_framework;

class DebugVertex {
  Vector3 position = new Vector3.zero();
  Vector4 color = new Vector4(1.0, 1.0, 1.0, 1.0);
  double point_size = 3.0;

  DebugVertex(Vector3 position, {Vector4 color, double point_size}) {
    if(position != null) {
      this.position = position;
    }

    if(color != null) {
      this.color = color;
    }

    if(point_size != null) {
      this.point_size = point_size;
    }
  }
}

class DebugParticleShader extends WebGLRenderer
{
  static const String VS =
  """
  uniform mat4 mvp_matrix;

  attribute vec3 position;
  attribute vec4 color;
  attribute float point_size;

  varying vec4 v_color;

  void main(void){
    v_color = color;

    gl_PointSize = point_size;
    gl_Position = mvp_matrix * vec4(position, 1.0);
  }
  """;

  static const String FS =
  """
  precision mediump float;

  varying vec4 v_color;

  void main(void){
    gl_FragColor = v_color;
  }
  """;

  //debug program
  GL.Program program;
  Map<String, int> attributes;
  Map<String, GL.UniformLocation> uniforms;

  //debug buffer
  WebGLArrayBuffer32 position_buffer;
  WebGLArrayBuffer32 color_buffer;
  WebGLArrayBuffer32 point_size_buffer;

  //debug info
  List<DebugVertex> vertices;

  Matrix4 mvp;

  DebugParticleShader(int width, int height)
  {
    this.initContext(width, height);
    this.initTrackball();
    this._initialize();
  }

  DebugParticleShader.copy(WebGLRenderer src) {
    this.gl = src.gl;
    this.dom = src.dom;
    this._initialize();
  }

  void _initialize() {
    var vs = this.compileVertexShader(VS);
    var fs = this.compileFragmentShader(FS);
    this.program = this.linkProgram(vs, fs);
    gl.deleteShader(vs);
    gl.deleteShader(fs);

    this.attributes = this.getAttributes(this.program, [
      "position",
      "color",
      "point_size",
    ]);

    this.uniforms = this.getUniformLocations(this.program, [
      "mvp_matrix",
    ]);

    this.mvp = new Matrix4.identity();
    this.color_buffer = new WebGLArrayBuffer32(gl, new Float32List.fromList([]));
    this.position_buffer = new WebGLArrayBuffer32(gl, new Float32List.fromList([]));
    this.point_size_buffer = new WebGLArrayBuffer32(gl, new Float32List.fromList([]));
  }


  void render(double elapsed) {
    bool enable_vertex = this.vertices != null && this.vertices.isNotEmpty;
    if(!enable_vertex) {
      return;
    }

    gl.disable(GL.DEPTH_TEST);
    gl.useProgram(this.program);

    Float32List position_data = new Float32List(this.vertices.length * 3);
    Float32List color_data = new Float32List(this.vertices.length * 4);
    Float32List point_size_data = new Float32List(this.vertices.length);
    for(int i = 0; i < this.vertices.length; i++) {
      position_data.setRange(i * 3, (i + 1) * 3, this.vertices[i].position.storage);
      color_data.setRange(i * 4, (i + 1) * 4, this.vertices[i].color.storage);
      point_size_data[i] = this.vertices[i].point_size;
    }

    position_buffer.setData(gl, position_data);
    color_buffer.setData(gl, color_data);
    point_size_buffer.setData(gl, point_size_data);

    if (this.uniforms.containsKey("mvp_matrix")) {
      gl.uniformMatrix4fv(this.uniforms["mvp_matrix"], false, mvp.storage);
    }

    if (this.attributes.containsKey("color")) {
      gl.enableVertexAttribArray(this.attributes["color"]);
      gl.bindBuffer(GL.ARRAY_BUFFER, this.color_buffer.buffer);
      gl.vertexAttribPointer(this.attributes["color"], 4, GL.FLOAT, false, 0, 0);
    }

    if (this.attributes.containsKey("point_size")) {
      gl.enableVertexAttribArray(this.attributes["point_size"]);
      gl.bindBuffer(GL.ARRAY_BUFFER, this.point_size_buffer.buffer);
      gl.vertexAttribPointer(this.attributes["point_size"], 1, GL.FLOAT, false, 0, 0);
    }

    if (this.attributes.containsKey("position")) {
      gl.enableVertexAttribArray(this.attributes["position"]);
      gl.bindBuffer(GL.ARRAY_BUFFER, this.position_buffer.buffer);
      gl.vertexAttribPointer(this.attributes["position"], 3, GL.FLOAT, false, 0, 0);

      gl.drawArrays(GL.POINTS, 0, this.vertices.length);
    }
  }
}

