part of mmd_renderer;


class MMD_VertMorph {
  int vertex_index;
  List data;
}

class MMD_Morph {
  String name;
  String english_name;
  List data;
}

class MMD_IK {
  BoneNode bone;
  Vector3 min;
  Vector3 max;

  String toString() =>
      ["{", ["bone : ${this.bone}", "max : ${this.max}", "min : ${this.min}",].join(", "), "}"].join("");
}

class BoneNode {
  String name;
  int bone_type = 0;
  Vector3 original_bone_position = new Vector3.zero();
  Vector3 relative_bone_position = new Vector3.zero();
  Vector3 absolute_bone_position = new Vector3.zero();

  Vector3 position = new Vector3.zero();
  Vector3 scale = new Vector3(1.0, 1.0, 1.0);
  Vector3 euler_angle = new Vector3.zero();
  Quaternion rotation = new Quaternion.identity();
  Quaternion absolute_rotation = new Quaternion.identity();

  Matrix4 absolute_transform = new Matrix4.identity();
  Matrix4 relative_transform = new Matrix4.identity();

  BoneNode parent = null;
  List<BoneNode> children = new List<BoneNode>();

  BoneNode ik_target_bone = null;
  int ik_iterations;
  double max_angle;
  List<MMD_IK> iks = new List<MMD_IK>();

  BoneNode ik_parent_transform;
  double ik_parent_transform_weight;

  void applyVMD(VMD_Animation vmd, int frame) {
    //リセットする
    this.rotation = new Quaternion.identity();
    this.position = new Vector3.zero();
    this.scale = new Vector3(1.0, 1.0, 1.0);
    this.euler_angle = new Vector3.zero();

    List<VMD_BoneMotion> motions = vmd.getFrame(this.name, frame);
    if (motions != null) {
      VMD_BoneMotion prev_frame = motions[0];
      VMD_BoneMotion next_frame = motions[1];
      if (prev_frame == null && next_frame != null) {
        next_frame.rotation.copyTo(this.rotation);
        next_frame.location.copyInto(this.position);
      } else if (prev_frame != null && next_frame == null) {
        prev_frame.rotation.copyTo(this.rotation);
        prev_frame.location.copyInto(this.position);
      } else {
        double blend = (frame - prev_frame.frame) / (next_frame.frame - prev_frame.frame);

        slerpQuaternion(prev_frame.rotation, next_frame.rotation, blend).copyTo(this.rotation);
        (next_frame.location * blend + prev_frame.location * (1.0 - blend)).copyInto(this.position);
      }
    }
  }

  void update({bool recursive: true}) {
    Matrix4 scale_matrix = new Matrix4.identity();
    scale_matrix.scale(this.scale);

    Matrix4 rotation_matrix = new Matrix4.identity();
    rotation_matrix.setRotation(this.rotation.asRotationMatrix());

    Matrix4 translate_matrix = new Matrix4.identity();
    translate_matrix.setTranslation(this.position);

    this.relative_transform = translate_matrix * rotation_matrix * scale_matrix;
    if (this.parent != null) {
      this.relative_transform = this.parent.relative_transform * this.relative_transform;
    }

    Matrix4 bone_translate_matrix = new Matrix4.identity();
    bone_translate_matrix.setTranslation(this.relative_bone_position);

    this.absolute_transform = bone_translate_matrix * translate_matrix * rotation_matrix * scale_matrix;
    this.absolute_rotation = new Quaternion.copy(this.rotation);
    if (this.parent != null) {
      this.absolute_transform = this.parent.absolute_transform * this.absolute_transform;
      this.absolute_rotation = this.parent.absolute_rotation * this.absolute_rotation;
    }

    this.absolute_bone_position = new Vector3.copy(this.absolute_transform.getColumn(3).xyz);

    if (recursive) {
      this.children.forEach((BoneNode bone) {
        bone.update(recursive: true);
      });
    }
  }

  String toString() =>
      [
          "{",
          [
              "parent : ${this.parent != null ? this.parent.name : null }",
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
              "ik_parent_transform : ${this.ik_parent_transform != null ? this.ik_parent_transform.name : null }",
              "ik_parent_transform_weight : ${this.ik_parent_transform_weight}",
              "iks : ${this.iks != null ? '...' : null}",].join(", "),
          "}"].join("");
}
