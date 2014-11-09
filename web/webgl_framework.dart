import 'dart:html';

import "mmd_renderer.dart";

void main() {
  var renderer = new MMD_Renderer();

  document.querySelector("body").append(renderer.dom);

  void render(double ms) {
    window.requestAnimationFrame(render);
    renderer.render(ms);
  }

  render(0.0);
}

