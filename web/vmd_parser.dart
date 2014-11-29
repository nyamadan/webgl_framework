part of mmd_renderer;

class VMD_Exception implements Exception {
  final String message;
  const VMD_Exception(this.message);
  String toString() => "VMD_Exception\n${this.message}";
}

class VMD_BoneMotion {
  String name;
  int frame;
  Vector3 location;
  Quaternion rotation;
  Uint8List interpolation;

  String toString() {
    return ["{", [
      "name: ${this.name}",
      "frame: ${this.frame}",
      "location: ${this.location}",
      "rotation: ${this.rotation}",
      "interpolation: ${this.interpolation}",
    ].join(", "), "}" ].join("");
  }
  int parse(ByteBuffer buffer, ByteData view, int offset) {
    this.name = sjisArrayToString(new Uint8List.view(buffer, offset, 15));
    offset += 15;

    this.frame = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.location = new Vector3(
      view.getFloat32(offset + 0, Endianness.LITTLE_ENDIAN),
      view.getFloat32(offset + 4, Endianness.LITTLE_ENDIAN),
      -view.getFloat32(offset + 8, Endianness.LITTLE_ENDIAN)
    );
    offset += 12;

    this.rotation = new Quaternion(
      -view.getFloat32(offset + 0, Endianness.LITTLE_ENDIAN),
      -view.getFloat32(offset + 4, Endianness.LITTLE_ENDIAN),
      view.getFloat32(offset + 8, Endianness.LITTLE_ENDIAN),
      view.getFloat32(offset + 12, Endianness.LITTLE_ENDIAN)
    );
    offset += 16;

    this.interpolation = new Uint8List.fromList(new List<int>.generate(16, (int i) => view.getUint8(offset + i)));
    offset += 64;

    return offset;
  }
}

class VMD_Animation {
  String name;
  List<VMD_BoneMotion> bone_motions;

  Future<VMD_Animation> load(String uri) {
    var completer = new Completer<VMD_Animation>();
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

  String toString() {
    return ["{", [
      "name: ${this.name}",
      "bone_motions: ${this.bone_motions != null ? '...' : null}",
    ].join(", "), "}" ].join("");
  }

  void parse(ByteBuffer buffer) {
    var view = new ByteData.view(buffer);
    int offset = 0;
    offset = this._checkHeader(buffer, view, offset);
    offset = this._getModelName(buffer, view, offset);
    offset = this._getBoneMotions(buffer, view, offset);
  }

  int _checkHeader(ByteBuffer buffer, ByteData view, int offset) {
    String header = new String.fromCharCodes(new Uint8List.view(buffer, offset, 30));
    if( "Vocaloid Motion Data 0002\0\0\0\0\0" == header ) {
      throw(new VMD_Exception("File is not VMD"));
    }

    return offset + 30;
  }

  int _getModelName(ByteBuffer buffer, ByteData view, int offset) {
    this.name = sjisArrayToString(new Uint8List.view(buffer, offset, 20));
    offset += 20;
    return offset;
  }

  int _getBoneMotions(ByteBuffer buffer, ByteData view, int offset) {
    int length = view.getUint32(offset, Endianness.LITTLE_ENDIAN);
    offset += 4;

    this.bone_motions = new List<VMD_BoneMotion>.generate(length, (int i){
      VMD_BoneMotion bone_motion = new VMD_BoneMotion();
      offset = bone_motion.parse(buffer, view, offset);
      return bone_motion;
    });

    // sort by frame
    this.bone_motions.sort((VMD_BoneMotion frame1, VMD_BoneMotion frame2){
      return frame1.frame - frame2.frame;
    });

    return offset;
  }

  List<VMD_BoneMotion> getFrame(String bone_name, int frame) {
    VMD_BoneMotion prev_frame = null;
    VMD_BoneMotion next_frame = null;
    for(int i = 0; i < this.bone_motions.length; i++) {
      VMD_BoneMotion bone_motion = this.bone_motions[i];
      if(bone_name != bone_motion.name) {
        continue;
      }

      if(bone_motion.frame < frame) {
        prev_frame = bone_motion;
        continue;
      }

      next_frame = bone_motion;
      break;
    }

    //not found
    if(prev_frame == null && next_frame == null) {
      return null;
    }

    return [prev_frame, next_frame];
  }

}
