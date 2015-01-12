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
import "copy_renderer.dart";

part 'pmd_parser.dart';
part 'pmx_parser.dart';
part 'vmd_parser.dart';
part 'pmd_main_shader.dart';
part 'pmd_edge_shader.dart';

part 'pmd_geometry_renderer.dart';
part 'pmd_deferred_aa_renderer.dart';

part 'motion_manager.dart';

class MMD_Material {
  Vector4 diffuse;
  double shiness;
  Vector3 specular;
  Vector3 ambient;

  int toon_index;

  String toon_texture_file_name;
  String texture_file_name;

  bool edge;

  int face_vert_count;
}

class MMD_Mesh {
  WebGLArrayBuffer32 position_buffer;
  WebGLArrayBuffer32 normal_buffer;
  WebGLArrayBuffer32 coord_buffer;
  WebGLArrayBuffer32 bone_buffer;
  WebGLArrayBuffer32 edge_buffer;

  List<WebGLBuffer> index_buffer_list;

  Map<String, WebGLCanvasTexture> textures;
  List<WebGLCanvasTexture> toon_textures;
  WebGLCanvasTexture white_texture;
  WebGLCanvasTexture diffuse_texture;
  WebGLTypedDataTexture bone_texture;

  List<BoneNode> bones;
  List<MMD_Material> materials;
}

class MMD_Renderer extends WebGLRenderer {
  final Logger log = new Logger("MMD_Renderer");

  bool enable_edge_shader = true;
  bool enable_deferred_shader = true;
  bool enable_sraa = false;
  bool play = true;

  WebGLFBO fbo;

  List<WebGLCanvasTexture> toon_textures;
  WebGLCanvasTexture white_texture;
  WebGLCanvasTexture diffuse_texture;

  PMD_Model pmd;
  PMX_Model pmx;
  VMD_Animation vmd;

  MMD_Mesh mesh;

  DebugParticleShader debug_particle_shader;
  DebugAxisShader debug_axis_shader;
  CopyRenderer copy_renderer;
  PMD_MainShader main_shader;
  PMD_EdgeShader edge_shader;

  PMD_GeometryRenderer geometry_renderer;
  PMD_DeferredAaRenderer deferred_aa_renderer;

  int frame;
  double start;

  void _initialize() {
    gl.getExtension("OES_texture_float");
    gl.getExtension("OES_texture_float_linear");
    gl.getExtension("OES_element_index_uint");
    gl.getExtension("WEBGL_depth_texture");

    this.debug_particle_shader = new DebugParticleShader(this.dom.width, this.dom.height);

    this.trackball.value = 1.0;

    this.debug_particle_shader = new DebugParticleShader.copy(this);
    this.debug_axis_shader = new DebugAxisShader.copy(this);

    this.main_shader = new PMD_MainShader.copy(this);
    this.edge_shader = new PMD_EdgeShader.copy(this);
    this.copy_renderer = new CopyRenderer.copy(this);

    if (this.enable_deferred_shader) {
      GL.DrawBuffers glext = gl.getExtension("WEBGL_draw_buffers");
      this.geometry_renderer = new PMD_GeometryRenderer.copy(this, glext);
      this.deferred_aa_renderer = new PMD_DeferredAaRenderer.copy(this);
    }

    this.fbo = new WebGLFBO(gl, width: this.dom.width, height: this.dom.height, depth_buffer_enabled: true);
    this.white_texture = new WebGLCanvasTexture(gl, width: 16, height: 16, color: new Vector4(1.0, 1.0, 1.0, 1.0));
    this.diffuse_texture = new WebGLCanvasTexture(gl, flip_y: true, width: 16, height: 16);
    CanvasRenderingContext2D ctx = this.diffuse_texture.ctx;
    var image_data = ctx.getImageData(0, 0, 16, 16);
    for (int y = 0; y < 16; y++) {
      int color = 255 - (y * 255 / 15).round();
      for (int x = 0; x < 16; x++) {
        int offset = (y * 16 + x) * 4;
        image_data.data[offset + 0] = color;
        image_data.data[offset + 1] = color;
        image_data.data[offset + 2] = color;
        image_data.data[offset + 3] = 0xff;
      }
    }
    ctx.putImageData(image_data, 0, 0);
    this.diffuse_texture.refresh(gl);

    this.toon_textures = new List<WebGLCanvasTexture>.generate(10, (int i) {
      var texture = new WebGLCanvasTexture(gl, flip_y: true, color: new Vector4(1.0, 1.0, 1.0, 1.0));
      texture.load(gl, "toon/toon${(i + 1).toString().padLeft(2, '0')}.bmp");
      return texture;
    });

    String model_file = "model/夕立改二（B式）1.01.pmx";
    //String model_file = "model/miku.pmd";
    String motion_file = "motion/kishimen.vmd";

    this._loadMesh(model_file);
    this._loadVMD(motion_file);
  }

