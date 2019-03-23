import "dart:html";
import "dart:js" as JS;

void testWorkers() {
    print("begin worker test");

    var func = (String s) => print("a function: $s");

    var jsfunc = JS.allowInterop(func);

    Worker worker = new Worker("worker.js");
    worker.postMessage(jsfunc);
}