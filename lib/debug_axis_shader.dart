part of webgl_framework;

class DebugAxis {
  Vector3 position = new Vector3.zero();
  Vector3 size = new Vector3(1.0, 1.0, 1.0);
  Quaternion rotation = new Quaternion.identity();

  DebugAxis(Vector3 position, {Vector4 color, Vector3 size, Quaternion rotation}) {
    if(position != null) {
      this.position = position;
    }

    if(size != null) {
      this.size = size;
    }

    if(rotation != null) {
      this.rotation = rotation;
    }
  }
}

class DebugAxisShader extends WebGLRenderer
{
  static const String VS =
  """
  uniform mat4 mvp_matrix;

  attribute vec3 position;
  attribute vec4 color;

  varying vec4 v_color;

  void main(void){
    v_color = color;

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

  //debug info
  List<DebugAxis> axises;

  Matrix4 mvp;

  DebugAxisShader(int width, int height)
  {
    this.initContext(width, height);
    this.initTrackball();
    this._initialize();
  }

  DebugAxisShader.copy(WebGLRenderer src) {
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
    ]);

    this.uniforms = this.getUniformLocations(this.program, [
      "mvp_matrix",
    ]);

    this.mvp = new Matrix4.identity();
    this.color_buffer = new WebGLArrayBuffer32(gl, new Float32List.fromList([]));
    this.position_buffer = new WebGLArrayBuffer32(gl, new Float32List.fromList([]));
  }

  void render(double elapsed) {
    bool enabled = this.axises != null && this.axises.isNotEmpty;
    if(!enabled) {
      return;
    }

    gl.disable(GL.DEPTH_TEST);
    gl.useProgram(this.program);

    Float32List position_data = new Float32List(this.axises.length * 3 * 6);
    Float32List color_data = new Float32List(this.axises.length * 4 * 6);
    for(int i = 0; i < this.axises.length; i++) {
      DebugAxis axis = this.axises[i];
      Vector3 origin = axis.position;
      Vector3 v = axis.size;

      int position_offset = i * 18;
      int color_offset = i * 24;

      Vector3 position_x = new Vector3(v.x, 0.0, 0.0);
      axis.rotation.rotate(position_x);
      position_x.add(origin);
      position_data.setRange(position_offset + 0, position_offset + 3, origin.storage);
      position_data.setRange(position_offset + 3, position_offset + 6, position_x.storage);

      Vector3 position_y = new Vector3(0.0, v.y, 0.0);
      axis.rotation.rotate(position_y);
      position_y.add(origin);
      position_data.setRange(position_offset + 6, position_offset + 9, origin.storage);
      position_data.setRange(position_offset + 9, position_offset + 12, position_y.storage);

      Vector3 position_z = new Vector3(0.0, 0.0, v.z);
      axis.rotation.rotate(position_z);
      position_z.add(origin);
      position_data.setRange(position_offset + 12, position_offset + 15, origin.storage);
      position_data.setRange(position_offset + 15, position_offset + 18, position_z.storage);

      Vector4 color_x = new Vector4(1.0, 0.0, 0.0, 1.0);
      color_data.setRange(color_offset, color_offset + 4, color_x.storage);
      color_data.setRange(color_offset + 4, color_offset + 8, color_x.storage);

      Vector4 color_y = new Vector4(0.0, 1.0, 0.0, 1.0);
      color_data.setRange(color_offset + 8, color_offset + 12, color_y.storage);
      color_data.setRange(color_offset + 12, color_offset + 16, color_y.storage);

      Vector4 color_z = new Vector4(0.0, 0.0, 1.0, 1.0);
      color_data.setRange(color_offset + 16, color_offset + 20, color_z.storage);
      color_data.setRange(color_offset + 20, color_offset + 24, color_z.storage);
    }

    position_buffer.setData(gl, position_data);
    color_buffer.setData(gl, color_data);

    if (this.uniforms.containsKey("mvp_matrix")) {
      gl.uniformMatrix4fv(this.uniforms["mvp_matrix"], false, mvp.storage);
    }

    if (this.attributes.containsKey("color")) {
      gl.enableVertexAttribArray(this.attributes["color"]);
      gl.bindBuffer(GL.ARRAY_BUFFER, this.color_buffer.buffer);
      gl.vertexAttribPointer(this.attributes["color"], 4, GL.FLOAT, false, 0, 0);
    }

    if (this.attributes.containsKey("position")) {
      gl.enableVertexAttribArray(this.attributes["position"]);
      gl.bindBuffer(GL.ARRAY_BUFFER, this.position_buffer.buffer);
      gl.vertexAttribPointer(this.attributes["position"], 3, GL.FLOAT, false, 0, 0);

      gl.drawArrays(GL.LINES, 0, this.axises.length * 6);
    }
  }
}
