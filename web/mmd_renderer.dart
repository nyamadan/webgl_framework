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
}

class MMD_Model {
  String name;
  String comment;

  List<MMD_Vertex> vertices;
  Uint16List triangles;
  List<MMD_Material> materials;

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
    for(int i = 0; i < this.vertices.length; i += 3) {
      var normal = this.vertices[i].normal;
      normal_list[i * 3 + 0] = normal.x;
      normal_list[i * 3 + 1] = normal.y;
      normal_list[i * 3 + 2] = normal.z;
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

    this.vertices = new List<MMD_Vertex>();
    for(int i = 0; i < length; i++) {
      var v = new MMD_Vertex();

      v.position = new Vector3.zero();
      v.position.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      v.position.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      v.position.z = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;

      v.normal = new Vector3.zero();
      v.normal.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      v.normal.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      v.normal.z = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;

      v.coord = new Vector2.zero();
      v.coord.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      v.coord.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;

      v.bone1 = view.getUint16(offset, Endianness.LITTLE_ENDIAN);
      offset += 2;

      v.bone2 = view.getUint16(offset, Endianness.LITTLE_ENDIAN);
      offset += 2;

      v.bone_weight = view.getUint8(offset);
      offset += 1;

      v.edge_flag = view.getUint8(offset);
      offset += 1;

      this.vertices.add(v);
    }
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

    this.materials = new List<MMD_Material>();
    for(int i = 0; i < length; i += 3) {
      var material = new MMD_Material();

      var diffuse = new Vector3.zero();
      diffuse.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      diffuse.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      diffuse.z = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      material.diffuse = diffuse;

      material.alpha = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;

      material.shiness = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;

      var specular = new Vector3.zero();
      specular.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      specular.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      specular.z = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      material.specular = specular;

      var ambient = new Vector3.zero();
      ambient.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      ambient.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      ambient.z = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      material.ambient = ambient;

      material.toon_index = view.getInt8(offset);
      offset += 1;

      material.edge_flag = view.getUint8(offset);
      offset += 1;

      material.face_vert_count = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;

      var texture_file_name = new Uint8List(20);
      for(int i = 0; i < texture_file_name.length; i++) {
        texture_file_name[i] = view.getUint8(offset);
        offset += 1;
      }
      material.texture_file_name = sjisArrayToString(texture_file_name);

      this.materials.add(material);
    }

    return offset;
  }
}

class MMD_Renderer extends WebGLRenderer {
  static const String VS =
  """
  attribute vec3 position;
  attribute vec3 normal;
  uniform mat4 mvp_matrix;

  varying vec3 v_normal;

  void main(void){
    v_normal = normal;
    gl_Position = mvp_matrix * vec4(position, 1.0);
  }
  """;

  static const String FS =
  """
  precision mediump float;

  uniform vec4 diffuse;
  varying vec3 v_normal;

  void main(void){
    gl_FragColor = diffuse;
  }
  """;

  GL.Program program;

  Map<String, int> attributes;
  Map<String, GL.UniformLocation> uniforms;

  WebGLArrayBuffer position_buffer;
  WebGLArrayBuffer normal_buffer;
  List<WebGLElementArrayBuffer> index_buffer_list;
  Map<String, WebGLCanvasTexture> textures;

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
    ]);

    this.uniforms = this.getUniformLocations(this.program, [
      "diffuse",
      "mvp_matrix",
    ]);

    gl.enable(GL.DEPTH_TEST);
    gl.depthFunc(GL.LEQUAL);

    gl.enable(GL.CULL_FACE);
    gl.frontFace(GL.CW);

    gl.clearColor(0.5, 0.5, 0.5, 1.0);
    gl.useProgram(this.program);

    if (this.attributes.containsKey("position")) {
      gl.enableVertexAttribArray(this.attributes["position"]);
    }

    if (this.attributes.containsKey("normal")) {
      gl.enableVertexAttribArray(this.attributes["normal"]);
    }

    this._load();
  }

  void _load() {
    (new MMD_Model())
    .load("miku.pmd")
    .then((MMD_Model pmd){
      var position_list = pmd.createPositionList();
      var normal_list = pmd.createNormalList();

      this.position_buffer = this.createArrayBuffer(position_list);
      this.normal_buffer = this.createArrayBuffer(normal_list);

      this.index_buffer_list = new List<WebGLElementArrayBuffer>.generate(pmd.materials.length,
        (int i) => this.createElementArrayBuffer(pmd.createTriangleList(i))
      );

      this.textures = new Map<String, WebGLCanvasTexture>();
      pmd.materials.forEach((MMD_Material material){
        if( material.texture_file_name.isEmpty || this.textures.containsKey(material.texture_file_name)) {
          return;
        }

        var texture = this.createCanvasTexture();
        var uri = material.texture_file_name;
        this.loadCanvasTexture(texture, uri);
        this.textures[uri] = texture;
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

    Matrix4 model = new Matrix4.identity();
    model.setRotation(this.trackball_rotation.asRotationMatrix());

    Matrix4 mvp = projection * view * model;

    if (this.uniforms.containsKey("mvp_matrix")) {
      gl.uniformMatrix4fv(this.uniforms["mvp_matrix"], false, mvp.storage);
    }

    if (this.attributes.containsKey("normal")) {
      gl.bindBuffer(GL.ARRAY_BUFFER, this.normal_buffer.buffer);
      gl.vertexAttribPointer(this.attributes["normal"], 3, GL.FLOAT, false, 0, 0);
    }

    if (this.attributes.containsKey("position")) {
      gl.bindBuffer(GL.ARRAY_BUFFER, this.position_buffer.buffer);
      gl.vertexAttribPointer(this.attributes["position"], 3, GL.FLOAT, false, 0, 0);
    }

    gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);

    for (int i = 0; i < this.pmd.materials.length; i++) {
      var index_buffer = this.index_buffer_list[i];

      if (this.uniforms.containsKey("diffuse")) {
        var color = new Vector4.zero();
        color.rgb = this.pmd.materials[i].diffuse;
        color.a = this.pmd.materials[i].alpha;
        gl.uniform4fv(this.uniforms["diffuse"], color.storage);
      }

      gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, index_buffer.buffer);
      gl.drawElements(GL.TRIANGLES, index_buffer.data.length, GL.UNSIGNED_SHORT, 0);
    }
  }
}