  MMD_Renderer(int width, int height) {
    this.initContext(width, height);
    this.initTrackball();

    this._initialize();
  }

  MMD_Renderer.from(WebGLRenderer src) {
    this.gl = gl;
    this.dom = src.dom;

    this._initialize();
  }

  Future<MMD_Mesh> _loadMesh(String filename) {
    RegExp re_pmd = new RegExp(r"\.pmd$", caseSensitive: false);
    if (re_pmd.hasMatch(filename)) {
      return this._loadPMD(filename).then((PMD_Model pmd) {
        return new Future.value(this.mesh);
      });
    }

    RegExp re_pmx = new RegExp(r"\.pmx$", caseSensitive: false);
    if (re_pmx.hasMatch(filename)) {
      return this._loadPMX(filename).then((PMX_Model pmx) {
        return new Future.value(this.mesh);
      });
    }

    return new Future.error(new Exception("Unknown file type: $filename"));
  }

  Future<VMD_Animation> _loadVMD(String filename) {
    return (new VMD_Animation()).load(filename).then((VMD_Animation vmd) {
      this.vmd = vmd;

      return new Future.value(vmd);
    });
  }

  Future<PMD_Model> _loadPMD(String filename) {
    return (new PMD_Model()).load(filename).then((PMD_Model pmd) {
      var position_list = pmd.createPositionList();
      var normal_list = pmd.createNormalList();
      var coord_list = pmd.createCoordList();
      var bone_buffer = pmd.createBoneList();
      var edge_buffer = pmd.createEdgeList();

      MMD_Mesh mesh = new MMD_Mesh();

      mesh.position_buffer = new WebGLArrayBuffer32(gl, position_list);
      mesh.edge_buffer = new WebGLArrayBuffer32(gl, edge_buffer);
      mesh.normal_buffer = new WebGLArrayBuffer32(gl, normal_list);
      mesh.coord_buffer = new WebGLArrayBuffer32(gl, coord_list);
      mesh.bone_buffer = new WebGLArrayBuffer32(gl, bone_buffer);

      mesh.textures = new Map<String, WebGLCanvasTexture>();
      mesh.materials = new List<MMD_Material>.generate(pmd.materials.length, (int i) {
        PMD_Material pmd_material = pmd.materials[i];
        MMD_Material material = new MMD_Material();

        material.ambient = new Vector3.copy(pmd_material.ambient);
        material.diffuse = new Vector4.copy(pmd_material.diffuse);
        material.toon_index = pmd_material.toon_index;
        material.edge = pmd_material.edge_flag != 0 ? true : false;
        material.face_vert_count = pmd_material.face_vert_count;
        material.shiness = pmd_material.shiness;
        material.specular = new Vector3.copy(pmd_material.specular);
        material.texture_file_name = pmd_material.texture_file_name;

        if (material.texture_file_name != null &&
            material.texture_file_name.isNotEmpty &&
            !mesh.textures.containsKey(material.texture_file_name)) {
          var texture = new WebGLCanvasTexture(gl);
          texture.load(gl, "model/${material.texture_file_name}");
          mesh.textures[material.texture_file_name] = texture;
        }

        return material;
      });

      mesh.index_buffer_list = new List<WebGLElementArrayBuffer16>.generate(
          mesh.materials.length,
          (int i) => new WebGLElementArrayBuffer16(gl, pmd.createTriangleList(i)));

      Float32List bone_data = new Float32List(8 * 512 * 4);
      mesh.bones = this._createBoneNodesFromPMD(pmd.bones);
      mesh.bone_texture = new WebGLTypedDataTexture(gl, bone_data, width: 8, height: 512, type: GL.FLOAT);

      mesh.toon_textures = this.toon_textures;
      mesh.diffuse_texture = this.diffuse_texture;
      mesh.white_texture = this.white_texture;

      this.mesh = mesh;
      this.pmd = pmd;
      return new Future.value(this.pmd);
    });
  }

