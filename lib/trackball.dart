part of webgl_framework;

class _Trackball {
  bool enabled = true;
  double value = 0.5;
  double delta = 0.05;
  Quaternion rotation = new Quaternion.identity();
  Vector2 rotation_delta = new Vector2(0.01, 0.01);

  _Trackball(HtmlElement element) {
    Point prev_point = null;
    element.onMouseDown.listen((MouseEvent event){
      event.preventDefault();

      prev_point = event.client;
    });

    element.onMouseMove.listen((MouseEvent event){
      event.preventDefault();

      if (prev_point == null) {
        return;
      }

      if(this.enabled) {
        Point delta = event.client - prev_point;
        Quaternion rotation = new Quaternion.identity() .. setEuler(delta.x * this.rotation_delta.x, delta.y * this.rotation_delta.y, 0.0);
        this.rotation =  rotation * this.rotation;
      }
      prev_point = event.client;
    });

    element.onMouseUp.listen((MouseEvent event){
      event.preventDefault();
      prev_point = null;
    });

    element.onMouseWheel.listen((WheelEvent event){
      event.preventDefault();

      if(event.deltaY > 0.0) {
        this.value = Math.min(this.value + this.delta, 1.0);
      }

      if(event.deltaY < 0.0) {
        this.value = Math.max(this.value - this.delta, 0.0);
      }
    });
  }
}

