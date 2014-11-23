library mmd_renderer;

import 'dart:html';
import 'dart:typed_data';
import 'dart:async';
import 'dart:math' as Math;
import 'dart:web_gl' as GL;

import "package:webgl_framework/webgl_framework.dart";
import "package:vector_math/vector_math.dart";

import "sjis_to_string.dart";

class MMD_Vertex {
  Vector3 position;
  Vector3 normal;
  Vector2 coord;

  int bone1;
  int bone2;

  int bone_weight;
  int edge_flag;

  int parse(ByteBuffer buffer, ByteData view, int offset) {
    this.position = new Vector3.zero();
    this.position.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.position.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.position.z = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.normal = new Vector3.zero();
    this.normal.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.normal.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.normal.z = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.coord = new Vector2.zero();
    this.coord.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.coord.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.bone1 = view.getUint16(offset, Endianness.LITTLE_ENDIAN);
    offset += 2;

    this.bone2 = view.getUint16(offset, Endianness.LITTLE_ENDIAN);
    offset += 2;

    this.bone_weight = view.getUint8(offset);
    offset += 1;

    this.edge_flag = view.getUint8(offset);
    offset += 1;

    return offset;
  }

  String toString() => ["{", [
    "position: ${this.position}",
    "normal: ${this.normal}",
    "coord: ${this.coord}",
    "bone1: ${this.bone1}",
    "bone2: ${this.bone2}",
    "bone_weight: ${this.bone_weight}",
    "edge_flag: ${this.edge_flag}",
  ].join(", "), "}"].join("");
}

class MMD_Material {
  Vector3 diffuse;
  double alpha;
  double shiness;
  Vector3 specular;
  Vector3 ambient;
  int toon_index;
  int edge_flag;
  int face_vert_count;
  String texture_file_name;

  int parse(ByteBuffer buffer, ByteData view, int offset){
    var diffuse = new Vector3.zero();
    diffuse.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    diffuse.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    diffuse.z = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.diffuse = diffuse;

    this.alpha = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.shiness = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    var specular = new Vector3.zero();
    specular.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    specular.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    specular.z = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.specular = specular;

    var ambient = new Vector3.zero();
    ambient.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    ambient.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    ambient.z = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.ambient = ambient;

    this.toon_index = view.getInt8(offset);
    offset += 1;

    this.edge_flag = view.getUint8(offset);
    offset += 1;

    this.face_vert_count = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    var texture_file_name = new Uint8List(20);
    for(int i = 0; i < texture_file_name.length; i++) {
      texture_file_name[i] = view.getUint8(offset);
      offset += 1;
    }
    this.texture_file_name = sjisArrayToString(texture_file_name);

    return offset;
  }
}

class MMD_Bone {
  String name;
  int parent_bone_index;
  int tail_pos_bone_index;
  int bone_type;
  int ik_parent_bone_index;
  Vector3 bone_head_pos;

  int parse(ByteBuffer buffer, ByteData view, int offset) {
    this.name = sjisArrayToString(new Uint8List.view(buffer, offset, 20));
    offset += 20;

    this.parent_bone_index = view.getInt16(offset, Endianness.LITTLE_ENDIAN);
    offset += 2;

    this.tail_pos_bone_index = view.getInt16(offset, Endianness.LITTLE_ENDIAN);
    offset += 2;

    this.bone_type = view.getUint8(offset);
    offset += 1;

    this.ik_parent_bone_index = view.getUint16(offset, Endianness.LITTLE_ENDIAN);
    offset += 2;

    this.bone_head_pos = new Vector3.zero();
    this.bone_head_pos.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.bone_head_pos.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.bone_head_pos.z = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    return offset;
  }

  String toString() => ["{", [
    "name: ${this.name}",
    "bone_type: ${this.bone_type}",
    "bone_head_pos: ${this.bone_head_pos}",
    "ik_parent_bone_index: ${this.ik_parent_bone_index}",
    "parent_bone_index: ${this.parent_bone_index}",
  ].join(", "), "}"].join("");
}

class MMD_IK {
  int bone_index;
  int target_bone_index;
  int iterations;
  double control_weight;
  List<int> child_bones;

  int parse(ByteBuffer buffer, ByteData view, int offset) {
    this.bone_index = view.getInt16(offset, Endianness.LITTLE_ENDIAN);
    offset += 2;

    this.target_bone_index = view.getInt16(offset, Endianness.LITTLE_ENDIAN);
    offset += 2;

    int chain_length = view.getUint8(offset);
    offset += 1;

    this.iterations = view.getUint16(offset, Endianness.LITTLE_ENDIAN);
    offset += 2;

    this.control_weight = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.child_bones = new List<int>.generate(chain_length, (int i){
      int bone_index = view.getInt16(offset, Endianness.LITTLE_ENDIAN);
      offset += 2;

      return bone_index;
    });

    return offset;
  }

  String toString() => ["{", [
    "bone_index: ${this.bone_index}",
    "target_bone_index: ${this.target_bone_index}",
    "position: ${this.iterations}",
    "control_weight: ${this.control_weight}",
    "child_bones: ${this.child_bones}",
  ].join(", "), "}"].join("");
}

