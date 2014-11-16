part of webgl_framework;

class WebGLCanvasTexture {
  CanvasElement canvas;
  CanvasRenderingContext2D ctx;

  GL.Texture texture;

  WebGLCanvasTexture([this.texture, this.canvas, this.ctx]);

  Future<WebGLCanvasTexture> load(GL.RenderingContext gl, String uri) {
    var completer = new Completer<WebGLCanvasTexture>();
    var future = completer.future;

    ImageElement image = document.createElement("img");
    image.onLoad.listen((event){
      bool isPowerOfTwo(int x) => (x & (x - 1)) == 0x00;
      int nextHighestPowerOfTwo(int x) {
        --x;
        for(int i = 1; i < 32; i <<= 1) {
          x = x | x >> i;
        }
        return x + 1;
      }

      if(isPowerOfTwo(image.width) && isPowerOfTwo(image.height)) {
        this.canvas.width = image.width;
        this.canvas.height = image.height;
      } else {
        this.canvas.width = nextHighestPowerOfTwo(image.width);
        this.canvas.height = nextHighestPowerOfTwo(image.height);
      }

      this.ctx.drawImage(image, 0, 0);

      gl.bindTexture(GL.TEXTURE_2D, this.texture);
      gl.texImage2DCanvas(GL.TEXTURE_2D, 0, GL.RGBA, GL.RGBA, GL.UNSIGNED_BYTE, this.canvas);
      gl.generateMipmap(GL.TEXTURE_2D);
      gl.bindTexture(GL.TEXTURE_2D, null);

      completer.complete(this);
    });

    image.src = uri;

    return future;
  }
}

