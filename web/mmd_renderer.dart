library mmd_renderer;

import 'dart:html';
import 'dart:typed_data';
import 'dart:async';
import 'dart:math' as Math;
import 'dart:web_gl' as GL;

import "package:webgl_framework/webgl_framework.dart";
import "package:vector_math/vector_math.dart";
import "package:logging/logging.dart";

import "sjis_to_string.dart";

part 'pmd_parser.dart';
part 'vmd_parser.dart';

class BoneNode {
  String name;
  int bone_type = 0;
  Vector3 original_bone_position = new Vector3.zero();
  Vector3 relative_bone_position = new Vector3.zero();
  Vector3 absolute_bone_position = new Vector3.zero();

  Vector3 position = new Vector3.zero();
  Vector3 scale = new Vector3(1.0, 1.0, 1.0);
  Quaternion rotation = new Quaternion.identity();
  Quaternion absolute_rotation = new Quaternion.identity();

  Matrix4 absolute_transform = new Matrix4.identity();
  Matrix4 relative_transform = new Matrix4.identity();

  BoneNode parent = null;
  List<BoneNode> children = new List<BoneNode>();

  void applyVMD(VMD_Animation vmd, int frame) {
    List<VMD_BoneMotion> motions = vmd.getFrame(this.name, frame);
    if(motions != null) {
      VMD_BoneMotion prev_frame = motions[0];
      VMD_BoneMotion next_frame = motions[1];

      if(prev_frame == null && next_frame != null) {
        next_frame.rotation.copyTo(this.rotation);
        next_frame.location.copyInto(this.position);
      } else if(prev_frame != null && next_frame == null) {
        prev_frame.rotation.copyTo(this.rotation);
        prev_frame.location.copyInto(this.position);
      } else {
        double blend = (frame - prev_frame.frame) / (next_frame.frame - prev_frame.frame);

        slerpQuaternion(prev_frame.rotation, next_frame.rotation, blend).copyTo(this.rotation);
        (next_frame.location * blend + prev_frame.location * (1.0 - blend)).copyInto(this.position);
      }
    }
  }

  void update({bool recursive : true}) {
    Matrix4 scale_matrix = new Matrix4.identity();
    scale_matrix.scale(this.scale);

    Matrix4 rotation_matrix = new Matrix4.identity();
    rotation_matrix.setRotation(this.rotation.asRotationMatrix());

    Matrix4 translate_matrix = new Matrix4.identity();
    translate_matrix.setTranslation(this.position);

    this.relative_transform = translate_matrix * rotation_matrix * scale_matrix;
    if(this.parent != null) {
      this.relative_transform = this.parent.relative_transform * this.relative_transform;
    }

    Matrix4 bone_translate_matrix = new Matrix4.identity();
    bone_translate_matrix.setTranslation(this.relative_bone_position);

    this.absolute_transform = bone_translate_matrix * translate_matrix * rotation_matrix * scale_matrix;
    this.absolute_rotation = new Quaternion.copy(this.rotation);
    if(this.parent != null) {
      this.absolute_transform = this.parent.absolute_transform * this.absolute_transform;
      this.absolute_rotation = this.parent.absolute_rotation * this.absolute_rotation;
    }

    this.absolute_bone_position = new Vector3.copy(this.absolute_transform.getColumn(3).xyz);

    if(recursive) {
      this.children.forEach((BoneNode bone) {
        bone.update(recursive: true);
      });
    }
  }

  String toString() => ["{",[
    "name : ${this.name}",
    "bone_type : ${this.bone_type}",
    "relative_bone_position : ${this.relative_bone_position}",
    "transformed_bone_position : ${this.absolute_bone_position}",
    "original_bone_position : ${this.original_bone_position}",
    "position : ${this.position}",
    "scale : ${this.scale}",
    "rotation : ${this.rotation}",
    "absolute_transform : ${this.absolute_transform}",
    "relative_transform : ${this.relative_transform}",
    "children : ${this.children != null ? '...' : null}",
  ].join(", "),"}"].join("");
}

