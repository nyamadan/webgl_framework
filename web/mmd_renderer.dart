library mmd_renderer;

import 'dart:html';
import 'dart:typed_data';
import 'dart:async';
import 'dart:math' as Math;
import 'dart:web_gl' as GL;

import "package:webgl_framework/webgl_framework.dart";
import "package:vector_math/vector_math.dart";

import "sjis_to_string.dart";

part 'pmd_parser.dart';
part 'vmd_parser.dart';

class BoneNode {
  Vector3 bone_position = new Vector3.zero();

  Vector3 position = new Vector3.zero();
  Vector3 scale = new Vector3(1.0, 1.0, 1.0);
  Quaternion rotation = new Quaternion.identity();
  Matrix4 transform = new Matrix4.identity();

  List<BoneNode> children = new List<BoneNode>();

  void update({BoneNode parent : null, bool recursive : true}) {
    Matrix4 scale_matrix = new Matrix4.identity();
    scale_matrix.scale(this.scale);

    Matrix4 rotation_matrix = new Matrix4.identity();
    rotation_matrix.setRotation(this.rotation.asRotationMatrix());

    Matrix4 translate_matrix = new Matrix4.identity();
    translate_matrix.setTranslation(this.position + this.bone_position);

    this.transform = translate_matrix * rotation_matrix * scale_matrix;
    if(parent != null) {
      this.transform = parent.transform * this.transform;
    }

    if(recursive) {
      this.children.forEach((BoneNode bone) {
        bone.update(parent: this, recursive: true);
      });
    }
  }

  String toString() => ["{",[
    "bone_position : ${this.bone_position}",
    "position : ${this.position}",
    "scale : ${this.scale}",
    "rotation : ${this.rotation}",
    "transform : ${this.transform}",
    "children : ${this.children != null ? '...' : null}",
  ].join(", "),"}"].join("");
}

class MMD_Renderer extends WebGLRenderer {
  static const String VS =
  """
  attribute vec3 position;
  attribute vec3 normal;
  attribute vec3 bone;
  attribute vec2 coord;
  uniform mat4 model_matrix;
  uniform mat4 view_matrix;
  uniform mat4 projection_matrix;

  uniform sampler2D bone_texture;

  varying vec4 v_normal;
  varying vec2 v_coord;

  const vec2 half_bone = vec2(0.5 / 4.0, 0.5 / 256.0);

  mat4 getBoneMatrix(float bone_index) {
    return mat4(
      texture2D(bone_texture, vec2(
          0.0 * half_bone.x + half_bone.x,
          2.0 * bone_index * half_bone.y + half_bone.y
      )),
      texture2D(bone_texture, vec2(
          2.0 * half_bone.x + half_bone.x,
          2.0 * bone_index * half_bone.y + half_bone.y
      )),
      texture2D(bone_texture, vec2(
          4.0 * half_bone.x + half_bone.x,
          2.0 * bone_index * half_bone.y + half_bone.y
      )),
      texture2D(bone_texture, vec2(
          8.0 * half_bone.x + half_bone.x,
          2.0 * bone_index * half_bone.y + half_bone.y
      ))
    );
  }

  void main(void){
    mat4 bone1 = getBoneMatrix(bone.x);
    mat4 bone2 = getBoneMatrix(bone.y);
    mat4 m = bone1 * bone.z + bone2 * (1.0 - bone.z);
    vec4 p = m * vec4(position, 1.0);

    v_normal = vec4(normalize(mat3(model_matrix * m) * normal), 1.0);

    v_coord = coord;
    gl_Position = projection_matrix * view_matrix * model_matrix * p;
  }
  """;