class MMD_MorphVertex {
  int index;
  Vector3 position;

  int parse(ByteBuffer buffer, ByteData view, int offset) {
    this.index = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.position = new Vector3.zero();

    this.position.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.position.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.position.z = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    return offset;
  }

  String toString() => ["{", [
    "index: ${this.index}",
    "position: ${this.position}",
  ].join(", "), "}"].join("");
}

class MMD_Morph {
  String name;
  int morph_type;
  List<MMD_MorphVertex> morph_vertices;

  int parse(ByteBuffer buffer, ByteData view, int offset) {
    this.name = sjisArrayToString(new Uint8List.view(buffer, offset, 20));
    offset += 20;

    int length = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.morph_type = view.getUint8(offset);
    offset += 1;

    this.morph_vertices = new List<MMD_MorphVertex>.generate(length, (int i){
      var morph_vertex = new MMD_MorphVertex();
      offset = morph_vertex.parse(buffer, view, offset);
      return morph_vertex;
    });

    return offset;
  }
}

class MMD_Model {
  String name;
  String comment;

  List<MMD_Vertex> vertices;
  Uint16List triangles;
  List<MMD_Material> materials;
  List<MMD_Bone> bones;
  List<MMD_IK> iks;
  List<MMD_Morph> morphs;

  Future<MMD_Model> load(String uri) {
    var completer = new Completer<MMD_Model>();
    var future = completer.future;

    var req = new HttpRequest();
    req.responseType = "arraybuffer";
    req.onLoad.listen((event){
      ByteBuffer buffer = req.response;
      this.parse(buffer);
      completer.complete(this);
    });
    req.open("GET", uri);
    req.send();

    return future;
  }

  void parse(ByteBuffer buffer) {
    var view = new ByteData.view(buffer);
    int offset = 0;
    offset = this._checkHeader(buffer, view, offset);
    offset = this._getName(buffer, view, offset);
    offset = this._getVertices(buffer, view, offset);
    offset = this._getTriangles(buffer, view, offset);
    offset = this._getMaterials(buffer, view, offset);
    offset = this._getBones(buffer, view, offset);
    offset = this._getIKs(buffer, view, offset);
    offset = this._getMorphs(buffer, view, offset);
  }

  void normalizePositions() {
    for(int i = 0; i < this.vertices.length; i++) {
      MMD_Vertex vertex = this.vertices[i];
      MMD_Bone bone1 = this.bones[vertex.bone1];
      MMD_Bone bone2 = this.bones[vertex.bone2];
      num weight = vertex.bone_weight / 100;
      Vector3 offset = (bone1.bone_head_pos * weight) + (bone2.bone_head_pos * (1.0 - weight));
      vertex.position = vertex.position - offset;
    }
  }

  void denormalizePositions() {
    for(int i = 0; i < this.vertices.length; i++) {
      MMD_Vertex vertex = this.vertices[i];
      MMD_Bone bone1 = this.bones[vertex.bone1];
      MMD_Bone bone2 = this.bones[vertex.bone2];
      num weight = vertex.bone_weight / 100;
      Vector3 offset = (bone1.bone_head_pos * weight) + (bone2.bone_head_pos * (1.0 - weight));
      vertex.position = vertex.position + offset;
    }
  }

  Uint16List createTriangleList([int index = null]) {
    if(index == null) {
      return new Uint16List.fromList(this.triangles);
    }

    int offset = 0;
    int i = 0;
    for(i = 0; i < index; i++) {
      offset += this.materials[i].face_vert_count;
    }

    var triangles = this.triangles
      .getRange(offset, offset + this.materials[i].face_vert_count)
      .toList()
    ;
    return new Uint16List.fromList(triangles);
  }

  Float32List createPositionList() {
    Float32List position_list = new Float32List(this.vertices.length * 3);
    for(int i = 0; i < this.vertices.length; i++) {
      var position = this.vertices[i].position;
      position_list[i * 3 + 0] = position.x;
      position_list[i * 3 + 1] = position.y;
      position_list[i * 3 + 2] = position.z;
    }
    return position_list;
  }

  Float32List createNormalList() {
    Float32List normal_list = new Float32List(this.vertices.length * 3);
    for(int i = 0; i < this.vertices.length; i++) {
      var normal = this.vertices[i].normal;
      normal_list[i * 3 + 0] = normal.x;
      normal_list[i * 3 + 1] = normal.y;
      normal_list[i * 3 + 2] = normal.z;
    }
    return normal_list;
  }

  Float32List createCoordList() {
    Float32List normal_list = new Float32List(this.vertices.length * 2);
    for(int i = 0; i < this.vertices.length; i++) {
      var coord = this.vertices[i].coord;
      normal_list[i * 2 + 0] = coord.x;
      normal_list[i * 2 + 1] = coord.y;
    }
    return normal_list;
  }

