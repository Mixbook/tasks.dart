# Tasks

Allows to specify "tasks" and execute them concurrently in a single thread in a queue with predefined concurrency count.

## Features

You can:

* Define tasks (by inheriting from `Task` or using `BlockTask`), which will perform some work.
* Define task queues, where you can specify the number of concurrently executing tasks in the queue.
* Track the status of the tasks (`pending`, `executing`, `finished`, etc).
* Cancel the tasks.
* Specify priorities for the tasks, which will be taken into account when deciding what task will execute next in the queue.

What's it good for:

* Concurrent handling of IO heavy or network heavy tasks. Like, you have 1000 HTTP calls to be made, and you want to
  parallelize them by making 20 at a time. This library will be a good fit for that task.
* Concurrent handling of tasks where you want to have the track of the status. E.g. image uploading, where you want to track
  the progress, and filter by successfully uploaded ones.
* You got the idea :)

What's it not good for:

* CPU heavy concurrent tasks. Since it uses single-threaded `Future`-based tasks, it will block the thread.
  You probably need something isolates-based instead.

## Usage

#### Using `BlockTask` to handle simultaneous HTTP calls:

```dart
import 'dart:async';
import 'dart:convert';
import 'package:tasks/tasks.dart';
import 'package:http/http.dart' as http;

main() async {
  var taskQueue = new TaskQueue(concurrencyCount: 3);
  var pages = new List.generate(10, (i) => i);
  var allPackages = [];
  var results = await Future.wait(pages.map((page) async {
    var task = new BlockTask(() async {
      return JSON.decode((await http.get("https://pub.dartlang.org/packages.json?page=$page")).body)["packages"];
    });
    taskQueue.queue(task);
    var result = await task.result;
    allPackages.addAll(result);
  }));
  print(allPackages);
}
```

#### Using `pmap`

This scenario above is pretty common, so we added a convenience helper `pmap` for that:

```dart
import 'dart:async';
import 'dart:convert';
import 'package:tasks/utils.dart';
import 'package:http/http.dart' as http;

main() async {
  var pages = new List.generate(10, (i) => i);
  var allPackages = await pmap(pages, (page) async {
    return JSON.decode((await http.get("https://pub.dartlang.org/packages.json?page=$page")).body)["packages"];
  }, concurrencyCount: 3);
  print(allPackages.expand((i) => i).toList());
}
```

#### Using subclasses of `Task`

If you have way more complicated requirements, with the business logic not fitting nicely into one anonymous function,
you can create your own class for `Task` and just override some methods:

```dart
import 'dart:async';
import 'dart:convert';
import 'package:tasks/tasks.dart';
import 'package:http/http.dart' as http;

class MyTask extends Task<Iterable<String>> {
  final int page;
  MyTask(this.page, {int priority: TaskPriority.normal}) : super(priority: priority);

  Future<Iterable<String>> performWork() async {
    return JSON.decode((await http.get("https://pub.dartlang.org/packages.json?page=$page")).body)["packages"];
  }
}

main() async {
  var taskQueue = new TaskQueue(concurrencyCount: 3);
  var pages = new List.generate(10, (i) => i);
  var allPackages = [];
  var results = await Future.wait(pages.map((page) async {
    var task = new MyTask(page);
    taskQueue.queue(task);
    var result = await task.result;
    allPackages.addAll(result);
  }));
  print(allPackages);
}
```

#### Tracking status of tasks

Let's extend the previous example to be able to track when the task is queued and finished.

```dart
// ...
var task = new MyTask(page);
task.onStateChange.listen((_) {
  if (task.isExecuting) {
    print("Task for page ${task.page} is executing");
  } else if (task.isFinished) {
    print("Task for page ${task.page} is finished");
  }
});
// ...
```
