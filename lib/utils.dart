library tasks.utils;

import 'dart:async';
import 'package:tasks/tasks.dart';

Future pmap(Iterable items, block(item), {int concurrencyCount: 1}) async {
  var taskQueue = new TaskQueue(concurrencyCount: concurrencyCount);
  var results = await Future.wait(items.map((item) {
    var task = new BlockTask(() => block(item));
    taskQueue.queue(task);
    return task.result;
  }));
  return results;
}