  int _checkHeader(ByteBuffer buffer, ByteData view, int offset) {
    var header = buffer.asUint8List(0, 7);
    if(
    header[0] != 0x50 ||
    header[1] != 0x6d ||
    header[2] != 0x64 ||
    header[3] != 0x00 ||
    header[4] != 0x00 ||
    header[5] != 0x80 ||
    header[6] != 0x3f
    ) {
      throw(new Exception("File is not PMD"));
    }

    return offset + 7;
  }

  int _getName(ByteBuffer buffer, ByteData view, int offset) {
    var name = new Uint8List(20);
    for(int i = 0; i < name.length; i++) {
      name[i] = view.getUint8(offset);
      offset += 1;
    }
    this.name = sjisArrayToString(name);

    var comment = new Uint8List(256);
    for(int i = 0; i < comment.length; i++) {
      comment[i] = view.getUint8(offset);
      offset += 1;
    }
    this.comment = sjisArrayToString(comment);

    return offset;
  }

  int _getVertices(ByteBuffer buffer, ByteData view, int offset) {
    int length = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
    offset += Uint32List.BYTES_PER_ELEMENT;

    this.vertices = new List<MMD_Vertex>.generate(length, (int i){
      var v = new MMD_Vertex();
      offset = v.parse(buffer, view, offset);
      return v;
    });
    return offset;
  }

  int _getTriangles(ByteBuffer buffer, ByteData view, int offset) {
    int length = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.triangles = new Uint16List(length);
    for(int i = 0; i < length; i += 3) {
      int v0 = view.getUint16(offset, Endianness.LITTLE_ENDIAN);
      offset += 2;

      int v1 = view.getUint16(offset, Endianness.LITTLE_ENDIAN);
      offset += 2;

      int v2 = view.getUint16(offset, Endianness.LITTLE_ENDIAN);
      offset += 2;

      this.triangles[i + 0] = v1;
      this.triangles[i + 1] = v0;
      this.triangles[i + 2] = v2;
    }

    return offset;
  }

  int _getMaterials(ByteBuffer buffer, ByteData view, int offset) {
    int length = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.materials = new List<MMD_Material>.generate(length, (int i){
      var material = new MMD_Material();
      offset = material.parse(buffer, view, offset);
      return material;
    });

    return offset;
  }

  int _getBones(ByteBuffer buffer, ByteData view, int offset) {
    int length = view.getUint16(offset, Endianness.LITTLE_ENDIAN);
    offset += 2;

    this.bones = new List<MMD_Bone>.generate(length, (int i){
      var bone = new MMD_Bone();
      offset = bone.parse(buffer, view, offset);
      return bone;
    });

    return offset;
  }

  int _getIKs(ByteBuffer buffer, ByteData view, int offset) {
    int length = view.getUint16(offset, Endianness.LITTLE_ENDIAN);
    offset += 2;

    this.iks = new List<MMD_IK>.generate(length, (int i){
      var ik = new MMD_IK();
      offset = ik.parse(buffer, view, offset);
      return ik;
    });

    return offset;
  }

  int _getMorphs(ByteBuffer buffer, ByteData view, int offset) {
    int length = view.getUint16(offset, Endianness.LITTLE_ENDIAN);
    offset += 2;

    this.morphs = new List<MMD_Morph>.generate(length, (int i){
      var morph = new MMD_Morph();
      offset = morph.parse(buffer, view, offset);
      return morph;
    });

    return offset;
  }
}

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

  MMD_Model pmd;

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
    (new MMD_Model())
    .load("miku.pmd")
    .then((MMD_Model pmd){
      var position_list = pmd.createPositionList();
      var normal_list = pmd.createNormalList();
      var coord_list = pmd.createCoordList();

      this.position_buffer = this.createArrayBuffer(position_list);
      this.normal_buffer = this.createArrayBuffer(normal_list);
      this.coord_buffer = this.createArrayBuffer(coord_list);

      this.index_buffer_list = new List<WebGLElementArrayBuffer>.generate(pmd.materials.length,
        (int i) => this.createElementArrayBuffer(pmd.createTriangleList(i))
      );

      this.white_texture = this.createCanvasTexture(
        width : 16, height : 16,
        color : new Vector4(1.0, 1.0, 1.0, 1.0)
      );

      this.textures = new Map<String, WebGLCanvasTexture>();
      pmd.materials.forEach((MMD_Material material){
        if( material.texture_file_name.isEmpty || this.textures.containsKey(material.texture_file_name)) {
          return;
        }

        var texture = this.createCanvasTexture();
        this.loadCanvasTexture(texture, material.texture_file_name);
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
    Vector3 look_from = new Vector3(0.0, 0.0, 25.0 + 25.0 * this.trackball_value);
    setViewMatrix(view, look_from, new Vector3(0.0, 0.0, 0.0), new Vector3(0.0, 1.0, 0.0));

    Matrix4 rh = new Matrix4.identity();
    rh.storage[10] = -1.0;

    Matrix4 rot = new Matrix4.identity();
    rot.setRotation(this.trackball_rotation.asRotationMatrix());

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
