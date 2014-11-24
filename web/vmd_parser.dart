part of mmd_renderer;

class VMD_Exception implements Exception {
  final String message;
  const VMD_Exception(this.message);
  String toString() => "VMD_Exception\n${this.message}";
}

class VMD_Animation {
  String name;
  String comment;

  Future<VMD_Animation> load(String uri) {
    var completer = new Completer<PMD_Model>();
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

  void parse(ByteBuffer buffer) {
    var view = new ByteData.view(buffer);
    int offset = 0;
  }
}
