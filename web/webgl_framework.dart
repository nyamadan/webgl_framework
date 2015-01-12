import 'dart:html';
import "package:logging/logging.dart";

import "mmd_renderer.dart";

void main() {
  //initialize logger
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    if(rec.level >= Level.SEVERE) {
      window.console.log('${rec.level.name}: ${rec.time}: ${rec.message}');
      return;
    }

    if(rec.level >= Level.WARNING) {
      window.console.warn('${rec.level.name}: ${rec.time}: ${rec.message}');
      return;
    }
    if(rec.level >= Level.INFO) {
      window.console.info('${rec.level.name}: ${rec.time}: ${rec.message}');
      return;
    }
    window.console.log('${rec.level.name}: ${rec.time}: ${rec.message}');
  });

  var renderer = new MMD_Renderer(1024, 1024);

  document.querySelector("body").append(renderer.dom);

  var frame_slider_element = document.querySelector("#frame-slider") as InputElement;
  var frame_element = document.querySelector("#frame") as InputElement;
  var play = document.querySelector("#play") as InputElement;

  play.onChange.listen((event){
    if(play.checked) {
      frame_slider_element.disabled = true;
      frame_element.disabled = true;

      renderer.start = null;
      renderer.play = true;
    } else {
      frame_slider_element.disabled = false;
      frame_element.disabled = false;

      renderer.play = false;
    }
  });

  frame_slider_element.onChange.listen((event){
    if(!renderer.play) {
      int frame_value = int.parse(frame_slider_element.value);
      if(frame_value >= 0 && frame_value <= 750) {
        frame_element.value = frame_value.toString();
      }
    }
  });

  frame_element.onChange.listen((event){
    if(!renderer.play) {
      int frame_value = int.parse(frame_element.value);
      if(frame_value >= 0 && frame_value <= 750) {
        frame_slider_element.value = frame_value.toString();
      }
    }
  });

  void render(double ms) {
    window.requestAnimationFrame(render);

    if(!renderer.play) {
      int frame = int.parse(frame_slider_element.value, radix: 10);
      renderer.frame = frame;
    } else {
      if(renderer.frame is int) {
        frame_slider_element.value = renderer.frame.toString();
        frame_element.value = renderer.frame.toString();
      }
    }

    renderer.render(ms);
  }

  render(0.0);
}