  Future<PMX_Model> _loadPMX(String filename) {
    return (new PMX_Model()).load(filename).then((PMX_Model pmx) {
      var position_list = pmx.createPositionList();
      var normal_list = pmx.createNormalList();
      var coord_list = pmx.createCoordList();
      var bone_buffer = pmx.createBoneList();
      var edge_buffer = pmx.createEdgeList();

      MMD_Mesh mesh = new MMD_Mesh();
      mesh.position_buffer = new WebGLArrayBuffer32(gl, position_list);
      mesh.edge_buffer = new WebGLArrayBuffer32(gl, edge_buffer);
      mesh.normal_buffer = new WebGLArrayBuffer32(gl, normal_list);
      mesh.coord_buffer = new WebGLArrayBuffer32(gl, coord_list);
      mesh.bone_buffer = new WebGLArrayBuffer32(gl, bone_buffer);

      mesh.textures = new Map<String, WebGLCanvasTexture>();

      pmx.textures.forEach((String file_name) {
        var texture = new WebGLCanvasTexture(gl, color: new Vector4(1.0, 1.0, 1.0, 1.0));
        texture.load(gl, "model/$file_name");
        mesh.textures[file_name] = texture;
      });

      mesh.materials = new List<MMD_Material>.generate(pmx.materials.length, (int i) {
        PMX_Material pmx_material = pmx.materials[i];
        MMD_Material material = new MMD_Material();
        material.face_vert_count = pmx_material.face_vert_count;
        material.ambient = new Vector3.copy(pmx_material.ambient);
        material.diffuse = new Vector4.copy(pmx_material.diffuse);
        material.specular = new Vector3.copy(pmx_material.specular);
        material.shiness = pmx_material.shiness;

        if (pmx_material.toon_index != null && pmx_material.toon_index >= 0) {
          switch (pmx_material.toon_mode) {
            case 0:
              material.toon_texture_file_name = pmx.textures[pmx_material.toon_index];
              break;
            case 1:
              material.toon_index = pmx_material.toon_index;
              break;
          }
        }

        if (pmx_material.texture_index != null && pmx_material.texture_index >= 0) {
          material.texture_file_name = pmx.textures[pmx_material.texture_index];
        }

        material.edge = pmx_material.edge;

        return material;
      });

      if (pmx.vertex_index_size == 1) {
        mesh.index_buffer_list = new List<WebGLElementArrayBuffer8>.generate(
            mesh.materials.length,
            (int i) => new WebGLElementArrayBuffer8(gl, pmx.createTriangleList(i)));
      } else if (pmx.vertex_index_size == 2) {
        mesh.index_buffer_list = new List<WebGLElementArrayBuffer16>.generate(
            mesh.materials.length,
            (int i) => new WebGLElementArrayBuffer16(gl, pmx.createTriangleList(i)));
      } else if (pmx.vertex_index_size == 4) {
        mesh.index_buffer_list = new List<WebGLElementArrayBuffer32>.generate(
            mesh.materials.length,
            (int i) => new WebGLElementArrayBuffer32(gl, pmx.createTriangleList(i)));
      }

      Float32List bone_data = new Float32List(8 * 512 * 4);
      mesh.bones = this._createBoneNodesFromPMX(pmx.bones);
      mesh.bone_texture = new WebGLTypedDataTexture(gl, bone_data, width: 8, height: 512, type: GL.FLOAT);

      mesh.toon_textures = this.toon_textures;
      mesh.diffuse_texture = this.diffuse_texture;
      mesh.white_texture = this.white_texture;

      this.mesh = mesh;
      this.pmx = pmx;

      return new Future.value(this.pmx);
    });
  }

