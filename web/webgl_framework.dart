import 'dart:html';
import "package:logging/logging.dart";

import "mmd_renderer.dart";

void main() {
  //initialize logger
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });

  var renderer = new MMD_Renderer(512, 512);

  document.querySelector("body").append(renderer.dom);

  void render(double ms) {
    window.requestAnimationFrame(render);
    renderer.render(ms);
  }

  render(0.0);
}

