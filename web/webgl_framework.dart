import 'dart:html';

import "teapot_renderer.dart";

void main() {
  var renderer = new TeapotRenderer();

  document.querySelector("body").append(renderer.dom);

  void render(double ms) {
    window.requestAnimationFrame(render);
    renderer.render(ms);
  }

  render(0.0);
}