  List<BoneNode> _createBoneNodesFromPMX(List<PMX_Bone> pmx_bones) {
    List<BoneNode> bone_nodes = new List<BoneNode>.generate(pmx_bones.length, (int i) {
      BoneNode bone = new BoneNode();
      PMX_Bone pmx_bone = pmx_bones[i];

      bone.name = pmx_bone.name;
      bone.original_bone_position = new Vector3.copy(pmx_bone.bone_head_pos);
      bone.ik_iterations = pmx_bone.iterations;
      bone.max_angle = pmx_bone.max_angle;
      if (pmx_bone.parent_bone_index >= 0) {
        PMX_Bone parent_pmd_bone = pmx_bones[pmx_bone.parent_bone_index];
        bone.relative_bone_position = pmx_bone.bone_head_pos - parent_pmd_bone.bone_head_pos;
      } else {
        bone.relative_bone_position = new Vector3.copy(pmx_bone.bone_head_pos);
      }
      return bone;
    });

    for (int i = 0; i < pmx_bones.length; i++) {
      PMX_Bone pmx_bone = pmx_bones[i];
      BoneNode bone = bone_nodes[i];

      if (pmx_bone.iks != null && pmx_bone.iks.isNotEmpty) {
        bone.iks = pmx_bone.iks.map((PMX_IK pmx_ik) {
          MMD_IK ik = new MMD_IK();
          ik.bone = bone_nodes[pmx_ik.bone_index];
          if (pmx_ik.max != null) {
            ik.max = pmx_ik.max.clone();
          }
          if (pmx_ik.min != null) {
            ik.min = pmx_ik.min.clone();
          }
          return ik;
        }).toList();
      }

      if (pmx_bone.ik_target_bone_index != null &&
          0 <= pmx_bone.ik_target_bone_index &&
          pmx_bone.ik_target_bone_index < pmx_bones.length) {
        bone.ik_target_bone = bone_nodes[pmx_bone.ik_target_bone_index];
      }

      if (pmx_bone.parent_bone_index != null &&
          0 <= pmx_bone.parent_bone_index &&
          pmx_bone.parent_bone_index < pmx_bones.length) {
        bone.parent = bone_nodes[pmx_bone.parent_bone_index];
      }

      if (pmx_bone.ik_parent_transform_bone_index != null &&
          0 <= pmx_bone.ik_parent_transform_bone_index &&
          pmx_bone.ik_parent_transform_bone_index < pmx_bones.length) {
        bone.ik_parent_transform = bone_nodes[pmx_bone.ik_parent_transform_bone_index];
        bone.ik_parent_transform_weight = pmx_bone.ik_parent_transform_bone_weight;
      }

      for (int j = 0; j < pmx_bones.length; j++) {
        if (pmx_bones[j].parent_bone_index == i) {
          bone.children.add(bone_nodes[j]);
        }
      }
    }

    return bone_nodes;
  }

