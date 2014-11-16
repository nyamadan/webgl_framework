library teapot_renderer;

import "dart:web_gl" as GL;
import "dart:math" as Math;
import "package:vector_math/vector_math.dart";
import "package:webgl_framework/webgl_framework.dart";
import "teapot.dart" as teapot;

class TeapotRenderer extends WebGLRenderer {
  static const String VS =
  """
  attribute vec3 position;
  attribute vec3 normal;
  attribute vec2 coord;
  uniform mat4 mvp_matrix;

  varying vec3 v_normal;
  varying vec2 v_coord;

  void main(void){
    v_coord = coord;
    v_normal = normal;
    gl_Position = mvp_matrix * vec4(position, 1.0);
  }
  """;

  static const String FS =
  """
  precision mediump float;

  uniform sampler2D texture;

  varying vec3 v_normal;
  varying vec2 v_coord;

  void main(void){
    vec4 color = texture2D(texture, v_coord);
    float d  = clamp(dot(v_normal, vec3(0.0, 0.0, 1.0)), 0.0, 1.0);
    gl_FragColor = vec4(color.rgb * (d * d + 0.5), 1.0);
  }
  """;

  GL.Program program;

  Map<String, int> attributes;
  Map<String, GL.UniformLocation> uniforms;

  WebGLArrayBuffer position_buffer;
  WebGLArrayBuffer normal_buffer;
  WebGLArrayBuffer coord_buffer;
  WebGLElementArrayBuffer index_buffer;
  WebGLCanvasTexture texture;

  TeapotRenderer({int width: 512, int height: 512}) : super(width: width, height: height)
  {
    var vs = this.compileVertexShader(VS);
    var fs = this.compileFragmentShader(FS);
    this.program = this.linkProgram(vs, fs);
    gl.deleteShader(vs);
    gl.deleteShader(fs);

    this.attributes = this.getAttributes(this.program, [
      "position",
      "normal",
      "coord",
    ]);
    this.uniforms = this.getUniformLocations(this.program, [
      "mvp_matrix",
      "texture",
    ]);

    this.position_buffer = this.createArrayBuffer(teapot.positions);
    this.normal_buffer = this.createArrayBuffer(teapot.normals);
    this.coord_buffer = this.createArrayBuffer(teapot.coords);
    this.index_buffer = this.createElementArrayBuffer(teapot.indices);

    gl.enable(GL.DEPTH_TEST);
    gl.clearColor(0.5, 0.5, 0.5, 1.0);
    gl.useProgram(this.program);

    if (this.attributes.containsKey("position")) {
      gl.enableVertexAttribArray(this.attributes["position"]);
      gl.bindBuffer(GL.ARRAY_BUFFER, this.position_buffer.buffer);
      gl.vertexAttribPointer(this.attributes["position"], 3, GL.FLOAT, false, 0, 0);
    }

    if (this.attributes.containsKey("normal")) {
      gl.enableVertexAttribArray(this.attributes["normal"]);
      gl.bindBuffer(GL.ARRAY_BUFFER, this.normal_buffer.buffer);
      gl.vertexAttribPointer(this.attributes["normal"], 3, GL.FLOAT, false, 0, 0);
    }

    if (this.attributes.containsKey("coord")) {
      gl.enableVertexAttribArray(this.attributes["coord"]);
      gl.bindBuffer(GL.ARRAY_BUFFER, this.coord_buffer.buffer);
      gl.vertexAttribPointer(this.attributes["coord"], 2, GL.FLOAT, false, 0, 0);
    }

    this.texture = this.createCanvasTexture();
    this.loadCanvasTexture(this.texture, "pattern.png", flip_y: true);

    gl.activeTexture(GL.TEXTURE0);
  }

  void render(double ms) {
    Matrix4 projection = new Matrix4.identity();
    setPerspectiveMatrix(projection, Math.PI * 60.0 / 180.0, this.aspect, 0.1, 1000.0);

    Matrix4 view = new Matrix4.identity();
    Vector3 look_from = new Vector3(0.0, 0.0, 30.0 + 100.0 * this.trackball_value);
    setViewMatrix(view, look_from, new Vector3(0.0, 0.0, 0.0), new Vector3(0.0, 1.0, 0.0));

    Matrix4 model = new Matrix4.identity();
    model.setRotation(this.trackball_rotation.asRotationMatrix());

    Matrix4 mvp = projection * view * model;

    if (this.uniforms.containsKey("texture")) {
      gl.bindTexture(GL.TEXTURE_2D, this.texture.texture);
      gl.uniform1i(this.uniforms["texture"], 0);
    }

    if (this.uniforms.containsKey("mvp_matrix")) {
      gl.uniformMatrix4fv(this.uniforms["mvp_matrix"], false, mvp.storage);
    }

    gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
    gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, this.index_buffer.buffer);
    gl.drawElements(GL.TRIANGLES, this.index_buffer.data.length, GL.UNSIGNED_SHORT, 0);
  }
}

