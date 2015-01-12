library gltf_viewer;

import "dart:web_gl" as GL;
import "dart:math" as Math;
import "package:vector_math/vector_math.dart";
import "package:webgl_framework/webgl_framework.dart";

class GLTFRenderer extends WebGLRenderer {
  void _initialize() {
    var gltf = new GLTFParser.copy(this);
    gltf.load("model", "fighter.gltf")
    .then((GLTFParser gltf) {
    });
  }

  GLTFRenderer(int width, int height) {
    this.initContext(width, height);
    this.initTrackball();
    this._initialize();
  }

  GLTFRenderer.copy(WebGLRenderer src) {
    this.gl = src.gl;
    this.dom = src.dom;

    this._initialize();
  }

  void render(double ms) {
    Matrix4 projection = new Matrix4.identity();
    setPerspectiveMatrix(projection, Math.PI * 60.0 / 180.0, this.aspect, 0.1, 1000.0);

    Matrix4 view = new Matrix4.identity();
    Vector3 look_from = new Vector3(0.0, 0.0, 30.0 + 100.0 * this.trackball.value);
    setViewMatrix(view, look_from, new Vector3(0.0, 0.0, 0.0), new Vector3(0.0, 1.0, 0.0));

    Matrix4 model = new Matrix4.identity();
    model.setRotation(this.trackball.rotation.asRotationMatrix());

    Matrix4 mvp = projection * view * model;
  }
}