  List<BoneNode> _createBoneNodesFromPMD(List<PMD_Bone> pmd_bones) {
    List<BoneNode> bone_nodes = new List<BoneNode>.generate(pmd_bones.length, (int i) {
      BoneNode bone = new BoneNode();
      PMD_Bone pmd_bone = pmd_bones[i];

      bone.name = pmd_bone.name;
      bone.bone_type = pmd_bone.bone_type;
      bone.original_bone_position = new Vector3.copy(pmd_bone.bone_head_pos);

      if (pmd_bone.parent_bone_index >= 0) {
        PMD_Bone parent_pmd_bone = pmd_bones[pmd_bone.parent_bone_index];
        bone.relative_bone_position = pmd_bone.bone_head_pos - parent_pmd_bone.bone_head_pos;
      } else {
        bone.relative_bone_position = new Vector3.copy(pmd_bone.bone_head_pos);
      }
      return bone;
    });

    for (int i = 0; i < pmd_bones.length; i++) {
      PMD_Bone pmd_bone = pmd_bones[i];
      BoneNode bone = bone_nodes[i];

      if (0 <= pmd_bone.parent_bone_index && pmd_bone.parent_bone_index < pmd_bones.length) {
        bone.parent = bone_nodes[pmd_bone.parent_bone_index];
      }

      for (int j = 0; j < pmd_bones.length; j++) {
        if (pmd_bones[j].parent_bone_index == i) {
          bone.children.add(bone_nodes[j]);
        }
      }
    }

    return bone_nodes;
  }

  void _writeBoneTexture(List<BoneNode> bones, Float32List bone_data) {
    for (int i = 0; i < bones.length; i++) {
      BoneNode bone = bones[i];
      int offset = i * 32;

      bone_data.setRange(offset, offset + 16, bone.relative_transform.storage);
      offset += 16;

      bone_data.setRange(offset, offset + 3, bone.original_bone_position.storage);
      offset += 3;
      bone_data[offset] = 1.0;
      offset += 1;

      bone_data.setRange(offset, offset + 3, bone.absolute_bone_position.storage);
      offset += 3;
      bone_data[offset] = 1.0;
      offset += 1;
    }
  }

  void _updateChildPMDIK(BoneNode child_bone, List<BoneNode> bones, PMD_IK ik) {
    BoneNode ik_bone_node = bones[ik.bone_index];
    BoneNode target_bone_node = bones[ik.target_bone_index];

    Vector3 target_position = target_bone_node.absolute_bone_position;
    Vector3 ik_position = ik_bone_node.absolute_bone_position;
    if (target_position.distanceToSquared(ik_position) < 0.01) {
      return;
    }

    Vector3 v1 = child_bone.absolute_rotation.rotated(target_position - child_bone.absolute_bone_position);
    Vector3 v2 = child_bone.absolute_rotation.rotated(ik_position - child_bone.absolute_bone_position);

    num theta = Math.acos(Math.min(Math.max(v1.dot(v2) / (v1.length * v2.length), -1.0), 1.0));

    Vector3 axis = v1.cross(v2).normalize();

    if (child_bone.name == "左ひざ" || child_bone.name == "右ひざ") {
      Quaternion q = new Quaternion.identity();
      q.setAxisAngle(axis, Math.min(theta, ik.max_angle * 4.0));

      var theta_x = Math.asin(q.x) * 2.0;
      child_bone.euler_angle.x += theta_x;
      child_bone.euler_angle.x = Math.max(0.05 * Math.PI / 180.0, child_bone.euler_angle.x);
      child_bone.euler_angle.x = Math.min(Math.PI, child_bone.euler_angle.x);

      child_bone.rotation.setEuler(0.0, child_bone.euler_angle.x, 0.0);
    } else {
      Quaternion q = new Quaternion.identity();
      q.setAxisAngle(axis, Math.min(theta, ik.max_angle * 4.0));
      child_bone.rotation.copyFrom(child_bone.rotation * q);
    }

    child_bone.update();
  }

  void _updatePMDIK(List<BoneNode> bones, PMD_IK ik) {
    List<BoneNode> child_bones = ik.child_bones.map((int i) => bones[i]).toList();

    BoneNode ik_bone_node = bones[ik.bone_index];
    BoneNode target_bone_node = bones[ik.target_bone_index];
    for (int i = 0; i < ik.iterations; i++) {
      child_bones.forEach((BoneNode child_bone) => this._updateChildPMDIK(child_bone, bones, ik));
    }
  }

