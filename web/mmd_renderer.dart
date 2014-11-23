library mmd_renderer;

import 'dart:html';
import 'dart:typed_data';
import 'dart:async';
import 'dart:math' as Math;
import 'dart:web_gl' as GL;

import "package:webgl_framework/webgl_framework.dart";
import "package:vector_math/vector_math.dart";

import "sjis_to_string.dart";

part "mmd_parser.dart";

class MMD_Renderer extends WebGLRenderer {
  static const String VS =
  """
  attribute vec3 position;
  attribute vec3 normal;
  attribute vec2 coord;
  uniform mat4 mvp_matrix;
  uniform mat4 normal_matrix;

  varying vec3 v_normal;
  varying vec2 v_coord;

  void main(void){
    v_normal = vec3(normal_matrix * vec4(normal, 1.0));
    v_coord = coord;
    gl_Position = mvp_matrix * vec4(position, 1.0);
  }
  """;

  static const String FS =
  """
  precision mediump float;

  uniform vec4 diffuse;
  uniform sampler2D texture;

  varying vec3 v_normal;
  varying vec2 v_coord;

  void main(void){
    vec4 tex_color = texture2D(texture, v_coord);

    float d = clamp(dot(v_normal, vec3(0.0, 0.0, 1.0)), 0.0, 1.0);
    d = (d * d) * 0.5 + 0.5;
    gl_FragColor = vec4(diffuse.rgb * tex_color.rgb * d, diffuse.a);
  }
  """;

  GL.Program program;

  Map<String, int> attributes;
  Map<String, GL.UniformLocation> uniforms;

  WebGLArrayBuffer position_buffer;
  WebGLArrayBuffer normal_buffer;
  WebGLArrayBuffer coord_buffer;
  List<WebGLElementArrayBuffer> index_buffer_list;
  Map<String, WebGLCanvasTexture> textures;
  WebGLCanvasTexture white_texture;

  PMD_Model pmd;

  MMD_Renderer({int width: 512, int height: 512}) : super(width: width, height: height)
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
      "diffuse",
      "texture",
      "mvp_matrix",
      "normal_matrix",
    ]);

    gl.enable(GL.DEPTH_TEST);
    gl.depthFunc(GL.LEQUAL);

    gl.enable(GL.CULL_FACE);
    gl.frontFace(GL.CCW);

    gl.clearColor(0.5, 0.5, 0.5, 1.0);
    gl.useProgram(this.program);

    if (this.attributes.containsKey("position")) {
      gl.enableVertexAttribArray(this.attributes["position"]);
    }

    if (this.attributes.containsKey("normal")) {
      gl.enableVertexAttribArray(this.attributes["normal"]);
    }

    if (this.attributes.containsKey("coord")) {
      gl.enableVertexAttribArray(this.attributes["coord"]);
    }

    gl.activeTexture(GL.TEXTURE0);

    this._load();
  }

  void _load() {
    (new PMD_Model())
    .load("miku.pmd")
    .then((PMD_Model pmd){
      var position_list = pmd.createPositionList();
      var normal_list = pmd.createNormalList();
      var coord_list = pmd.createCoordList();

      this.position_buffer = new WebGLArrayBuffer(gl, position_list);
      this.normal_buffer = new WebGLArrayBuffer(gl, normal_list);
      this.coord_buffer = new WebGLArrayBuffer(gl, coord_list);

      this.index_buffer_list = new List<WebGLElementArrayBuffer>.generate(pmd.materials.length,
        (int i) => new WebGLElementArrayBuffer(gl, pmd.createTriangleList(i))
      );

      this.white_texture = new WebGLCanvasTexture(gl,
        width : 16, height : 16,
        color : new Vector4(1.0, 1.0, 1.0, 1.0)
      );

      this.textures = new Map<String, WebGLCanvasTexture>();
      pmd.materials.forEach((PMD_Material material){
        if( material.texture_file_name.isEmpty || this.textures.containsKey(material.texture_file_name)) {
          return;
        }

        var texture = new WebGLCanvasTexture(gl);
        texture.load(gl, material.texture_file_name);
        this.textures[material.texture_file_name] = texture;
      });

      this.pmd = pmd;
    });
  }

  void render(double ms) {
    if (this.pmd == null) {
      return;
    }

    Matrix4 projection = new Matrix4.identity();
    setPerspectiveMatrix(projection, Math.PI * 60.0 / 180.0, this.aspect, 0.1, 1000.0);

    Matrix4 view = new Matrix4.identity();
    Vector3 look_from = new Vector3(0.0, 0.0, 25.0 + 25.0 * this.trackball.value);
    setViewMatrix(view, look_from, new Vector3(0.0, 0.0, 0.0), new Vector3(0.0, 1.0, 0.0));

    Matrix4 rh = new Matrix4.identity();
    rh.storage[10] = -1.0;

    Matrix4 rot = new Matrix4.identity();
    rot.setRotation(this.trackball.rotation.asRotationMatrix());

    Matrix4 normal = rot * rh;

    Matrix4 model = rot * rh;

    Matrix4 mvp = projection * view * model;

    if (this.uniforms.containsKey("mvp_matrix")) {
      gl.uniformMatrix4fv(this.uniforms["mvp_matrix"], false, mvp.storage);
    }

    if (this.uniforms.containsKey("normal_matrix")) {
      gl.uniformMatrix4fv(this.uniforms["normal_matrix"], false, normal.storage);
    }

    if (this.attributes.containsKey("normal")) {
      gl.bindBuffer(GL.ARRAY_BUFFER, this.normal_buffer.buffer);
      gl.vertexAttribPointer(this.attributes["normal"], 3, GL.FLOAT, false, 0, 0);
    }

    if (this.attributes.containsKey("position")) {
      gl.bindBuffer(GL.ARRAY_BUFFER, this.position_buffer.buffer);
      gl.vertexAttribPointer(this.attributes["position"], 3, GL.FLOAT, false, 0, 0);
    }

    if (this.attributes.containsKey("coord")) {
      gl.bindBuffer(GL.ARRAY_BUFFER, this.coord_buffer.buffer);
      gl.vertexAttribPointer(this.attributes["coord"], 2, GL.FLOAT, false, 0, 0);
    }

    gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);

    for (int i = 0; i < this.pmd.materials.length; i++) {
      var index_buffer = this.index_buffer_list[i];

      var material = this.pmd.materials[i];

      if (this.uniforms.containsKey("diffuse")) {
        var color = new Vector4.zero();
        color.rgb = material.diffuse;
        color.a = material.alpha;
        gl.uniform4fv(this.uniforms["diffuse"], color.storage);
      }

      if (this.uniforms.containsKey("texture")) {
        if(this.textures.containsKey(material.texture_file_name)) {
          gl.bindTexture(GL.TEXTURE_2D, this.textures[material.texture_file_name].texture);
        } else {
          gl.bindTexture(GL.TEXTURE_2D, this.white_texture.texture);
        }
        gl.uniform1i(this.uniforms["texture"], 0);
      }

      gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, index_buffer.buffer);
      gl.drawElements(GL.TRIANGLES, index_buffer.data.length, GL.UNSIGNED_SHORT, 0);
    }
  }
}