class MMD_Renderer extends WebGLRenderer {
  final Logger log = new Logger("MMD_Renderer");

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

  const vec2 half_bone = vec2(0.5 / 8.0, 0.5 / 512.0);

  mat4 getTransformMatrix(float bone_index) {
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
          6.0 * half_bone.x + half_bone.x,
          2.0 * bone_index * half_bone.y + half_bone.y
      ))
    );
  }

  vec4 getBonePosition(float bone_index) {
    return texture2D(bone_texture, vec2(
        8.0 * half_bone.x + half_bone.x,
        2.0 * bone_index * half_bone.y + half_bone.y
    ));
  }

  vec4 getTransformedBonePosition(float bone_index) {
    return texture2D(bone_texture, vec2(
        10.0 * half_bone.x + half_bone.x,
        2.0 * bone_index * half_bone.y + half_bone.y
    ));
  }

  void main(void){
    float weight = bone.z;
    mat4 transform1 = getTransformMatrix(bone.x);
    mat4 transform2 = getTransformMatrix(bone.y);

    vec4 bone1 = getBonePosition(bone.x);
    vec4 bone2 = getBonePosition(bone.y);

    vec4 transformed_bone1 = getTransformedBonePosition(bone.x);
    vec4 transformed_bone2 = getTransformedBonePosition(bone.y);

    vec4 v1 = vec4(position, 1.0) - bone1;
    vec4 v2 = vec4(position, 1.0) - bone2;

    vec4 p1 = (transform1 * v1) + transformed_bone1;
    vec4 p2 = (transform2 * v2) + transformed_bone2;

    mat4 m = transform1 * weight + transform2 * (1.0 - weight);
    v_normal = vec4(normalize(mat3(model_matrix * m) * normal), 1.0);

    v_coord = coord;
    gl_Position = projection_matrix * view_matrix * model_matrix * mix(p2, p1, weight);
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

  DebugParticleShader debug_particle_shader;
  DebugAxisShader debug_axis_shader;

  int frame;
  double start;

  void _initialize() {
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

    this.debug_particle_shader = new DebugParticleShader(this.dom.width, this.dom.height);

    this.trackball.value = 1.0;

    this.debug_particle_shader = new DebugParticleShader.copy(this);
    this.debug_axis_shader = new DebugAxisShader.copy(this);

    this._loadPMD();
    this._loadVMD();
  }

  MMD_Renderer(int width, int height)
  {
    this.initContext(width, height);
    this.initTrackball();

    this._initialize();
  }

  MMD_Renderer.from(WebGLRenderer src)
  {
    this.gl = gl;
    this.dom = src.dom;

    this._initialize();
  }

  void _loadVMD() {
    (new VMD_Animation())
    .load("miku.vmd")
    .then((VMD_Animation vmd) {
      this.vmd = vmd;
    });
  }

  void _loadPMD() {
    (new PMD_Model())
    .load("miku.pmd")
    .then((PMD_Model pmd){
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

      Float32List bone_data = new Float32List(8 * 512 * 4);
      this._createBoneNodes(pmd.bones);
      this.bone_texture = new WebGLTypedDataTexture(gl, bone_data, width : 8, height : 512, type : GL.FLOAT);
      this.pmd = pmd;
    });
  }

  void _createBoneNodes(List<PMD_Bone> pmd_bones) {
    this.bones = new List<BoneNode>.generate(pmd_bones.length, (int i){
      BoneNode bone = new BoneNode();
      PMD_Bone pmd_bone = pmd_bones[i];

      bone.name = pmd_bone.name;
      bone.bone_type = pmd_bone.bone_type;
      bone.original_bone_position = new Vector3.copy(pmd_bone.bone_head_pos);

      if(pmd_bone.parent_bone_index >= 0) {
        PMD_Bone parent_pmd_bone = pmd_bones[pmd_bone.parent_bone_index];
        bone.relative_bone_position = pmd_bone.bone_head_pos - parent_pmd_bone.bone_head_pos;
      } else {
        bone.relative_bone_position = new Vector3.copy(pmd_bone.bone_head_pos);
      }
      return bone;
    });

    for(int i = 0; i < pmd_bones.length; i++) {
      PMD_Bone pmd_bone = pmd_bones[i];
      BoneNode bone = this.bones[i];

      if(0 <= pmd_bone.parent_bone_index  && pmd_bone.parent_bone_index < pmd_bones.length) {
        bone.parent = this.bones[pmd_bone.parent_bone_index];
      }

      for(int j = 0; j < pmd_bones.length; j++) {
        if(pmd_bones[j].parent_bone_index == i) {
          bone.children.add(bones[j]);
        }
      }
    }
  }

  void _writeBoneTexture(List<BoneNode> bones, Float32List bone_data) {
    for(int i = 0; i < bones.length; i++) {
      BoneNode bone = bones[i];
      int offset = i * 32;

      bone_data.setRange(offset, offset + 16, bone.relative_transform.storage); offset += 16;

      bone_data.setRange(offset, offset + 3, bone.original_bone_position.storage); offset += 3;
      bone_data[offset] = 1.0; offset += 1;

      bone_data.setRange(offset, offset + 3, bone.absolute_bone_position.storage); offset += 3;
      bone_data[offset] = 1.0; offset += 1;
    }
  }

  void _updateChildIK(List<BoneNode> child_bones, int child_bone_index, List<BoneNode> bones, PMD_IK ik) {
    BoneNode child_bone = child_bones[child_bone_index];
    BoneNode ik_bone_node = bones[ik.bone_index];
    BoneNode target_bone_node = bones[ik.target_bone_index];

    Vector3 target_position = target_bone_node.absolute_bone_position;
    Vector3 ik_position = ik_bone_node.absolute_bone_position;
    if(target_position.distanceToSquared(ik_position) < 0.001) {
      return;
    }

    Vector3 v1 = child_bone.absolute_rotation.rotated(target_position - child_bone.absolute_bone_position);
    Vector3 v2 = child_bone.absolute_rotation.rotated(ik_position - child_bone.absolute_bone_position);

    num theta = Math.acos(Math.min(Math.max(v1.dot(v2) / (v1.length * v2.length), -1.0), 1.0));
    if(theta.abs() < 0.001) {
      return;
    }

    Vector3 axis = v1.cross(v2).normalize();
    Quaternion q = new Quaternion.identity();
    q.setAxisAngle(axis, theta * ik.control_weight);
    child_bone.rotation.copyFrom(child_bone.rotation * q);

    if(child_bone.name == "左ひざ") {
      Quaternion q = new Quaternion.identity();
      //child_bone.rotation.copyFrom(q);
    }

    if(child_bone.name == "右ひざ") {
      Quaternion q = new Quaternion.identity();
      //child_bone.rotation.copyFrom(q);
    }

    child_bone.update();
  }

  void _updateIK(List<BoneNode> bones, PMD_IK ik) {
    List<BoneNode> child_bones = ik.child_bones.map((int i) => bones[i]).toList();
    for(int i = 0; i < ik.iterations; i++) {
      BoneNode ik_bone_node = bones[ik.bone_index];
      BoneNode target_bone_node = bones[ik.target_bone_index];

      for(int j = 0; j < child_bones.length; j++) {
        this._updateChildIK(child_bones, j, bones, ik);
      }
    }
  }

  void _updateBoneAnimation(List<BoneNode> bones, List<PMD_IK> iks, VMD_Animation vmd, int frame, Float32List bone_data) {
    bones.forEach((BoneNode bone) => bone.applyVMD(vmd, frame));

    //bones[69].rotation.setAxisAngle(new Vector3(1.0, 0.0, 0.0), 1.0);
    bones.where((BoneNode bone) => bone.parent == null).forEach((BoneNode bone) => bone.update());

    iks.forEach((ik) => this._updateIK(bones, ik));

    //debug output
    bones.forEach((bone){
      var particle = new DebugVertex(bone.absolute_bone_position);
      if(bone.bone_type == 2) {
        particle.point_size = 5.0;
        particle.color = new Vector4(1.0, 0.0, 0.0, 1.0);
      }

      if(bone.bone_type == 4) {
        particle.color = new Vector4(1.0, 0.0, 0.0, 1.0);
      }
      this.debug_particle_shader.vertices.add(particle);
    });

    this._writeBoneTexture(bones, bone_data);
  }

  void _refreshBoneTexture() {
    this.bone_texture.refresh(gl);
  }

  void render(double elapsed) {
    this.debug_particle_shader.vertices = new List<DebugVertex>();
    this.debug_axis_shader.axises = new List<DebugAxis>();

    if (this.pmd == null || this.vmd == null) {
      return;
    }

    if(this.start == null) {
      this.start = elapsed;
    }

    this.frame = ((elapsed - start) / 30.0).round() % 750;

    Matrix4 projection = new Matrix4.identity();
    setPerspectiveMatrix(projection, Math.PI * 60.0 / 180.0, this.aspect, 0.1, 1000.0);

    Matrix4 view = new Matrix4.identity();
    Vector3 look_from = new Vector3(0.0, 0.0, 5.0 + 45.0 * this.trackball.value);
    setViewMatrix(view, look_from, new Vector3(0.0, 0.0, 0.0), new Vector3(0.0, 1.0, 0.0));

    Matrix4 rot = new Matrix4.identity();
    rot.setRotation(this.trackball.rotation.asRotationMatrix());

    Matrix4 model = rot;
    Matrix4 mvp = projection * view * model;

    gl.enable(GL.DEPTH_TEST);
    gl.depthFunc(GL.LEQUAL);

    gl.enable(GL.CULL_FACE);
    gl.frontFace(GL.CCW);

    gl.clearColor(0.5, 0.5, 0.5, 1.0);

    gl.useProgram(this.program);

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
      gl.enableVertexAttribArray(this.attributes["normal"]);
      gl.bindBuffer(GL.ARRAY_BUFFER, this.normal_buffer.buffer);
      gl.vertexAttribPointer(this.attributes["normal"], 3, GL.FLOAT, false, 0, 0);
    }

    if (this.attributes.containsKey("position")) {
      gl.enableVertexAttribArray(this.attributes["position"]);
      gl.bindBuffer(GL.ARRAY_BUFFER, this.position_buffer.buffer);
      gl.vertexAttribPointer(this.attributes["position"], 3, GL.FLOAT, false, 0, 0);
    }

    if (this.attributes.containsKey("coord")) {
      gl.enableVertexAttribArray(this.attributes["coord"]);
      gl.bindBuffer(GL.ARRAY_BUFFER, this.coord_buffer.buffer);
      gl.vertexAttribPointer(this.attributes["coord"], 2, GL.FLOAT, false, 0, 0);
    }

    if (this.attributes.containsKey("bone")) {
      gl.enableVertexAttribArray(this.attributes["bone"]);
      gl.bindBuffer(GL.ARRAY_BUFFER, this.bone_buffer.buffer);
      gl.vertexAttribPointer(this.attributes["bone"], 3, GL.FLOAT, false, 0, 0);
    }

    this._updateBoneAnimation(this.bones, this.pmd.iks, this.vmd, this.frame, this.bone_texture.data);
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

    mvp.copyInto(this.debug_axis_shader.mvp);
    this.debug_axis_shader.render(elapsed);
    mvp.copyInto(this.debug_particle_shader.mvp);
    this.debug_particle_shader.render(elapsed);
  }
}