  void _updateChildPMXIK(MMD_IK ik, BoneNode ik_bone_node, BoneNode target_bone_node) {
    Vector3 target_position = target_bone_node.absolute_bone_position;
    Vector3 ik_position = ik_bone_node.absolute_bone_position;
    if (target_position.distanceToSquared(ik_position) < 0.01) {
      return;
    }

    Vector3 v1 = ik.bone.absolute_rotation.rotated(target_position - ik.bone.absolute_bone_position);
    Vector3 v2 = ik.bone.absolute_rotation.rotated(ik_position - ik.bone.absolute_bone_position);
    num theta = Math.acos(Math.min(Math.max(v1.dot(v2) / (v1.length * v2.length), -1.0), 1.0));

    Vector3 axis = v1.cross(v2).normalize();

    if (ik.max != null || ik.min != null) {
      Quaternion q1 = new Quaternion.identity();
      q1.setAxisAngle(axis, Math.min(theta, ik_bone_node.max_angle));

      double pitch = Math.asin(q1.x) * 2.0;
      double yaw = Math.asin(q1.y) * 2.0;
      double roll = Math.asin(q1.z) * 2.0;

      ik.bone.euler_angle.x += pitch;
      ik.bone.euler_angle.y += yaw;
      ik.bone.euler_angle.z += roll;

      ik.bone.euler_angle.x = Math.min(Math.max(ik.bone.euler_angle.x, ik.min.x), ik.max.x);
      ik.bone.euler_angle.y = Math.min(Math.max(ik.bone.euler_angle.y, ik.min.y), ik.max.y);
      ik.bone.euler_angle.z = Math.min(Math.max(ik.bone.euler_angle.z, ik.min.z), ik.max.z);
      ik.bone.rotation.setEuler(ik.bone.euler_angle.y, ik.bone.euler_angle.x, ik.bone.euler_angle.z);
    } else {
      Quaternion q = new Quaternion.identity();
      q.setAxisAngle(axis, Math.min(theta, ik_bone_node.max_angle));

      ik.bone.rotation.copyFrom(ik.bone.rotation * q);
    }

    ik.bone.update();
  }

  void _updatePMXIK(List<BoneNode> bones) {
    bones.where((BoneNode bone) => (bone.iks != null) && bone.iks.isNotEmpty).forEach((BoneNode ik_bone_node) {
      BoneNode target_bone_node = ik_bone_node.ik_target_bone;

      for (int i = 0; i < ik_bone_node.ik_iterations; i++) {
        ik_bone_node.iks.forEach((MMD_IK ik) {
          this._updateChildPMXIK(ik, ik_bone_node, target_bone_node);
        });
      }
    });
  }

  void _updateBoneAnimation(List<BoneNode> bones, List<PMD_IK> iks, VMD_Animation vmd, int frame) {
    bones.forEach((BoneNode bone) => bone.applyVMD(vmd, frame));

    bones.where((BoneNode bone) => bone.parent == null).forEach((BoneNode bone) => bone.update());

    if (iks != null) {
      iks.forEach((ik) => this._updatePMDIK(bones, ik));
    } else {
      this._updatePMXIK(bones);
    }


    bones.where((BoneNode bone) => bone.ik_parent_transform != null).forEach((BoneNode bone) {
      slerpQuaternion(
          bone.rotation,
          bone.ik_parent_transform.rotation,
          bone.ik_parent_transform_weight).copyTo(bone.rotation);
      (bone.ik_parent_transform.position * bone.ik_parent_transform_weight +
          bone.position * (1.0 - bone.ik_parent_transform_weight)).copyInto(bone.position);
      bone.update();
    });
  }