  static const String FS =
  """
  precision mediump float;

  uniform vec4 diffuse;
  uniform sampler2D texture;

  varying vec4 v_normal;
  varying vec2 v_coord;

  void main(void){
    vec4 tex_color = texture2D(texture, v_coord);

    float d = clamp(dot(v_normal.xyz, vec3(0.0, 0.0, 1.0)), 0.0, 1.0);
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
  WebGLArrayBuffer bone_buffer;

  List<WebGLElementArrayBuffer> index_buffer_list;
  Map<String, WebGLCanvasTexture> textures;
  WebGLCanvasTexture white_texture;
  WebGLTypedDataTexture bone_texture;

  PMD_Model pmd;
  VMD_Animation vmd;

  List<BoneNode> bones;

  MMD_Renderer({int width: 512, int height: 512}) : super(width: width, height: height)
  {
    gl.getExtension("OES_texture_float");
    gl.getExtension("OES_texture_float_linear");

    var vs = this.compileVertexShader(VS);
    var fs = this.compileFragmentShader(FS);
    this.program = this.linkProgram(vs, fs);
    gl.deleteShader(vs);
    gl.deleteShader(fs);

    this.attributes = this.getAttributes(this.program, [
      "position",
      "normal",
      "coord",
      "bone",
    ]);

    this.uniforms = this.getUniformLocations(this.program, [
      "diffuse",
      "texture",
      "bone_texture",
      "mvp_matrix",
      "model_matrix",
      "view_matrix",
      "projection_matrix",
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

    if (this.attributes.containsKey("bone")) {
      gl.enableVertexAttribArray(this.attributes["bone"]);
    }

    this._loadPMD();
    this._loadVMD();
  }

  void _loadVMD() {
    (new VMD_Animation())
    .load("miku.vmd")
    .then((VMD_Animation vmd) {
      print(vmd);
    });
  }

  void _loadPMD() {
    (new PMD_Model())
    .load("miku.pmd")
    .then((PMD_Model pmd){
      pmd.setupSkinning();

      var position_list = pmd.createPositionList();
      var normal_list = pmd.createNormalList();
      var coord_list = pmd.createCoordList();
      var bone_buffer = pmd.createBoneList();

      this.position_buffer = new WebGLArrayBuffer(gl, position_list);
      this.normal_buffer = new WebGLArrayBuffer(gl, normal_list);
      this.coord_buffer = new WebGLArrayBuffer(gl, coord_list);
      this.bone_buffer = new WebGLArrayBuffer(gl, bone_buffer);

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

      Float32List bone_data = new Float32List(4 * 256 * 4);
      this._createBones(pmd.bones);
      this.bone_texture = new WebGLTypedDataTexture(gl, bone_data, width : 4, height : 256, type : GL.FLOAT);
      this.pmd = pmd;
    });
  }

  void _createBones(List<PMD_Bone> pmd_bones) {
    this.bones = new List<BoneNode>.generate(pmd_bones.length, (int i) => new BoneNode() );
    for(int i = 0; i < pmd_bones.length; i++) {
      PMD_Bone pmd_bone = pmd_bones[i];
      BoneNode bone = bones[i];

      if(pmd_bone.parent_bone_index >= 0) {
        PMD_Bone parent_pmd_bone = pmd_bones[pmd_bone.parent_bone_index];
        bone.bone_position = pmd_bone.bone_head_pos - parent_pmd_bone.bone_head_pos;
      } else {
        bone.bone_position = new Vector3.copy(pmd_bone.bone_head_pos);
      }

      for(int j = 0; j < pmd_bones.length; j++) {
        if(pmd_bones[j].parent_bone_index == i) {
          bone.children.add(bones[j]);
        }
      }
    }
  }

  void _calcBone(List<BoneNode> bones, Float32List bone_data) {
    bones.first.update();

    for(int i = 0; i < bones.length; i++) {
      BoneNode bone = bones[i];
      int offset = i * 16;
      bone_data.setRange(offset, offset + 16, bone.transform.storage);
    }
  }

  void _refreshBoneTexture() {
    this.bone_texture.refresh(gl);
  }

  void render(double ms) {
    if (this.pmd == null) {
      return;
    }

    Matrix4 projection = new Matrix4.identity();
    setPerspectiveMatrix(projection, Math.PI * 60.0 / 180.0, this.aspect, 0.1, 1000.0);

    Matrix4 view = new Matrix4.identity();
    Vector3 look_from = new Vector3(0.0, 0.0, 5.0 + 45.0 * this.trackball.value);
    setViewMatrix(view, look_from, new Vector3(0.0, 0.0, 0.0), new Vector3(0.0, 1.0, 0.0));

    Matrix4 rh = new Matrix4.identity();
    rh.storage[10] = -1.0;

    Matrix4 rot = new Matrix4.identity();
    rot.setRotation(this.trackball.rotation.asRotationMatrix());

    Matrix4 model = rot * rh;

    Matrix4 mvp = projection * view * model;

    if (this.uniforms.containsKey("mvp_matrix")) {
      gl.uniformMatrix4fv(this.uniforms["mvp_matrix"], false, mvp.storage);
    }

    if (this.uniforms.containsKey("model_matrix")) {
      gl.uniformMatrix4fv(this.uniforms["model_matrix"], false, model.storage);
    }

    if (this.uniforms.containsKey("view_matrix")) {
      gl.uniformMatrix4fv(this.uniforms["view_matrix"], false, view.storage);
    }

    if (this.uniforms.containsKey("projection_matrix")) {
      gl.uniformMatrix4fv(this.uniforms["projection_matrix"], false, projection.storage);
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

    if (this.attributes.containsKey("bone")) {
      gl.bindBuffer(GL.ARRAY_BUFFER, this.bone_buffer.buffer);
      gl.vertexAttribPointer(this.attributes["bone"], 3, GL.FLOAT, false, 0, 0);
    }

    this._calcBone(this.bones, this.bone_texture.data);
    this._refreshBoneTexture();

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
        gl.activeTexture(GL.TEXTURE0);
        GL.Texture texture;
        if(this.textures.containsKey(material.texture_file_name)) {
          texture = this.textures[material.texture_file_name].texture;
        } else {
          texture = this.white_texture.texture;
        }
        gl.bindTexture(GL.TEXTURE_2D, texture);
        gl.uniform1i(this.uniforms["texture"], 0);
      }

      if (this.uniforms.containsKey("bone_texture")) {
        gl.activeTexture(GL.TEXTURE1);
        gl.bindTexture(GL.TEXTURE_2D, this.bone_texture.texture);
        gl.uniform1i(this.uniforms["bone_texture"], 1);
      }

      gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, index_buffer.buffer);
      gl.drawElements(GL.TRIANGLES, index_buffer.data.length, GL.UNSIGNED_SHORT, 0);
    }
  }
}
