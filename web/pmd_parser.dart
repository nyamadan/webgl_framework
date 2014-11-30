part of mmd_renderer;

class PMD_Exception implements Exception {
  final String message;
  const PMD_Exception(this.message);
  String toString() => "PMD_Exception\n${this.message}";
}

class PMD_Vertex {
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
    this.position.z = -view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.normal = new Vector3.zero();
    this.normal.x = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.normal.y = view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;
    this.normal.z = -view.getFloat32(offset, Endianness.LITTLE_ENDIAN);
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

class PMD_Material {
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

class PMD_Bone {
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

class PMD_IK {
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
    "iterations: ${this.iterations}",
    "control_weight: ${this.control_weight}",
    "child_bones: ${this.child_bones}",
  ].join(", "), "}"].join("");
}

class PMD_MorphVertex {
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

class PMD_Morph {
  String name;
  int morph_type;
  List<PMD_MorphVertex> morph_vertices;

  int parse(ByteBuffer buffer, ByteData view, int offset) {
    this.name = sjisArrayToString(new Uint8List.view(buffer, offset, 20));
    offset += 20;

    int length = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.morph_type = view.getUint8(offset);
    offset += 1;

    this.morph_vertices = new List<PMD_MorphVertex>.generate(length, (int i){
      var morph_vertex = new PMD_MorphVertex();
      offset = morph_vertex.parse(buffer, view, offset);
      return morph_vertex;
    });

    return offset;
  }
}

class PMD_Model {
  final Logger log = new Logger("PMD_Model");

  String name;
  String comment;

  List<PMD_Vertex> vertices;
  Uint16List triangles;
  List<PMD_Material> materials;
  List<PMD_Bone> bones;
  List<PMD_IK> iks;
  List<PMD_Morph> morphs;

  String toString() => ["{", [
    "name: ${this.name}",
    "comment: ${this.comment}",
    "triangles: ${this.triangles != null ? "..." : null}",
    "materials: ${this.materials != null ? "..." : null}",
    "bones: ${this.bones != null ? "..." : null}",
    "iks: ${this.iks != null ? "..." : null}",
    "morphs: ${this.morphs != null ? "..." : null}",
  ].join(", "), "}"].join("");

  Future<PMD_Model> load(String uri) {
    var completer = new Completer<PMD_Model>();
    var future = completer.future;

    var req = new HttpRequest();
    req.overrideMimeType("text\/plain; charset=x-user-defined");
    req.onLoad.listen((event){
      var u8_list = new Uint8List.fromList(req.responseText.codeUnits);
      ByteBuffer buffer = u8_list.buffer;

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

    log.info(this);
    for(int i = 0; i < this.bones.length; i++) {
      PMD_Bone bone = this.bones[i];
      String n = i.toString().padLeft(4, "0");
      log.fine("$n: $bone");
    }

    for(int i = 0; i < this.iks.length; i++) {
      PMD_IK ik = this.iks[i];
      String n = i.toString().padLeft(4, "0");
      log.fine("$n: $ik");
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

  Float32List createBoneList() {
    Float32List bone_list = new Float32List(this.vertices.length * 3);
    for(int i = 0; i < this.vertices.length; i++) {
      PMD_Vertex vertex = this.vertices[i];
      bone_list[i * 3 + 0] = vertex.bone1 * 1.0;
      bone_list[i * 3 + 1] = vertex.bone2 * 1.0;
      bone_list[i * 3 + 2] = vertex.bone_weight / 100.0;
    }
    return bone_list;
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
      throw(new PMD_Exception("File is not PMD"));
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

    this.vertices = new List<PMD_Vertex>.generate(length, (int i){
      var v = new PMD_Vertex();
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

    this.materials = new List<PMD_Material>.generate(length, (int i){
      var material = new PMD_Material();
      offset = material.parse(buffer, view, offset);
      return material;
    });

    return offset;
  }

  int _getBones(ByteBuffer buffer, ByteData view, int offset) {
    int length = view.getUint16(offset, Endianness.LITTLE_ENDIAN);
    offset += 2;

    this.bones = new List<PMD_Bone>.generate(length, (int i){
      var bone = new PMD_Bone();
      offset = bone.parse(buffer, view, offset);
      return bone;
    });

    return offset;
  }

  int _getIKs(ByteBuffer buffer, ByteData view, int offset) {
    int length = view.getUint16(offset, Endianness.LITTLE_ENDIAN);
    offset += 2;

    this.iks = new List<PMD_IK>.generate(length, (int i){
      var ik = new PMD_IK();
      offset = ik.parse(buffer, view, offset);
      return ik;
    });

    return offset;
  }

  int _getMorphs(ByteBuffer buffer, ByteData view, int offset) {
    int length = view.getUint16(offset, Endianness.LITTLE_ENDIAN);
    offset += 2;

    this.morphs = new List<PMD_Morph>.generate(length, (int i){
      var morph = new PMD_Morph();
      offset = morph.parse(buffer, view, offset);
      return morph;
    });

    return offset;
  }
}