  void render(double elapsed) {
    this.debug_particle_shader.vertices = new List<DebugVertex>();
    this.debug_axis_shader.axises = new List<DebugAxis>();

    if (this.mesh == null || this.vmd == null) {
      return;
    }

    if (this.start == null) {
      this.start = elapsed;
      this.frame = 0;
    }

    if (this.play) {
      this.frame = ((elapsed - start) / 30.0).round() % 750;
    }

    Matrix4 projection = new Matrix4.identity();
    setPerspectiveMatrix(projection, Math.PI * 60.0 / 180.0, this.aspect, 0.1, 100.0);

    Matrix4 view = new Matrix4.identity();
    Vector3 look_from = new Vector3(0.0, 0.0, 5.0 + 45.0 * this.trackball.value);
    setViewMatrix(view, look_from, new Vector3(0.0, 0.0, 0.0), new Vector3(0.0, 1.0, 0.0));

    Matrix4 rot = new Matrix4.identity();
    rot.setRotation(this.trackball.rotation.asRotationMatrix());

    Matrix4 model = rot;
    Matrix4 mvp = projection * view * model;

    if (this.pmd != null) {
      this._updateBoneAnimation(this.mesh.bones, this.pmd.iks, this.vmd, this.frame);
    } else if (this.pmx != null) {
      this._updateBoneAnimation(this.mesh.bones, null, this.vmd, this.frame);
    }
    this._writeBoneTexture(this.mesh.bones, this.mesh.bone_texture.data);
    this.mesh.bone_texture.refresh(gl);

    Map<String, double> morph_weights = this.vmd.getMorphFrame(frame);
    if (this.pmx != null) {
      this.pmx.createSubPositionList(morph_weights).forEach((SubArrayData sub_data) {
        this.mesh.position_buffer.setSubData(gl, sub_data);
      });
    }

    if (this.enable_deferred_shader) {
      //setup shader
      gl.bindFramebuffer(GL.FRAMEBUFFER, this.geometry_renderer.fbo);
      gl.clearColor(0.5, 0.5, 0.5, 1.0);
      gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);

      this.geometry_renderer.mesh = this.mesh;
      this.geometry_renderer.model = model;
      this.geometry_renderer.view = view;
      this.geometry_renderer.projection = projection;
      this.geometry_renderer.mvp = mvp;
      this.geometry_renderer.render(elapsed);

      if (this.enable_sraa) {
        gl.bindFramebuffer(GL.FRAMEBUFFER, null);
        this.deferred_aa_renderer.color_texture = this.geometry_renderer.color_texture;
        this.deferred_aa_renderer.normal_texture = this.geometry_renderer.normal_texture;
        this.deferred_aa_renderer.depth_texture = this.geometry_renderer.depth_texture;
        this.deferred_aa_renderer.render(elapsed);
      } else {
        gl.bindFramebuffer(GL.FRAMEBUFFER, null);
        this.copy_renderer.texture_buffer = this.geometry_renderer.color_texture;
        this.copy_renderer.render(elapsed);
      }
    } else {
      //setup shader
      gl.bindFramebuffer(GL.FRAMEBUFFER, this.fbo.buffer);
      gl.clearColor(0.5, 0.5, 0.5, 1.0);
      gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);

      if (this.enable_edge_shader) {
        this.edge_shader.mesh = this.mesh;

        this.edge_shader.model = model;
        this.edge_shader.view = view;
        this.edge_shader.projection = projection;
        this.edge_shader.mvp = mvp;
        this.edge_shader.render(elapsed);
      }

      this.main_shader.mesh = this.mesh;
      this.main_shader.model = model;
      this.main_shader.view = view;
      this.main_shader.projection = projection;
      this.main_shader.mvp = mvp;
      this.main_shader.render(elapsed);

      gl.bindFramebuffer(GL.FRAMEBUFFER, null);
      this.copy_renderer.texture_buffer = this.fbo.texture;
      this.copy_renderer.render(elapsed);
    }

    //mvp.copyInto(this.debug_axis_shader.mvp);
    //this.debug_axis_shader.render(elapsed);
    //mvp.copyInto(this.debug_particle_shader.mvp);
    //this.debug_particle_shader.render(elapsed);
  }
}
